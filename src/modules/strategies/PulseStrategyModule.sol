// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/modules/strategies/IPulseStrategyModule.sol";

import "../../libraries/external/FullMath.sol";

/**
 * @title PulseStrategyModule
 * @dev A strategy module that implements the Pulse V1 strategy and Lazy Pulse strategy.
 */
contract PulseStrategyModule is IPulseStrategyModule {
    /// @inheritdoc IPulseStrategyModule
    uint256 public constant Q96 = 2 ** 96;

    /// @inheritdoc IStrategyModule
    function validateStrategyParams(
        bytes memory params_
    ) external pure override {
        StrategyParams memory params = abi.decode(params_, (StrategyParams));
        if (
            params.width == 0 ||
            params.tickSpacing == 0 ||
            params.width % params.tickSpacing != 0 ||
            params.tickNeighborhood * 2 > params.width ||
            (params.strategyType != StrategyType.Original &&
                params.tickNeighborhood != 0)
        ) revert InvalidParams();
    }

    /// @inheritdoc IStrategyModule
    function getTargets(
        ICore.PositionInfo memory info,
        IAmmModule ammModule,
        IOracle oracle
    )
        external
        view
        override
        returns (
            bool isRebalanceRequired,
            ICore.TargetPositionInfo memory target
        )
    {
        if (info.tokenIds.length != 1) {
            revert InvalidLength();
        }
        IAmmModule.Position memory position = ammModule.getPositionInfo(
            info.tokenIds[0]
        );
        StrategyParams memory strategyParams = abi.decode(
            info.strategyParams,
            (StrategyParams)
        );
        (, int24 tick) = oracle.getOraclePrice(info.pool);
        return
            calculateTarget(
                tick,
                position.tickLower,
                position.tickUpper,
                strategyParams
            );
    }

    function _centeredPosition(
        int24 tick,
        int24 positionWidth,
        int24 tickSpacing
    ) private pure returns (int24 targetTickLower, int24 targetTickUpper) {
        targetTickLower = tick - positionWidth / 2;
        int24 remainder = targetTickLower % tickSpacing;
        if (remainder < 0) remainder += tickSpacing;
        targetTickLower -= remainder;
        targetTickUpper = targetTickLower + positionWidth;
        if (
            targetTickUpper < tick ||
            _max(tick - targetTickLower, targetTickUpper - tick) >
            _max(
                tick - (targetTickLower + tickSpacing),
                (targetTickUpper + tickSpacing) - tick
            )
        ) {
            targetTickLower += tickSpacing;
            targetTickUpper += tickSpacing;
        }
    }

    function _calculatePosition(
        int24 tick,
        int24 tickLower,
        int24 tickUpper,
        StrategyParams memory params
    ) private pure returns (int24 targetTickLower, int24 targetTickUpper) {
        if (params.width != tickUpper - tickLower)
            return _centeredPosition(tick, params.width, params.tickSpacing);
        if (
            tick >= tickLower + params.tickNeighborhood &&
            tick <= tickUpper - params.tickNeighborhood
        ) return (tickLower, tickUpper);
        if (params.strategyType == StrategyType.Original)
            return _centeredPosition(tick, params.width, params.tickSpacing);
        if (
            params.strategyType == StrategyType.LazyDescending &&
            tick >= tickLower
        ) return (tickLower, tickUpper);
        if (
            params.strategyType == StrategyType.LazyAscending &&
            tick <= tickUpper
        ) return (tickLower, tickUpper);

        int24 delta = -(tick % params.tickSpacing);
        if (tick < tickLower) {
            if (delta < 0) delta += params.tickSpacing;
            targetTickLower = tick + delta;
        } else {
            if (delta > 0) delta -= params.tickSpacing;
            targetTickLower = tick + delta - params.width;
        }
        targetTickUpper = targetTickLower + params.width;
    }

    /// @inheritdoc IPulseStrategyModule
    function calculateTarget(
        int24 tick,
        int24 tickLower,
        int24 tickUpper,
        StrategyParams memory params
    )
        public
        pure
        returns (
            bool isRebalanceRequired,
            ICore.TargetPositionInfo memory target
        )
    {
        (int24 targetTickLower, int24 targetTickUpper) = _calculatePosition(
            tick,
            tickLower,
            tickUpper,
            params
        );
        if (targetTickLower == tickLower && targetTickUpper == tickUpper)
            return (false, target);
        target.lowerTicks = new int24[](1);
        target.upperTicks = new int24[](1);
        target.lowerTicks[0] = targetTickLower;
        target.upperTicks[0] = targetTickUpper;
        target.liquidityRatiosX96 = new uint256[](1);
        target.liquidityRatiosX96[0] = Q96;
        isRebalanceRequired = true;
    }

    function _max(int24 a, int24 b) private pure returns (int24) {
        if (a < b) return b;
        return a;
    }
}
