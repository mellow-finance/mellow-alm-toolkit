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
        (uint256 poolFee0, uint256 poolFee1) = poolGaugeFee(input.pool);

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
                checkPoolManipulation(input.pool, poolFee0, poolFee1, amount0Delta, amount1Delta);

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

    function poolGaugeFee(address pool) internal view returns (uint256 fee0, uint256 fee1) {
        IPoolSwap.GaugeFees memory gaugeFees = IPoolSwap(pool).gaugeFees();
        fee0 = gaugeFees.token0;
        fee1 = gaugeFees.token1;
    }

    /**
     * @dev Checks that the accrued fees in the pool have not increased more that expected based on the position changes.
     * @param pool The address of the liquidity pool.
     * @param initialFee0 The balance of token0 in the pool before the operation.
     * @param initialFee1 The balance of token1 in the pool before the operation.
     * @param position0Delta The change in token0 of the position: > 0 if removed, < 0 if added.
     * @param position1Delta The change in token1 of the position: > 0 if removed, < 0 if added.
     */
    function checkPoolManipulation(
        address pool,
        uint256 initialFee0,
        uint256 initialFee1,
        int256 position0Delta,
        int256 position1Delta
    ) internal view {
        /// @dev fees are not decreased while we are inside one transaction
        (uint256 fee0, uint256 fee1) = poolGaugeFee(pool);
        uint24 feeD6 = IPoolSwap(pool).fee();
        uint256 maxFeePoolIncrease0 =
            position0Delta > 0 ? uint256(position0Delta).mulDiv(feeD6, D6) + 1 : 0;
        uint256 maxFeePoolIncrease1 =
            position1Delta > 0 ? uint256(position1Delta).mulDiv(feeD6, D6) + 1 : 0;

        if (fee0 > initialFee0 + maxFeePoolIncrease0 || fee1 > initialFee1 + maxFeePoolIncrease1) {
            revert PoolManipulated();
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
