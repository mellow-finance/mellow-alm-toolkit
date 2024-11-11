// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../../scripts/deploy/Constants.sol";
import "../../src/interfaces/external/velo/ISwapRouter.sol";

contract SolvencyRunner is Test, DeployScript {
    using SafeERC20 for IERC20;
    using RandomLib for RandomLib.Storage;

    uint256 private constant Q96 = 2 ** 96;
    uint256 private constant ROUNDING_ERROR = 1e4;

    ICore private _core;
    ILpWrapper private _wrapper;
    RebalancingBot private _bot =
        new RebalancingBot(INonfungiblePositionManager(Constants.OPTIMISM_POSITION_MANAGER));
    RandomLib.Storage internal rnd;
    uint256 internal _iteration;

    address[] private depositors;
    uint256[] private depositedAmounts0;
    uint256[] private depositedAmounts1;
    uint256[] private depositedShares;
    uint256[] private withdrawnAmounts0;
    uint256[] private withdrawnAmounts1;
    uint256[] private withdrawnShares;
    bool private hasWithdrawals;

    IERC20 private token0;
    IERC20 private token1;
    ICLPool private pool;
    ICLGauge private gauge;

    int256 private rebalanceChange0;
    int256 private rebalanceChange1;
    int256 private swapChange0;
    int256 private swapChange1;

    uint256 private initialBalance0;
    uint256 private initialBalance1;
    uint256 private initialShares;

    function __SolvencyRunner_init(ICore core_, ILpWrapper wrapper_) internal {
        delete depositors;
        delete depositedAmounts0;
        delete depositedAmounts1;
        delete depositedShares;
        delete withdrawnAmounts0;
        delete withdrawnAmounts1;
        delete withdrawnShares;

        delete rebalanceChange0;
        delete rebalanceChange1;
        delete swapChange0;
        delete swapChange1;

        delete _iteration;
        delete hasWithdrawals;

        _core = core_;
        _wrapper = wrapper_;

        token0 = _wrapper.token0();
        token1 = _wrapper.token1();

        pool = ICLPool(_core.managedPositionAt(_wrapper.positionId()).pool);
        gauge = ICLGauge(pool.gauge());

        // just a magic, nvm
        deal(address(token0), address(gauge), 1000 wei);
        deal(address(token1), address(gauge), 1000 wei);

        (initialBalance0, initialBalance1, initialShares) = calculateTvl();
    }

    function applyRoundings(uint256 amount) internal pure returns (uint256) {
        return amount - Math.ceilDiv(amount, ROUNDING_ERROR);
    }

    function calculateTvl()
        internal
        view
        returns (uint256 amount0, uint256 amount1, uint256 totalSupply)
    {
        ICore.ManagedPositionInfo memory info = _core.managedPositionAt(_wrapper.positionId());
        uint256[] memory tokenIds = info.ammPositionIds;
        uint256 length = tokenIds.length;
        totalSupply = _wrapper.totalSupply();
        IAmmModule ammModule = _core.ammModule();
        (uint160 sqrtPriceX96,,,,,) = pool.slot0();
        for (uint256 i = 0; i < length; i++) {
            (uint256 position0, uint256 position1) =
                ammModule.tvl(tokenIds[i], sqrtPriceX96, info.callbackParams, new bytes(0));
            amount0 += position0;
            amount1 += position1;
        }
    }

    function transitionRandomDeposit() internal {
        uint256 userIndex;
        if (depositors.length == 0 || rnd.randBool()) {
            userIndex = depositors.length;
            depositors.push(rnd.randAddress());
            depositedAmounts0.push(0);
            depositedAmounts1.push(0);
            depositedShares.push(0);
            withdrawnAmounts0.push(0);
            withdrawnAmounts1.push(0);
            withdrawnShares.push(0);
        } else {
            userIndex = rnd.randInt(depositors.length - 1);
        }
        address user = depositors[userIndex];

        uint256 lpAmount = rnd.randAmountD18();
        (uint256 totalAmount0, uint256 totalAmount1, uint256 totalSupply) = calculateTvl();
        uint256 amount0 = totalAmount0 * lpAmount / totalSupply;
        uint256 amount1 = totalAmount1 * lpAmount / totalSupply;
        lpAmount = applyRoundings(lpAmount);

        deal(address(token0), user, amount0);
        deal(address(token1), user, amount1);

        vm.startPrank(user);
        token0.safeIncreaseAllowance(address(_wrapper), amount0);
        token1.safeIncreaseAllowance(address(_wrapper), amount1);
        if (lpAmount + _wrapper.totalSupply() > _wrapper.totalSupplyLimit()) {
            vm.expectRevert(bytes4(keccak256("TotalSupplyLimitReached()")));
            _wrapper.deposit(amount0, amount1, lpAmount, user, type(uint256).max);

            token0.forceApprove(address(_wrapper), 0);
            token1.forceApprove(address(_wrapper), 0);
        } else {
            (uint256 actualAmount0, uint256 actualAmount1, uint256 actualLpAmount) =
                _wrapper.deposit(amount0, amount1, lpAmount, user, type(uint256).max);

            depositedAmounts0[userIndex] += actualAmount0;
            depositedAmounts1[userIndex] += actualAmount1;
            depositedShares[userIndex] += actualLpAmount;

            if (actualAmount0 != amount0) {
                token0.forceApprove(address(_wrapper), 0);
            }

            if (actualAmount1 != amount1) {
                token1.forceApprove(address(_wrapper), 0);
            }
        }
        vm.stopPrank();
    }

    function _withdraw(uint256 userIndex, uint256 lpAmount) internal {
        (uint256 totalAmount0, uint256 totalAmount1, uint256 totalSupply) = calculateTvl();
        uint256 minAmount0 = totalAmount0 * lpAmount / totalSupply;
        uint256 minAmount1 = totalAmount1 * lpAmount / totalSupply;
        minAmount0 = applyRoundings(minAmount0);
        minAmount1 = applyRoundings(minAmount1);
        address user = depositors[userIndex];
        vm.prank(user);
        (uint256 amount0, uint256 amount1, uint256 actualLpAmount) =
            _wrapper.withdraw(lpAmount, minAmount0, minAmount1, user, type(uint256).max);
        withdrawnAmounts0[userIndex] += amount0;
        withdrawnAmounts1[userIndex] += amount1;
        withdrawnShares[userIndex] += actualLpAmount;
    }

    function transitionRandomWithdraw() internal {
        uint256 holders = 0;
        for (uint256 i = 0; i < depositors.length; i++) {
            if (_wrapper.balanceOf(depositors[i]) != 0) {
                holders++;
            }
        }
        if (holders == 0) {
            return;
        }
        uint256 holderIndex = rnd.randInt(holders - 1);
        holders = 0;
        uint256 userIndex = 0;
        for (uint256 i = 0; i < depositors.length; i++) {
            if (_wrapper.balanceOf(depositors[i]) == 0) {
                continue;
            }
            if (holderIndex == holders) {
                userIndex = i;
                break;
            }
            holders++;
        }
        address user = depositors[userIndex];
        uint256 lpAmount = rnd.randInt(1, _wrapper.balanceOf(user));
        hasWithdrawals = true;
        _withdraw(userIndex, lpAmount);
    }

    function transitionRandomSwap() internal {
        ISwapRouter swapRouter = ISwapRouter(Constants.OPTIMISM_SWAP_ROUTER);

        address swapper = rnd.randAddress();
        vm.startPrank(swapper);
        bool zeroToOne = rnd.randBool();
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: address(zeroToOne ? token0 : token1),
            tokenOut: address(zeroToOne ? token1 : token0),
            tickSpacing: pool.tickSpacing(),
            recipient: swapper,
            deadline: type(uint256).max,
            amountOut: rnd.randInt(
                1,
                ((zeroToOne ? token1.balanceOf(address(pool)) : token0.balanceOf(address(pool))) >> 1)
                    + 1
            ),
            amountInMaximum: type(uint128).max,
            sqrtPriceLimitX96: 0
        });

        deal(params.tokenIn, swapper, params.amountInMaximum);
        IERC20(params.tokenIn).forceApprove(address(swapRouter), params.amountInMaximum);

        (uint256 balance0Before, uint256 balance1Before,) = calculateTvl();

        swapRouter.exactOutputSingle(params);

        {
            (uint256 balance0After, uint256 balance1After,) = calculateTvl();
            swapChange0 += int256(balance0After) - int256(balance0Before);
            swapChange1 += int256(balance1After) - int256(balance1Before);
        }

        deal(params.tokenIn, swapper, 0);
        IERC20(params.tokenIn).forceApprove(address(swapRouter), 0);

        vm.stopPrank();
    }

    function randomTransitionIndex(uint256 bitMask) internal returns (uint256) {
        uint256 bits = allTransitions.length;

        uint256 nonZeroBits = 0;
        for (uint256 i = 0; i < bits; i++) {
            if ((bitMask & (1 << i)) != 0) {
                nonZeroBits++;
            }
        }
        if (nonZeroBits == 0) {
            return rnd.randInt(bits - 1);
        }

        uint256 index = rnd.randInt(nonZeroBits - 1);
        for (uint256 i = 0; i < bits; i++) {
            if ((bitMask & (1 << i)) != 0) {
                if (index == 0) {
                    return i;
                }
                index--;
            }
        }
        return 0;
    }

    function transitionRandomRebalance() internal {
        address coreOperator = _core.getRoleMember(keccak256("operator"), 0);

        IStrategyModule strategyModule = _core.strategyModule();
        ICore.ManagedPositionInfo memory info = _core.managedPositionAt(_wrapper.positionId());

        IOracle oracle = _core.oracle();

        deal(address(token0), address(_bot), type(uint128).max);
        deal(address(token1), address(_bot), type(uint128).max);

        if (rnd.randBool() && rnd.randBool()) {
            transitionRandomSwap();
        }
        (bool isRebalanceRequired,) = strategyModule.getTargets(info, _core.ammModule(), oracle);
        bool isRevertExpected = !isRebalanceRequired;
        (uint256 balance0, uint256 balance1,) = calculateTvl();
        if (!isRevertExpected) {
            try oracle.ensureNoMEV(address(pool), info.securityParams) {
                // normal pool state
            } catch {
                isRevertExpected = true;
            }
        }

        vm.startPrank(coreOperator);

        ICore.RebalanceParams memory rebalanceParams = ICore.RebalanceParams({
            callback: address(_bot),
            data: new bytes(0),
            id: _wrapper.positionId()
        });

        if (isRevertExpected) {
            vm.expectRevert();
        }

        _core.rebalance(rebalanceParams);
        vm.stopPrank();

        if (!isRevertExpected) {
            (uint256 balance0After, uint256 balance1After,) = calculateTvl();
            rebalanceChange0 += int256(balance0After) - int256(balance0);
            rebalanceChange1 += int256(balance1After) - int256(balance1);
        }
        deal(address(token0), address(_bot), 0);
        deal(address(token1), address(_bot), 0);
    }

    function transitionRandomSetStrategyParams() internal {
        IPulseStrategyModule.StrategyParams memory params = abi.decode(
            _core.managedPositionAt(_wrapper.positionId()).strategyParams,
            (IPulseStrategyModule.StrategyParams)
        );
        if (rnd.randBool() && rnd.randBool()) {
            params.strategyType = IPulseStrategyModule.StrategyType(
                rnd.randInt(uint256(type(IPulseStrategyModule.StrategyType).max))
            );
        }
        params.width = int24(int256(rnd.randInt(1, 25) * 2));
        if (params.strategyType != IPulseStrategyModule.StrategyType.Tamper) {
            params.maxLiquidityRatioDeviationX96 = 0;
        } else {
            params.maxLiquidityRatioDeviationX96 = Q96 * rnd.randInt(1, 10) / 100;
        }
        if (params.strategyType != IPulseStrategyModule.StrategyType.Original) {
            params.tickNeighborhood = 0;
        } else {
            params.tickNeighborhood = int24(int256(rnd.randInt(uint256(uint24(params.width / 2)))));
        }

        address wrapperAdmin = _wrapper.getRoleMember(keccak256("admin"), 0);
        vm.prank(wrapperAdmin);
        _wrapper.setStrategyParams(params);
    }

    function transitionRandomSkip() internal {
        skip(rnd.randInt(1 days));
    }

    function transitionRandomSetTotalSupplyLimit() internal {
        uint256 totalSupply = _wrapper.totalSupply();

        address wrapperAdmin = _wrapper.getRoleMember(keccak256("admin"), 0);
        vm.startPrank(wrapperAdmin);
        if (rnd.randBool() && rnd.randBool()) {
            _wrapper.setTotalSupplyLimit(rnd.randInt(totalSupply));
        } else {
            _wrapper.setTotalSupplyLimit(rnd.randInt(totalSupply, totalSupply * 2 + 1000 ether));
        }
        vm.stopPrank();
    }

    function transitionDistributeRewards() internal {
        uint256 amount = rnd.randAmountD18();
        address voter = address(gauge.voter());
        address rewardToken = gauge.rewardToken();
        vm.startPrank(voter);
        deal(rewardToken, voter, amount);
        IERC20(rewardToken).safeIncreaseAllowance(address(gauge), amount);
        ICLGauge(gauge).notifyRewardAmount(amount);
        vm.stopPrank();
    }

    function finalize() internal {
        for (uint256 i = 0; i < depositors.length; i++) {
            address user = depositors[i];
            uint256 lpAmount = _wrapper.balanceOf(user);
            if (lpAmount == 0) {
                continue;
            }
            _withdraw(i, lpAmount);
        }
    }

    function validateState() internal {
        uint256 deposited0 = initialBalance0;
        uint256 deposited1 = initialBalance1;
        uint256 withdrawn0 = 0;
        uint256 withdrawn1 = 0;

        (uint256 tvl0, uint256 tvl1, uint256 totalSupply) = calculateTvl();
        for (uint256 i = 0; i < depositors.length; i++) {
            deposited0 += depositedAmounts0[i];
            deposited1 += depositedAmounts1[i];
            withdrawn0 += withdrawnAmounts0[i];
            withdrawn1 += withdrawnAmounts1[i];
        }

        int256 expectedBalance0 =
            int256(deposited0) - int256(withdrawn0) + swapChange0 + rebalanceChange0;
        int256 expectedBalance1 =
            int256(deposited1) - int256(withdrawn1) + swapChange1 + rebalanceChange1;

        int256 actualBalance0 = int256(tvl0);
        int256 actualBalance1 = int256(tvl1);

        assertApproxEqAbs(expectedBalance0, actualBalance0, _iteration);
        assertApproxEqAbs(expectedBalance1, actualBalance1, _iteration);

        uint256 expectedShares = initialShares;
        for (uint256 i = 0; i < depositors.length; i++) {
            expectedShares += depositedShares[i];
        }
        for (uint256 i = 0; i < depositors.length; i++) {
            expectedShares -= withdrawnShares[i];
        }
        assertEq(totalSupply, expectedShares, "Total supply is incorrect");
    }

    function finalValidation() internal {
        validateState();
        // if (hasWithdrawals) {
        //     return;
        // }
        // (uint160 sqrtPriceX96,,,,,) = pool.slot0();
        // uint256 priceX96 = Math.mulDiv(sqrtPriceX96, sqrtPriceX96, Q96);
        // (uint256 tvl0, uint256 tvl1,) = calculateTvl();
        // uint256 value = Math.mulDiv(tvl0, priceX96, Q96) + tvl1;
        // uint256 valueBefore = Math.mulDiv(initialBalance0, priceX96, Q96) + initialBalance1;
        // assertLe(value, valueBefore + _iteration, "Final TVL is greater than initial TVL");
        // for (uint256 i = 0; i < depositors.length; i++) {
        //     uint256 userShares = _wrapper.balanceOf(depositors[i]);
        //     assertEq(userShares, 0, "User has non-zero balance");
        //     uint256 cumulativeDepositedValue =
        //         Math.mulDiv(depositedAmounts0[i], priceX96, Q96) + depositedAmounts1[i];
        //     uint256 cumulativeHoldAndWithdrawnValue =
        //         Math.mulDiv(withdrawnAmounts0[i], priceX96, Q96) + withdrawnAmounts1[i];
        //     assertLe(
        //         cumulativeHoldAndWithdrawnValue,
        //         cumulativeDepositedValue + _iteration,
        //         "User balance is greater than deposited"
        //     );
        // }
    }

    function() internal[] allTransitions = [
        transitionRandomDeposit,
        transitionRandomWithdraw,
        transitionRandomSwap,
        transitionRandomRebalance,
        transitionRandomSetStrategyParams,
        transitionRandomSkip,
        transitionRandomSetTotalSupplyLimit,
        transitionDistributeRewards
    ];

    function _runSolvency(uint256 iterations, uint256 bitMask) internal {
        uint256[] memory indices = new uint256[](iterations);
        for (uint256 i = 0; i < iterations; i++) {
            indices[i] = randomTransitionIndex(bitMask);
        }
        _runSolvency(indices);
    }

    function _runSolvency(uint256[] memory indices) internal {
        for (uint256 i = 0; i < indices.length; i++) {
            _iteration = i + 1;
            allTransitions[indices[i]]();
            validateState();
        }
        finalize();
        finalValidation();
    }

    function testSolvencyRunner() internal pure {}
}
