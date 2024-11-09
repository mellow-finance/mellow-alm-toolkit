// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../../scripts/deploy/Constants.sol";
import "../../src/interfaces/external/velo/ISwapRouter.sol";

contract SolvencyRunner is Test, DeployScript {
    using SafeERC20 for IERC20;
    using RandomLib for RandomLib.Storage;

    uint256 private constant Q96 = 2 ** 96;

    ICore private _core;
    ILpWrapper private _wrapper;
    RebalancingBot private _bot =
        new RebalancingBot(INonfungiblePositionManager(Constants.OPTIMISM_POSITION_MANAGER));
    RandomLib.Storage internal rnd;

    address[] private depositors;
    uint256[] private depositedAmounts0;
    uint256[] private depositedAmounts1;
    uint256[] private depositedShares;
    uint256[] private claimedAmounts;
    uint256[] private withdrawnAmounts0;
    uint256[] private withdrawnAmounts1;
    uint256[] private withdrawnShares;

    IERC20 token0;
    IERC20 token1;

    function __SolvencyRunner_init(ICore core_, ILpWrapper wrapper_) internal {
        delete depositors;
        delete depositedAmounts0;
        delete depositedAmounts1;
        delete depositedShares;
        delete claimedAmounts;
        delete withdrawnAmounts0;
        delete withdrawnAmounts1;
        delete withdrawnShares;

        _core = core_;
        _wrapper = wrapper_;

        token0 = _wrapper.token0();
        token1 = _wrapper.token1();
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
        (uint160 sqrtPriceX96,,,,,) = ICLPool(info.pool).slot0();
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
            claimedAmounts.push(0);
            withdrawnAmounts0.push(0);
            withdrawnAmounts1.push(0);
            withdrawnShares.push(0);
        } else {
            userIndex = rnd.randInt(depositors.length - 1);
        }
        address user = depositors[userIndex];

        uint256 lpAmount = rnd.randAmountD18();
        (uint256 totalAmount0, uint256 totalAmount1, uint256 totalSupply) = calculateTvl();
        uint256 d = 6;
        uint256 amount0 = totalAmount0 * lpAmount / totalSupply * (10 ** d + 1) / 10 ** d + 1; // + 0.0001% + dust due to roundings
        uint256 amount1 = totalAmount1 * lpAmount / totalSupply * (10 ** d + 1) / 10 ** d + 1;

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

        (uint256 totalAmount0, uint256 totalAmount1, uint256 totalSupply) = calculateTvl();
        uint256 minAmount0 = (totalAmount0 * lpAmount / totalSupply) * 9995 / 10000; // 0.05% slippage due to roundings
        uint256 minAmount1 = (totalAmount1 * lpAmount / totalSupply) * 9995 / 10000;

        vm.prank(user);
        (uint256 amount0, uint256 amount1, uint256 actualLpAmount) =
            _wrapper.withdraw(lpAmount, minAmount0, minAmount1, user, type(uint256).max);
        withdrawnAmounts0[userIndex] += amount0;
        withdrawnAmounts1[userIndex] += amount1;
        withdrawnShares[userIndex] += actualLpAmount;
    }

    function transitionRandomSwap() internal {
        ICLPool pool = ICLPool(_core.managedPositionAt(_wrapper.positionId()).pool);
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

        swapRouter.exactOutputSingle(params);

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
        if (!isRevertExpected) {
            try oracle.ensureNoMEV(info.pool, info.securityParams) {
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

    function() internal[] allTransitions = [
        transitionRandomDeposit,
        transitionRandomWithdraw,
        transitionRandomSwap,
        transitionRandomRebalance,
        transitionRandomSetStrategyParams,
        transitionRandomSkip,
        transitionRandomSetTotalSupplyLimit
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
            allTransitions[indices[i]]();
        }
    }

    function testSolvencyRunner() internal pure {}
}
