// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../interfaces/modules/strategies/IPulseStrategyModule.sol";
import "../../libraries/external/TickMath.sol";

contract PulseStrategyModule is IPulseStrategyModule {
    using Math for uint256;
    /// @inheritdoc IPulseStrategyModule
    uint256 public constant Q96 = 2 ** 96;

    /// @inheritdoc IStrategyModule
    function validateStrategyParams(
        bytes memory params_
    ) external pure override {
        if (params_.length != 0xa0) revert InvalidLength();
        StrategyParams memory params = abi.decode(params_, (StrategyParams));
        if (
            params.width == 0 ||
            params.tickSpacing == 0 ||
            params.width % params.tickSpacing != 0 ||
            params.tickNeighborhood * 2 > params.width ||
            (params.strategyType != StrategyType.Original &&
                params.tickNeighborhood != 0) ||
            (params.strategyType == StrategyType.Tamper && params.maxLiquidityRatioDeviationX96 == 0)
        ) revert InvalidParams();
    }

    /// @inheritdoc IStrategyModule
    function getTargets(
        ICore.ManagedPositionInfo memory info,
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
        StrategyParams memory strategyParams = abi.decode(
            info.strategyParams,
            (StrategyParams)
        );
        (uint160 sqrtPriceX96, int24 tick) = oracle.getOraclePrice(info.pool);
        if (strategyParams.strategyType == StrategyType.Tamper) {
            if (info.ammPositionIds.length != 2) revert InvalidLength();

            IAmmModule.AmmPosition memory lowerPosition = ammModule
                .getAmmPosition(info.ammPositionIds[0]);
            IAmmModule.AmmPosition memory upperPosition = ammModule
                .getAmmPosition(info.ammPositionIds[1]);
            return
                calculateTargetTamper(
                    sqrtPriceX96,
                    lowerPosition,
                    upperPosition,
                    strategyParams
                );
        } else {
            if (info.ammPositionIds.length != 1) {
                revert InvalidLength();
            }
            IAmmModule.AmmPosition memory position = ammModule.getAmmPosition(
                info.ammPositionIds[0]
            );
            return
                calculateTargetPulse(
                    sqrtPriceX96,
                    tick,
                    position.tickLower,
                    position.tickUpper,
                    strategyParams
                );
        }
    }

    function _calculatePenalty(
        uint160 sqrtPriceX96,
        uint160 sqrtPriceX96Lower,
        uint160 sqrtPriceX96Upper
    ) private pure returns (uint256) {
        if (
            sqrtPriceX96 < sqrtPriceX96Lower || sqrtPriceX96 > sqrtPriceX96Upper
        ) return type(uint256).max; // inf

        return
            Math.max(
                Math.mulDiv(sqrtPriceX96, Q96, sqrtPriceX96Lower),
                Math.mulDiv(sqrtPriceX96Upper, Q96, sqrtPriceX96)
            );
    }

    /*
        width = 2
        tickSpacing = 1
        spotTick = 1.9999 
        tick = 1
        sqrtPrice = getSqrtRatioAtTick(1.9999)

        prev result:
        [0, 2]

        new result:
        [1, 3]

        // Max(spotTick - tickLower, tickUpper - spotTick)
        //  |
        //  V
        // Max(sqrtPrice / sqrtPriceLower, sqrtPriceUpper / sqrtPrice)
    */
    function _centeredPosition(
        uint160 sqrtPriceX96,
        int24 tick,
        int24 positionWidth,
        int24 tickSpacing
    ) private pure returns (int24 targetTickLower, int24 targetTickUpper) {
        targetTickLower = tick - positionWidth / 2;
        int24 remainder = targetTickLower % tickSpacing;
        if (remainder < 0) remainder += tickSpacing;
        targetTickLower -= remainder;
        targetTickUpper = targetTickLower + positionWidth;

        uint256 penalty = _calculatePenalty(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(targetTickLower),
            TickMath.getSqrtRatioAtTick(targetTickUpper)
        );
        uint256 leftPenalty = _calculatePenalty(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(targetTickLower - tickSpacing),
            TickMath.getSqrtRatioAtTick(targetTickUpper - tickSpacing)
        );
        uint256 rightPenalty = _calculatePenalty(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(targetTickLower + tickSpacing),
            TickMath.getSqrtRatioAtTick(targetTickUpper + tickSpacing)
        );

        if (penalty <= leftPenalty && penalty <= rightPenalty)
            return (targetTickLower, targetTickUpper);

        if (leftPenalty <= rightPenalty) {
            targetTickLower -= tickSpacing;
            targetTickUpper -= tickSpacing;
        } else {
            targetTickLower += tickSpacing;
            targetTickUpper += tickSpacing;
        }
    }

    function _calculatePosition(
        uint160 sqrtPriceX96,
        int24 tick,
        int24 tickLower,
        int24 tickUpper,
        StrategyParams memory params
    ) private pure returns (int24 targetTickLower, int24 targetTickUpper) {
        if (params.width != tickUpper - tickLower)
            return
                _centeredPosition(
                    sqrtPriceX96,
                    tick,
                    params.width,
                    params.tickSpacing
                );

        if (
            sqrtPriceX96 >=
            TickMath.getSqrtRatioAtTick(tickLower + params.tickNeighborhood) &&
            sqrtPriceX96 <=
            TickMath.getSqrtRatioAtTick(tickUpper - params.tickNeighborhood)
        ) return (tickLower, tickUpper);

        if (params.strategyType == StrategyType.Original)
            return
                _centeredPosition(
                    sqrtPriceX96,
                    tick,
                    params.width,
                    params.tickSpacing
                );

        uint160 sqrtPriceX96Lower = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceX96Upper = TickMath.getSqrtRatioAtTick(tickUpper);

        if (
            params.strategyType == StrategyType.LazyDescending &&
            sqrtPriceX96 >= sqrtPriceX96Lower
        ) return (tickLower, tickUpper);

        if (
            params.strategyType == StrategyType.LazyAscending &&
            sqrtPriceX96 <= sqrtPriceX96Upper
        ) return (tickLower, tickUpper);
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
            if (
                TickMath.getSqrtRatioAtTick(tick) != sqrtPriceX96 ||
                remainder != 0
            ) {
                targetTickLower += params.tickSpacing;
            }
        }
        targetTickUpper = targetTickLower + params.width;
    }

    function calculateTargetPulse(
        uint160 sqrtPriceX96,
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
            sqrtPriceX96,
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

    /**
     * @dev Calculates the target lower tick and liquidity ratio of the lower position based on the given parameters.
     * @param sqrtPriceX96 The current sqrtPriceX96 of the market, indicating the instantaneous price level.
     * @param tickLower The lower tick value.
     * @param half Half of the width of each position.
     * @return targetLower The calculated target lower tick.
     * @return liquidityRatioX96 The calculated liquidity ratio.
     */
    function _getCrossedPositions(
        uint256 sqrtPriceX96,
        int24 tickLower,
        int24 half
    ) private pure returns (int24 targetLower, uint256 liquidityRatioX96) {
        int24 width = half * 2;
        uint256 sqrtPriceX96LowerHalf = TickMath.getSqrtRatioAtTick(
            tickLower + half
        );
        uint256 sqrtPriceX96LowerWidth = TickMath.getSqrtRatioAtTick(
            tickLower + width
        );
        if (sqrtPriceX96 < sqrtPriceX96LowerHalf) {
            targetLower = tickLower - half;
        } else if (sqrtPriceX96 > sqrtPriceX96LowerWidth) {
            targetLower = tickLower + half;
        } else {
            targetLower = tickLower;
        }
        if (sqrtPriceX96LowerHalf >= sqrtPriceX96) {
            liquidityRatioX96 = Q96;
        } else if (sqrtPriceX96LowerWidth <= sqrtPriceX96) {
            liquidityRatioX96 = 0;
        } else {
            /**
             * @dev shift sqrtPrices for (x+w/2), in ticks [x + w/2, x + w] -> [0, w/2]
             * so sqrtPriceX96Shifted belongs to [Q96, sqrtPriceX96Half]
             * liquidityRatioX96 can be calculated as (sqrtPriceX96Half - sqrtPriceX96Shifted)/(sqrtPriceX96Half - Q96) that is equivalent to
             * (1 - 2 * tickShifted/w) in ticks, where tickShifted belongs to [0, w/2]
             */
            uint256 sqrtPriceX96Half = TickMath.getSqrtRatioAtTick(half);
            uint256 sqrtPriceX96Shifted = sqrtPriceX96.mulDiv(
                Q96,
                sqrtPriceX96LowerHalf
            );
            liquidityRatioX96 = uint256(sqrtPriceX96Half - sqrtPriceX96Shifted)
                .mulDiv(Q96, sqrtPriceX96Half - Q96);
        }
    }

    function calculateTargetTamper(
        uint256 sqrtPriceX96,
        IAmmModule.AmmPosition memory lowerPosition,
        IAmmModule.AmmPosition memory upperPosition,
        StrategyParams memory params
    )
        public
        pure
        returns (
            bool isRebalanceRequired,
            ICore.TargetPositionInfo memory target
        )
    {
        int24 width = lowerPosition.tickUpper - lowerPosition.tickLower;
        int24 half = width / 2;
        int24 tickLower = lowerPosition.tickLower;

        if (
            width % 2 != 0 ||
            upperPosition.tickLower != lowerPosition.tickLower + half ||
            upperPosition.tickUpper != lowerPosition.tickUpper + half
        ) {
            revert InvalidPosition();
        }

        (int24 targetLower, uint256 liquidityRatioX96) = _getCrossedPositions(
            sqrtPriceX96,
            tickLower,
            half
        );
        /// @dev default value in case of empty positions
        uint256 ratioX96 = Q96;
        uint256 totalLiquidity = lowerPosition.liquidity +
            upperPosition.liquidity;
        if (totalLiquidity > 0) {
            ratioX96 = Math.mulDiv(
                lowerPosition.liquidity,
                Q96,
                totalLiquidity
            );
        }

        target.lowerTicks = new int24[](2);
        target.upperTicks = new int24[](2);
        target.liquidityRatiosX96 = new uint256[](2);
        target.lowerTicks[0] = targetLower;
        target.upperTicks[0] = targetLower + width;
        target.liquidityRatiosX96[0] = ratioX96;
        target.lowerTicks[1] = targetLower + half;
        target.upperTicks[1] = targetLower + half + width;
        target.liquidityRatiosX96[1] = Q96 - ratioX96;

        if (
            targetLower == lowerPosition.tickLower &&
            _checkDeviation(
                ratioX96,
                liquidityRatioX96,
                params.maxLiquidityRatioDeviationX96
            )
        ) return (true, target);
        if (
            targetLower + half == lowerPosition.tickLower &&
            _checkDeviation(
                Q96 - ratioX96,
                liquidityRatioX96,
                params.maxLiquidityRatioDeviationX96
            )
        ) return (true, target);
        if (
            targetLower - half == lowerPosition.tickLower &&
            _checkDeviation(
                ratioX96,
                Q96 - liquidityRatioX96,
                params.maxLiquidityRatioDeviationX96
            )
        ) return (true, target);

        return (false, target);
    }

    function _max(int24 a, int24 b) private pure returns (int24) {
        if (a < b) return b;
        return a;
    }

    /**
     * @dev Checks if the difference between two numbers exceeds a specified deviation.
     * @param a The first number.
     * @param b The second number.
     * @param deviation The maximum allowed difference between the two numbers.
     * @return bool true if the difference between `a` and `b` exceeds `deviation`, false otherwise.
     */
    function _checkDeviation(
        uint256 a,
        uint256 b,
        uint256 deviation
    ) internal pure returns (bool) {
        if (a + deviation > b || b + deviation > a) return true;
        return false;
    }
}
