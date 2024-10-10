// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../interfaces/modules/strategies/IPulseStrategyModuleV2.sol";
import "../../libraries/external/TickMath.sol";

contract PulseStrategyModuleV2 is IPulseStrategyModuleV2 {
    /// @inheritdoc IPulseStrategyModuleV2
    uint256 public constant Q96 = 2 ** 96;

    /// @inheritdoc IStrategyModule
    function validateStrategyParams(
        StrategyParams memory params
    ) external pure override {
        if (
            params.width == 0 ||
            params.tickSpacing == 0 ||
            params.width % params.tickSpacing != 0 ||
            params.tickNeighborhood * 2 > params.width ||
            (params.strategyType !=
                StrategyType.Original &&
                params.tickNeighborhood != 0)
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
        if (info.ammPositionIds.length != 1) {
            revert InvalidLength();
        }
        IAmmModule.AmmPosition memory position = ammModule.getAmmPosition(
            info.ammPositionIds[0]
        );
        (uint160 sqrtPriceX96, int24 tick) = oracle.getOraclePrice(info.pool);
        return
            calculateTarget(
                sqrtPriceX96,
                tick,
                position.tickLower,
                position.tickUpper,
                info.coreParams.strategyParams
            );
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
        IPulseStrategyModule.StrategyParams memory params
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
            params.strategyType ==
            StrategyType.LazyDescending &&
            sqrtPriceX96 >= sqrtPriceX96Lower
        ) return (tickLower, tickUpper);

        if (
            params.strategyType ==
            StrategyType.LazyAscending &&
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

    /// @inheritdoc IPulseStrategyModuleV2
    function calculateTarget(
        uint160 sqrtPriceX96,
        int24 tick,
        int24 tickLower,
        int24 tickUpper,
        IPulseStrategyModule.StrategyParams memory params
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

    function _max(int24 a, int24 b) private pure returns (int24) {
        if (a < b) return b;
        return a;
    }
}
