// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../interfaces/modules/strategies/IPulseStrategyModule.sol";

contract PulseStrategyModule is IPulseStrategyModule {
    /// @dev A constant representing the Q96 fixed-point format.
    uint256 private constant Q96 = 2 ** 96;

    /**
     * @notice Calculates a penalty based on the price position within a given range.
     * @param sqrtPriceX96 Current square root price in Q96 format.
     * @param sqrtPriceX96Lower Lower bound of the price range in Q96 format.
     * @param sqrtPriceX96Upper Upper bound of the price range in Q96 format.
     * @return The calculated penalty, with a maximum value if outside the range.
     */
    function calculatePenalty(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceX96Lower,
        uint160 sqrtPriceX96Upper
    ) public pure returns (uint256) {
        if (sqrtPriceX96 < sqrtPriceX96Lower || sqrtPriceX96 > sqrtPriceX96Upper) {
            return type(uint256).max;
        }

        return Math.max(
            Math.mulDiv(sqrtPriceX96, Q96, sqrtPriceX96Lower),
            Math.mulDiv(sqrtPriceX96Upper, Q96, sqrtPriceX96)
        );
    }

    /**
     * @notice Calculates the centered tick position for a given tick and range.
     * @param sqrtPriceX96 Current square root price in Q96 format.
     * @param tick Current tick of the position.
     * @param positionWidth Width of the position.
     * @param tickSpacing Spacing between each tick.
     * @return targetTickLower Lower tick of the centered position.
     * @return targetTickUpper Upper tick of the centered position.
     */
    function calculateCenteredPosition(
        uint160 sqrtPriceX96,
        int24 tick,
        int24 positionWidth,
        int24 tickSpacing
    ) public pure returns (int24 targetTickLower, int24 targetTickUpper) {
        targetTickLower = tick - positionWidth / 2;
        int24 remainder = targetTickLower % tickSpacing;
        if (remainder < 0) {
            remainder += tickSpacing;
        }
        targetTickLower -= remainder;
        targetTickUpper = targetTickLower + positionWidth;

        uint256 penalty = calculatePenalty(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(targetTickLower),
            TickMath.getSqrtRatioAtTick(targetTickUpper)
        );
        uint256 leftPenalty = calculatePenalty(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(targetTickLower - tickSpacing),
            TickMath.getSqrtRatioAtTick(targetTickUpper - tickSpacing)
        );
        uint256 rightPenalty = calculatePenalty(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(targetTickLower + tickSpacing),
            TickMath.getSqrtRatioAtTick(targetTickUpper + tickSpacing)
        );

        if (penalty <= leftPenalty && penalty <= rightPenalty) {
            return (targetTickLower, targetTickUpper);
        }

        if (leftPenalty <= rightPenalty) {
            targetTickLower -= tickSpacing;
            targetTickUpper -= tickSpacing;
        } else {
            targetTickLower += tickSpacing;
            targetTickUpper += tickSpacing;
        }
    }

    /**
     * @notice Calculates the optimal tick position based on given parameters.
     * @param sqrtPriceX96 Current square root price in Q96 format.
     * @param tick Current tick of the position.
     * @param tickLower Lower bound of the existing position.
     * @param tickUpper Upper bound of the existing position.
     * @param params Strategy parameters.
     * @return targetTickLower Lower tick of the calculated position.
     * @return targetTickUpper Upper tick of the calculated position.
     */
    function calculatePulsePosition(
        uint160 sqrtPriceX96,
        int24 tick,
        int24 tickLower,
        int24 tickUpper,
        IPulseStrategyModule.StrategyParams memory params
    ) public pure returns (int24 targetTickLower, int24 targetTickUpper) {
        if (
            sqrtPriceX96 >= TickMath.getSqrtRatioAtTick(tickLower + params.tickNeighborhood)
                && sqrtPriceX96 <= TickMath.getSqrtRatioAtTick(tickUpper - params.tickNeighborhood)
                && params.width == tickUpper - tickLower
        ) {
            return (tickLower, tickUpper);
        }

        if (
            params.width != tickUpper - tickLower
                || params.strategyType == IPulseStrategyModule.StrategyType.Original
        ) {
            return calculateCenteredPosition(sqrtPriceX96, tick, params.width, params.tickSpacing);
        }

        uint160 sqrtPriceX96Lower = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceX96Upper = TickMath.getSqrtRatioAtTick(tickUpper);

        if (
            params.strategyType == IPulseStrategyModule.StrategyType.LazyDescending
                && sqrtPriceX96 >= sqrtPriceX96Lower
        ) {
            return (tickLower, tickUpper);
        }

        if (
            params.strategyType == IPulseStrategyModule.StrategyType.LazyAscending
                && sqrtPriceX96 <= sqrtPriceX96Upper
        ) {
            return (tickLower, tickUpper);
        }
        /*  
            [== sqrtPriceX96 in tick N ==][== sqrtPriceX96 in tick N+1 ==]
            ^                             ^
            tick N                        tick N+1
        */
        /// @dev round floor, it is a lower tick of active range multiple of tickSpacing
        int24 remainder = tick % params.tickSpacing;
        if (remainder < 0) {
            remainder = params.tickSpacing + remainder;
        }
        targetTickLower = tick - remainder;

        if (sqrtPriceX96 > sqrtPriceX96Upper) {
            targetTickLower -= params.width;
        } else if (sqrtPriceX96 < sqrtPriceX96Lower) {
            if (remainder != 0 || TickMath.getSqrtRatioAtTick(tick) != sqrtPriceX96) {
                targetTickLower += params.tickSpacing;
            }
        } else {
            /// @dev sqrtPriceX96 in [sqrtPriceX96Lower, sqrtPriceX96Upper]
            return (tickLower, tickUpper);
        }
        targetTickUpper = targetTickLower + params.width;
    }

    /**
     * @notice Determines if rebalancing is needed and calculates the target position if so.
     * @param sqrtPriceX96 Current square root price in Q96 format.
     * @param tick Current tick.
     * @param positions Position data of the existing positions.
     * @param params Strategy parameters.
     * @return isRebalanceRequired Boolean indicating if rebalancing is required.
     * @return target Target position information for rebalancing.
     */
    function calculateTargetPulse(
        uint160 sqrtPriceX96,
        int24 tick,
        IAmmModule.AmmPosition[] memory positions,
        IPulseStrategyModule.StrategyParams memory params
    ) public pure returns (bool isRebalanceRequired, ICore.TargetPositionInfo memory target) {
        int24 tickLower;
        int24 tickUpper;
        isRebalanceRequired = positions.length != 1;
        if (!isRebalanceRequired) {
            tickLower = positions[0].tickLower;
            tickUpper = positions[0].tickUpper;
        }
        (int24 targetTickLower, int24 targetTickUpper) =
            calculatePulsePosition(sqrtPriceX96, tick, tickLower, tickUpper, params);
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

    /**
     * @notice Calculates the initial position's lower tick and liquidity ratio.
     * @param sqrtPriceX96 Current square root price in Q96 format.
     * @param tick Current tick of the position.
     * @param width Width of the position.
     * @return targetLower The lower tick of the target position.
     * @return lowerLiquidityRatioX96 Liquidity ratio for the lower range in Q96 format.
     */
    function calculateTamperPosition(uint160 sqrtPriceX96, int24 tick, int24 width)
        public
        pure
        returns (int24 targetLower, uint256 lowerLiquidityRatioX96)
    {
        int24 half = width / 2;
        (targetLower,) = calculateCenteredPosition(sqrtPriceX96, tick, width + half, half);
        uint160 sqrtPriceCenterX96 = TickMath.getSqrtRatioAtTick(targetLower + half);
        if (sqrtPriceX96 <= sqrtPriceCenterX96) {
            lowerLiquidityRatioX96 = Q96;
        } else if (sqrtPriceX96 >= TickMath.getSqrtRatioAtTick(targetLower + width)) {
            lowerLiquidityRatioX96 = 0;
        } else {
            // tick in [targetLower + half, targetLower + width]
            // The relative accuracy of the calculations below is no worse than 1e-5, which means:
            // max(|lowerLiquidityRatioX96(calculated) - lowerLiquidityRatioX96(theoretical)|) < Q96 / 1e5
            uint160 sqrtRatioAtTick = TickMath.getSqrtRatioAtTick(tick);
            uint160 sqrtRatioAtNextTick = TickMath.getSqrtRatioAtTick(tick + 1);
            int256 preciseTickX96 = int256(tick) * int256(Q96)
                + int256(
                    Math.mulDiv(
                        Q96, sqrtPriceX96 - sqrtRatioAtTick, sqrtRatioAtNextTick - sqrtRatioAtTick
                    )
                );
            uint256 deduction = Math.ceilDiv(
                uint256(preciseTickX96 - targetLower * int256(Q96)), uint24(half)
            ) - Q96;
            lowerLiquidityRatioX96 = Q96 - Math.min(Q96, deduction);
        }
    }

    /**
     * @notice Determines if rebalancing is needed and calculates the target position if so.
     * @param sqrtPriceX96 Current square root price in Q96 format.
     * @param tick Current tick.
     * @param positions Position data of the existing positions.
     * @param params Strategy parameters.
     * @return isRebalanceRequired Boolean indicating if rebalancing is required.
     * @return target Target position information for rebalancing.
     */
    function calculateTargetTamper(
        uint160 sqrtPriceX96,
        int24 tick,
        IAmmModule.AmmPosition[] memory positions,
        IPulseStrategyModule.StrategyParams memory params
    ) public pure returns (bool isRebalanceRequired, ICore.TargetPositionInfo memory target) {
        int24 width = params.width;
        int24 half = width / 2;
        (int24 targetLower, uint256 targetLowerRatioX96) =
            calculateTamperPosition(sqrtPriceX96, tick, width);
        isRebalanceRequired = positions.length != 2;
        IAmmModule.AmmPosition memory lowerPosition;
        IAmmModule.AmmPosition memory upperPosition;
        if (!isRebalanceRequired) {
            lowerPosition = positions[0];
            upperPosition = positions[1];
            isRebalanceRequired = lowerPosition.tickUpper - lowerPosition.tickLower != width
                || upperPosition.tickUpper - upperPosition.tickLower != width
                || lowerPosition.tickUpper != upperPosition.tickLower + half
                || lowerPosition.tickLower % half != 0;
        }

        if (!isRebalanceRequired) {
            uint256 ratioDiffX96 = 0;
            uint256 totalLiquidity = lowerPosition.liquidity + upperPosition.liquidity;
            uint256 lowerRatioX96 = Math.mulDiv(Q96, lowerPosition.liquidity, totalLiquidity);
            uint256 upperRatioX96 = Q96 - lowerRatioX96;
            uint256 targetUpperRatioX96 = Q96 - targetLowerRatioX96;
            if (targetLower == lowerPosition.tickLower) {
                ratioDiffX96 += Q96 - Math.min(targetLowerRatioX96, lowerRatioX96)
                    - Math.min(targetUpperRatioX96, upperRatioX96);
            } else if (targetLower + half == lowerPosition.tickLower) {
                ratioDiffX96 += Q96 - Math.min(targetUpperRatioX96, lowerRatioX96);
            } else if (targetLower - half == lowerPosition.tickLower) {
                ratioDiffX96 += Q96 - Math.min(targetLowerRatioX96, upperRatioX96);
            } else {
                // NOTE: Position adjustments are restricted to a maximum of half the interval width.
                // This is intentional in the LStrategy (Tamper) logic to prevent large-volume liquidity shifts in the pool during rebalancing.
                ratioDiffX96 = Q96;
                if (targetLower < lowerPosition.tickLower) {
                    targetLower = lowerPosition.tickLower - half;
                    targetLowerRatioX96 = Q96;
                } else {
                    targetLower = lowerPosition.tickLower + half;
                    targetLowerRatioX96 = 0;
                }
            }
            isRebalanceRequired = ratioDiffX96 > params.maxLiquidityRatioDeviationX96;
        }

        if (isRebalanceRequired) {
            target.lowerTicks = new int24[](2);
            target.upperTicks = new int24[](2);
            target.liquidityRatiosX96 = new uint256[](2);
            target.lowerTicks[0] = targetLower;
            target.lowerTicks[1] = targetLower + half;
            target.upperTicks[0] = targetLower + width;
            target.upperTicks[1] = targetLower + half + width;
            target.liquidityRatiosX96[0] = targetLowerRatioX96;
            target.liquidityRatiosX96[1] = Q96 - targetLowerRatioX96;
        }
    }

    /// @inheritdoc IStrategyModule
    function validateStrategyParams(bytes memory params_) external pure override {
        if (params_.length != 0xa0) {
            revert InvalidLength();
        }
        StrategyParams memory params = abi.decode(params_, (StrategyParams));
        if (
            params.width == 0 || params.tickSpacing == 0 || params.width % params.tickSpacing != 0
                || params.strategyType > StrategyType.Tamper
        ) {
            revert InvalidParams();
        }

        if (params.strategyType == StrategyType.Original) {
            // can be negative
            if (params.tickNeighborhood * 2 > params.width) {
                revert InvalidParams();
            }
        } else {
            if (params.tickNeighborhood != 0) {
                revert InvalidParams();
            }
        }
        if (params.strategyType == StrategyType.Tamper) {
            if (
                params.width % 2 != 0 || (params.width / 2) % params.tickSpacing != 0
                    || params.maxLiquidityRatioDeviationX96 == 0
                    || params.maxLiquidityRatioDeviationX96 >= Q96
            ) {
                revert InvalidParams();
            }
        } else {
            if (params.maxLiquidityRatioDeviationX96 != 0) {
                revert InvalidParams();
            }
        }
    }

    /// @inheritdoc IStrategyModule
    function getTargets(ICore.ManagedPositionInfo memory info, IAmmModule ammModule, IOracle oracle)
        external
        view
        override
        returns (bool isRebalanceRequired, ICore.TargetPositionInfo memory target)
    {
        StrategyParams memory strategyParams = abi.decode(info.strategyParams, (StrategyParams));
        (uint160 sqrtPriceX96, int24 tick) = oracle.getOraclePrice(info.pool);
        // Reasoning for using sqrtPriceX96 to get actual tick:
        // uniswap V3: https://github.com/Uniswap/v3-core/blob/main/contracts/interfaces/pool/IUniswapV3PoolState.sol#L12
        // velodrome slipstream: https://github.com/velodrome-finance/slipstream/blob/main/contracts/core/interfaces/pool/ICLPoolState.sol#L12
        tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        uint256 length = info.ammPositionIds.length;
        IAmmModule.AmmPosition[] memory positions = new IAmmModule.AmmPosition[](length);
        for (uint256 i = 0; i < length; i++) {
            positions[i] = ammModule.getAmmPosition(info.ammPositionIds[i]);
        }
        return calculateTarget(sqrtPriceX96, tick, positions, strategyParams);
    }

    /// @inheritdoc IPulseStrategyModule
    function calculateTarget(
        uint160 sqrtPriceX96,
        int24 tick,
        IAmmModule.AmmPosition[] memory positions,
        StrategyParams memory strategyParams
    ) public pure returns (bool isRebalanceRequired, ICore.TargetPositionInfo memory target) {
        if (strategyParams.strategyType == StrategyType.Tamper) {
            return calculateTargetTamper(sqrtPriceX96, tick, positions, strategyParams);
        } else {
            return calculateTargetPulse(sqrtPriceX96, tick, positions, strategyParams);
        }
    }
}
