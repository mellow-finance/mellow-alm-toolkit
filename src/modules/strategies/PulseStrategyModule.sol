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

    /// @inheritdoc IPulseStrategyModule
    function validateStrategyParams(
        bytes memory params
    ) external pure override {
        StrategyParams memory strategyParams = abi.decode(
            params,
            (StrategyParams)
        );
        if (
            strategyParams.tickSpacing == 0 ||
            (strategyParams.strategyType != StrategyType.Original &&
                strategyParams.tickNeighborhood != 0)
        ) revert InvalidParams();
    }

    /// @inheritdoc IPulseStrategyModule
    function getTargets(
        ICore.NftsInfo memory info,
        IAmmModule ammModule,
        IOracle oracle
    )
        external
        view
        override
        returns (bool isRebalanceRequired, ICore.TargetNftsInfo memory target)
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

    /// @inheritdoc IPulseStrategyModule
    function calculateTarget(
        int24 tick,
        int24 tickLower,
        int24 tickUpper,
        StrategyParams memory params
    )
        public
        pure
        returns (bool isRebalanceRequired, ICore.TargetNftsInfo memory target)
    {
        if (
            tick >= tickLower + params.tickNeighborhood &&
            tick <= tickUpper - params.tickNeighborhood
        ) {
            return (false, target);
        }

        int24 targetTickLower;
        int24 targetTickUpper;
        int24 positionWidth = tickUpper - tickLower;
        if (params.strategyType == StrategyType.Original) {
            targetTickLower = tick - positionWidth / 2;
            int24 remainder = targetTickLower % params.tickSpacing;
            if (remainder < 0) remainder += params.tickSpacing;
            targetTickLower -= remainder;
            targetTickUpper = targetTickLower + positionWidth;
            if (
                targetTickUpper < tick ||
                _max(tick - targetTickLower, targetTickUpper - tick) >
                _max(
                    tick - (targetTickLower + params.tickSpacing),
                    (targetTickUpper + params.tickSpacing) - tick
                )
            ) {
                targetTickLower += params.tickSpacing;
                targetTickUpper += params.tickSpacing;
            }
        } else {
            if (
                params.strategyType == StrategyType.LazyDescending &&
                tick >= tickLower
            ) return (false, target);
            if (
                params.strategyType == StrategyType.LazyAscending &&
                tick <= tickUpper
            ) return (false, target);

            int24 delta = -(tick % params.tickSpacing);
            if (tick < tickLower) {
                if (delta < 0) delta += params.tickSpacing;
                targetTickLower = tick + delta;
            } else {
                if (delta > 0) delta -= params.tickSpacing;
                targetTickLower = tick + delta - positionWidth;
            }
            targetTickUpper = targetTickLower + positionWidth;
        }

        if (targetTickLower == tickLower && targetTickUpper == tickUpper) {
            return (false, target);
        }

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
