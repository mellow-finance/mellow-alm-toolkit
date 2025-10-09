// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "src/interfaces/utils/IRebalanceCallback.sol";
import "src/interfaces/utils/IRebalancer.sol";
import "src/utils/VeloDeployFactory.sol";

contract Rebalancer is IRebalancer, IRebalanceCallback {
    using Math for uint256;

    VeloDeployFactory public immutable factory;
    ICore public immutable core;
    IAmmModule public immutable ammModule;
    IOracle public immutable oracle;
    IStrategyModule public immutable strategyModule;
    address public immutable depositWithdrawModule;
    uint256 private constant Q96 = 2 ** 96;
    uint256 private constant D9 = 1e9;
    uint256 private constant D6 = 1e6;
    uint256 private constant MAX_DUST_D9 = 1e3; // 1e-6

    constructor(address deployFactoryAddress) {
        factory = VeloDeployFactory(payable(deployFactoryAddress));
        core = factory.core();
        ammModule = core.ammModule();
        depositWithdrawModule = address(core.ammDepositWithdrawModule());
        oracle = core.oracle();
        strategyModule = core.strategyModule();
    }

    /// @inheritdoc IRebalancer
    function rebalance(ICore.RebalanceParams memory params) external {
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(params.id);
        (bool isRebalanceNeeded, ICore.TargetPositionInfo memory target) =
            strategyModule.getTargets(info, ammModule, oracle);

        if (!isRebalanceNeeded) {
            revert NoNeedRebalance();
        }

        bool swap = isSwap(target, info);

        if (!swap) {
            rebalanceWithoutSwap(target.id);
        } else {
            rebalanceWithSwap(params, target, info);
        }
    }

    /// @inheritdoc IRebalanceCallback
    function call(
        bytes memory,
        ICore.TargetPositionInfo memory target,
        ICore.ManagedPositionInfo memory info
    ) external returns (uint256[] memory tokenIds) {
        if (isSwap(target, info) || target.lowerTicks.length > 1) {
            revert OnlyMoveLiquidity();
        }

        address this_ = address(this);
        for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
            IAmmModule.AmmPosition memory position =
                ammModule.getAmmPosition(info.ammPositionIds[i]);
            Address.functionDelegateCall(
                depositWithdrawModule,
                abi.encodeWithSelector(
                    IAmmDepositWithdrawModule.withdraw.selector,
                    info.ammPositionIds[i],
                    position.liquidity,
                    this_
                )
            );
            Address.functionDelegateCall(
                depositWithdrawModule,
                abi.encodeWithSelector(
                    IAmmDepositWithdrawModule.burn.selector, info.ammPositionIds[i]
                )
            );
        }
        address token0 = ammModule.getToken0(info.pool);
        address token1 = ammModule.getToken1(info.pool);

        bytes memory result = Address.functionDelegateCall(
            depositWithdrawModule,
            abi.encodeWithSelector(
                IAmmDepositWithdrawModule.mint.selector,
                info.pool,
                target.lowerTicks[0],
                target.upperTicks[0],
                IERC20(token0).balanceOf(this_),
                IERC20(token1).balanceOf(this_),
                this_
            )
        );

        tokenIds = new uint256[](1);
        (tokenIds[0],,,) = abi.decode(result, (uint256, uint128, uint256, uint256));

        Address.functionDelegateCall(
            address(ammModule),
            abi.encodeWithSelector(IAmmModule.approveTokenId.selector, address(core), tokenIds[0])
        );
    }

    /// @inheritdoc IRebalancer
    function positionData(address lpWrapper) public view returns (RebalanceData memory data) {
        (, data.info) = managedPositionInfo(lpWrapper);
        (data.isRebalanceRequired, data.target) =
            strategyModule.getTargets(data.info, ammModule, oracle);
        data.lpWrapper = lpWrapper;
        data.strategyParams = getStrategyParams(lpWrapper);
        data.securityParams = getSecurityParams(lpWrapper);
    }

    /// @inheritdoc IRebalancer
    function managedPositionInfo(address lpWrapper)
        public
        view
        returns (uint256 positionId, ICore.ManagedPositionInfo memory info)
    {
        positionId = ILpWrapper(lpWrapper).positionId();
        info = core.managedPositionAt(positionId);
    }

    /// @inheritdoc IRebalancer
    function getStrategyParams(address lpWrapper)
        public
        view
        returns (IPulseStrategyModule.StrategyParams memory strategyParams)
    {
        (, ICore.ManagedPositionInfo memory info) = managedPositionInfo(lpWrapper);
        return abi.decode(info.strategyParams, (IPulseStrategyModule.StrategyParams));
    }

    /// @inheritdoc IRebalancer
    function getSecurityParams(address lpWrapper)
        public
        view
        returns (IVeloOracle.SecurityParams memory securityParams)
    {
        (, ICore.ManagedPositionInfo memory info) = managedPositionInfo(lpWrapper);
        return abi.decode(info.securityParams, (IVeloOracle.SecurityParams));
    }

    /// @inheritdoc IRebalancer
    function rebalanceRequired() public view returns (RebalanceData[] memory data) {
        uint256 positionCount = core.positionCount();
        data = new RebalanceData[](positionCount);
        uint256 length;
        for (uint256 i = 0; i < positionCount; i++) {
            data[length].positionId = i;
            data[length].info = core.managedPositionAt(i);
            (data[length].isRebalanceRequired, data[length].target) =
                strategyModule.getTargets(data[length].info, ammModule, oracle);

            if (data[length].isRebalanceRequired && factory.isEntity(data[length].info.owner)) {
                data[length].lpWrapper = data[length].info.owner;
                data[length].strategyParams = getStrategyParams(data[length].lpWrapper);
                data[length].securityParams = getSecurityParams(data[length].lpWrapper);
                length++;
            }
        }
        assembly {
            mstore(data, length)
        }
    }

    function rebalanceWithoutSwap(uint256 positionId) internal {
        core.rebalance(ICore.RebalanceParams({id: positionId, callback: address(this), data: ""}));
    }

    /**
     * @dev Rebalances a managed position that requires a swap.
     * @param params The parameters for the rebalance operation.
     * @param target The target position information.
     * @param input The current managed position information.
     * Requirements:
     * - The `callback` address in `params` must not be the zero address.
     * - The capital after the rebalance must not be less than the capital before the rebalance
     *   by more than the allowed slippage defined in `info.slippageD9` applied to only moved capital.
     */
    function rebalanceWithSwap(
        ICore.RebalanceParams memory params,
        ICore.TargetPositionInfo memory target,
        ICore.ManagedPositionInfo memory input
    ) internal {
        if (params.callback == address(0)) {
            revert InvalidCallback();
        }
        uint160 sqrtPriceX96 = ammModule.getSqrtPriceX96(input.pool);
        uint256 capitalBefore = capitalPosition(input, sqrtPriceX96);
        (uint256 poolBalance0, uint256 poolBalance1) = poolBalance(input.pool);

        int256 amount0Delta;
        int256 amount1Delta;
        for (uint256 i = 0; i < input.ammPositionIds.length; i++) {
            (uint256 amount0, uint256 amount1) = ammModule.tvl(input.ammPositionIds[i]);
            amount0Delta += int256(amount0);
            amount1Delta += int256(amount1);
        }

        core.rebalance(params);

        ICore.ManagedPositionInfo memory output = core.managedPositionAt(target.id);
        uint256 capitalAfter = capitalPosition(output, sqrtPriceX96);

        if (capitalAfter < capitalBefore) {
            uint256 capitalDelta = capitalBefore - capitalAfter;
            /// @dev skip slippage check for small capital changes to avoid high slippage on small moves
            if (capitalDelta.mulDiv(D9, capitalBefore) > MAX_DUST_D9) {
                for (uint256 i = 0; i < output.ammPositionIds.length; i++) {
                    (uint256 amount0, uint256 amount1) = ammModule.tvl(output.ammPositionIds[i]);
                    amount0Delta -= int256(amount0);
                    amount1Delta -= int256(amount1);
                }
                /// @dev check pool balances to detect manipulation: must be the same as before the rebalance,
                /// because in case of swap (fully or partial) the pool balances do not change (fees are stay in the pool)
                checkPoolBalancesDelta(
                    input.pool,
                    poolBalance0,
                    poolBalance1,
                    amount0Delta,
                    amount1Delta,
                    input.slippageD9
                );

                /// @dev estimate moved capital as an average of token0 and token1 deltas in token1 terms
                uint256 movedCapital = PositionMath.calculateCapital(
                    uint256(amount0Delta < 0 ? -amount0Delta : amount0Delta),
                    uint256(amount1Delta < 0 ? -amount1Delta : amount1Delta),
                    sqrtPriceX96
                ) / 2;

                uint256 capitalDeltaLimit = movedCapital.mulDiv(input.slippageD9, D9);
                if (capitalDelta > capitalDeltaLimit || movedCapital > capitalBefore / 2) {
                    revert HighSlippage();
                }
            }
        }
    }

    function poolBalance(address pool)
        internal
        view
        returns (uint256 amount0Balance, uint256 amount1Balance)
    {
        amount0Balance = IERC20(ammModule.getToken0(pool)).balanceOf(pool);
        amount1Balance = IERC20(ammModule.getToken1(pool)).balanceOf(pool);
    }

    /**
     * @dev Checks that the change in pool balances matches the expected position deltas within fee tolerance.
     * @param pool The address of the liquidity pool.
     * @param balance0Before The balance of token0 in the pool before the operation.
     * @param balance1Before The balance of token1 in the pool before the operation.
     * @param position0Delta The change in token0 of the position: > 0 if removed, < 0 if added.
     * @param position1Delta The change in token1 of the position: > 0 if removed, < 0 if added.
     * @param slippageD9 The allowed slippage in D9 format (e.g., 1e7 for 1%).
     */
    function checkPoolBalancesDelta(
        address pool,
        uint256 balance0Before,
        uint256 balance1Before,
        int256 position0Delta,
        int256 position1Delta,
        uint256 slippageD9
    ) internal view {
        (uint256 amount0Balance, uint256 amount1Balance) = poolBalance(pool);

        (int256 balance0Delta, int256 balance1Delta) = (
            int256(amount0Balance) - int256(balance0Before),
            int256(amount1Balance) - int256(balance1Before)
        );

        if (balance0Delta > 0 && balance1Delta > 0) {
            /// @dev both pool balances increased - impossible in a swap
            revert PoolManipulated();
        } else if (balance0Delta < 0 && balance1Delta < 0) {
            /// @dev both pool balances decreased - impossible in a swap
            revert PoolManipulated();
        } else if (balance0Delta < 0 && position0Delta > 0) {
            /// @dev pool balance decreased, position0Delta of the position was swapped
            if (uint256(-balance0Delta) > uint256(position0Delta).mulDiv(slippageD9, D9)) {
                revert PoolManipulated();
            }
        } else if (balance1Delta < 0 && position1Delta > 0) {
            /// @dev pool balance decreased, position1Delta of the position was swapped
            if (uint256(-balance1Delta) > uint256(position1Delta).mulDiv(slippageD9, D9)) {
                revert PoolManipulated();
            }
        }
    }

    function capitalPosition(ICore.ManagedPositionInfo memory info, uint160 sqrtPriceX96)
        public
        view
        returns (uint256)
    {
        uint256 amount0Total;
        uint256 amount1Total;
        for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
            (uint256 amount0, uint256 amount1) = ammModule.tvl(info.ammPositionIds[i]);
            amount0Total += amount0;
            amount1Total += amount1;
        }
        return PositionMath.calculateCapital(amount0Total, amount1Total, sqrtPriceX96);
    }

    function isSwap(ICore.TargetPositionInfo memory target, ICore.ManagedPositionInfo memory info)
        internal
        view
        returns (bool)
    {
        uint160 sqrtPriceX96 = ammModule.getSqrtPriceX96(info.pool);

        for (uint256 i = 0; i < target.lowerTicks.length; i++) {
            if (
                sqrtPriceX96 > TickMath.getSqrtRatioAtTick(target.lowerTicks[i])
                    && sqrtPriceX96 < TickMath.getSqrtRatioAtTick(target.upperTicks[i])
            ) {
                return true;
            }
        }

        IAmmModule.AmmPosition[] memory ammPosition =
            new IAmmModule.AmmPosition[](info.ammPositionIds.length);

        for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
            ammPosition[i] = ammModule.getAmmPosition(info.ammPositionIds[i]);
            if (
                sqrtPriceX96 > TickMath.getSqrtRatioAtTick(ammPosition[i].tickLower)
                    && sqrtPriceX96 < TickMath.getSqrtRatioAtTick(ammPosition[i].tickUpper)
            ) {
                return true;
            }
        }
        return false;
    }
}
