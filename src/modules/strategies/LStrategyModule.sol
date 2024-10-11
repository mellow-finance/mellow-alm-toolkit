// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../interfaces/modules/IStrategyModule.sol";
import "../../libraries/external/TickMath.sol";

/**
 * @title LStrategyModule
 * @dev A strategy module contract that implements the optimised for alm base version LStrategy.
 */
contract LStrategyModule is IStrategyModule {
    using Math for uint256;
    // Error definitions
    error InvalidParams();
    error InvalidLength();
    error InvalidPosition();

    // Constants
    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D4 = 1e4;

    /**
     * @dev Struct representing the parameters for a strategy.
     * @param maxLiquidityRatioDeviationX96 The maximum allowed deviation of the liquidity ratio for lower position.
     */
    struct StrategyParams {
        uint256 maxLiquidityRatioDeviationX96;
    }

    /**
     * @dev Validates the strategy parameters.
     * @param params The encoded strategy parameters.
     * @notice This function decodes the `params` and checks if the `maxLiquidityRatioDeviationX96` is valid.
     *         If the `maxLiquidityRatioDeviationX96` is 0 or greater than half of Q96, it reverts with an `InvalidParams` error.
     */
    function validateStrategyParams(
        bytes memory params
    ) external pure override {
        StrategyParams memory strategyParams = abi.decode(
            params,
            (StrategyParams)
        );
        if (
            strategyParams.maxLiquidityRatioDeviationX96 == 0 ||
            strategyParams.maxLiquidityRatioDeviationX96 > Q96 / 2
        ) {
            revert InvalidParams();
        }
    }

    /**
     * @dev Calculates the target lower tick and liquidity ratio of the lower position based on the given parameters.
     * @param sqrtPriceX96 The current sqrtPriceX96 of the market, indicating the instantaneous price level.
     * @param tickLower The lower tick value.
     * @param half Half of the width of each position.
     * @return targetLower The calculated target lower tick.
     * @return liquidityRatioX96 The calculated liquidity ratio.
     */
    function calculateTarget(
        uint256 sqrtPriceX96,
        int24 tickLower,
        int24 half
    ) public pure returns (int24 targetLower, uint256 liquidityRatioX96) {
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

    /**
     * @dev Checks if the difference between two numbers exceeds a specified deviation.
     * @param a The first number.
     * @param b The second number.
     * @param deviation The maximum allowed difference between the two numbers.
     * @return bool true if the difference between `a` and `b` exceeds `deviation`, false otherwise.
     */
    function checkDeviation(
        uint256 a,
        uint256 b,
        uint256 deviation
    ) public pure returns (bool) {
        if (a + deviation > b || b + deviation > a) return true;
        return false;
    }

    /**
     * @dev Retrieves the target positions for rebalancing based on the given ManagedPositionInfo, AmmModule, and Oracle.
     * @param info The ManagedPositionInfo containing the pool and token IDs.
     * @param ammModule The AmmModule contract.
     * @param oracle The Oracle contract.
     * @return bool A boolean indicating whether rebalancing is required.
     * @return target The TargetPositionInfo containing the target positions for rebalancing.
     */
    function getTargets(
        ICore.ManagedPositionInfo memory info,
        IAmmModule ammModule,
        IOracle oracle
    )
        external
        view
        override
        returns (bool, ICore.TargetPositionInfo memory target)
    {
        (uint160 sqrtPriceX96, ) = oracle.getOraclePrice(info.pool);
        if (info.ammPositionIds.length != 2) revert InvalidLength();
        IAmmModule.AmmPosition memory lowerPosition = ammModule.getAmmPosition(
            info.ammPositionIds[0]
        );
        IAmmModule.AmmPosition memory upperPosition = ammModule.getAmmPosition(
            info.ammPositionIds[1]
        );

        int24 width = lowerPosition.tickUpper - lowerPosition.tickLower;
        int24 half = width / 2;
        if (
            width % 2 != 0 ||
            upperPosition.tickLower != lowerPosition.tickLower + half ||
            upperPosition.tickUpper != lowerPosition.tickUpper + half
        ) {
            revert InvalidPosition();
        }

        (int24 targetLower, uint256 targetRatioX96) = calculateTarget(
            sqrtPriceX96,
            lowerPosition.tickLower,
            half
        );

        uint256 ratioX96 = Math.mulDiv(
            lowerPosition.liquidity,
            Q96,
            lowerPosition.liquidity + upperPosition.liquidity
        );

        target.lowerTicks = new int24[](2);
        target.upperTicks = new int24[](2);
        target.liquidityRatiosX96 = new uint256[](2);
        target.lowerTicks[0] = targetLower;
        target.upperTicks[0] = targetLower + width;
        target.liquidityRatiosX96[0] = ratioX96;
        target.lowerTicks[1] = targetLower + half;
        target.upperTicks[1] = targetLower + half + width;
        target.liquidityRatiosX96[1] = Q96 - ratioX96;

        uint256 maxDeviationX96 = abi
            .decode(info.strategyParams, (StrategyParams))
            .maxLiquidityRatioDeviationX96;

        if (
            targetLower == lowerPosition.tickLower &&
            checkDeviation(ratioX96, targetRatioX96, maxDeviationX96)
        ) return (true, target);
        if (
            targetLower + half == lowerPosition.tickLower &&
            checkDeviation(Q96 - ratioX96, targetRatioX96, maxDeviationX96)
        ) return (true, target);
        if (
            targetLower - half == lowerPosition.tickLower &&
            checkDeviation(ratioX96, Q96 - targetRatioX96, maxDeviationX96)
        ) return (true, target);

        return (false, target);
    }
}
