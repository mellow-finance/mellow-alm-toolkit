// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "../IStrategyModule.sol";

/**
 * @title PulseStrategyModule
 * @dev Implements various strategies for Pulse V1, including Original, Lazy Syncing, Lazy Ascending, and Lazy Descending strategies.
 */
interface IPulseStrategyModule is IStrategyModule {
    // Custom errors to address operation failures
    error InvalidParams(); // Thrown when input parameters are invalid
    error InvalidLength(); // Thrown when an array length is incorrect
    error InvalidPosition(); // Thrown when count of amm position is not equal to 2 in case of Tamper strategy

    // Enum representing different types of strategies
    enum StrategyType {
        Original, // Original Pulse V1 strategy
        LazySyncing, // Lazy syncing strategy
        LazyAscending, // Lazy ascending strategy
        LazyDescending, // Lazy descending strategy
        Tamper // Tamper strategy
    }

    /**
     * @dev Struct for strategy parameters.
     * Encapsulates the details required to execute different types of strategies.
     */
    struct StrategyParams {
        StrategyType strategyType; // Type of strategy
        int24 tickNeighborhood; // Neighborhood of ticks to consider for rebalancing
        int24 tickSpacing; // tickSpacing of the corresponding amm pool
        int24 width; // Width of the interval
        uint256 maxLiquidityRatioDeviationX96; // The maximum allowed deviation of the liquidity ratio for lower position.
    }

    /**
     * @dev Returns the constant value of Q96, representing 2 ** 96.
     * Used for fixed-point arithmetic operations.
     * @return Q96 The constant value 2 ** 96.
     */
    function Q96() external view returns (uint256);

    /**
     * @dev Calculates the target position after rebalance based on the provided strategy parameters and the current market state.
     * This function's behavior varies with the chosen strategy type, adapting to market movements and strategic requirements:
     *
     * Always calculate centered position if provided tickLower and tickUpper are equal,
     * else gets ttargets align strategy type. It should be used only at initial setup.
     *
     * StrategyType.Original (Pulse V1):
     * This is the classic strategy where the position is actively managed within an interval [tickLower, tickUpper].
     * If the market tick moves outside an interval [tickLower + tickNeighborhood, tickUpper - tickNeighborhood],
     * a rebalance is triggered to center the position as closely as possible to the current tick, maintaining the same width.
     * This ensures the position remains effectively aligned with the market.
     *
     * StrategyType.LazySyncing:
     * Supports active position management within the [tickLower, tickUpper] interval, with rebalancing actions triggered under two scenarios:
     *   - If the current tick < tickLower, rebalance to a new position closest to the current tick on the right side, with the same width.
     *   - If the current tick > tickUpper, rebalance to a new position closest to the current tick on the left side, with the same width.
     * This strategy aims to realign the position with the market with minimal adjustments.
     *
     * StrategyType.LazyAscending:
     * Similar to LazySyncing but specifically focuses on ascending market conditions. If the current tick is less than tickLower,
     * it does not trigger a rebalance. Rebalancing is considered only when the market moves upwards beyond the tickUpper,
     * aiming to catch upward trends without reacting to downward movements.
     *
     * StrategyType.LazyDescending:
     * Opposite to LazyAscending, this strategy caters to descending market conditions. If the current tick is greater than tickUpper,
     * it does not prompt a rebalance. The strategy focuses on rebalancing when the market descends below tickLower,
     * aiming to manage downward trends without reacting to upward movements.
     *
     * For each strategy, the function evaluates whether rebalancing is necessary based on the current tick's position relative to the strategy's parameters.
     * If rebalancing is required, it calculates the target position details, ensuring strategic alignment with the current market conditions.
     *
     * @param sqrtPriceX96 The current sqrtPriceX96 of the market, indicating the instantaneous price level.
     * @param tick The current tick of the market, indicating the instantaneous price level.
     * @param tickLower The lower bound tick of the existing position.
     * @param tickUpper The upper bound tick of the existing position.
     * @param params The strategy parameters defining the rebalancing logic, including strategy type, tick neighborhood, and desired position width.
     * @return isRebalanceRequired A boolean indicating if rebalancing is needed based on the current market condition and strategy parameters.
     * @return target Details of the target position if rebalancing is required, including new tick bounds and liquidity distribution.
     */
    function calculateTargetPulse(
        uint160 sqrtPriceX96,
        int24 tick,
        int24 tickLower,
        int24 tickUpper,
        StrategyParams memory params
    )
        external
        pure
        returns (
            bool isRebalanceRequired,
            ICore.TargetPositionInfo memory target
        );

    /**
     * @dev Calculates the target position after rebalance based on the provided strategy parameters and the current market state.
     * This function's behavior varies with the chosen strategy type, adapting to market movements and strategic requirements:
     *
     * Always calculate centered position if provided position(s) has equal lower and upper ticks,
     * else gets ttargets align strategy type. It should be used only at initial setup.
     *
     * StrategyType.Tamper:
     * Handles two crossed positions upper position [tickLower, tickLower+width] and lower [tickLower+width/2, tickLower+width+width/2]
     *   - If tick in range [tickLower+width/2, tickLower+width] it rebalances liquidity between these two position to achieve better utilization.
     *   - If tick < tickLower+width/2 it moves upper position under lower postion
     *   - If tick > tickLower+width it moves lower position above upper postion
     *
     * For each strategy, the function evaluates whether rebalancing is necessary based on the current tick's position relative to the strategy's parameters.
     * If rebalancing is required, it calculates the target position details, ensuring strategic alignment with the current market conditions.
     *
     * @param sqrtPriceX96 The current sqrtPriceX96 of the market, indicating the instantaneous price level.
     * @param lowerPosition The lower position.
     * @param upperPosition The upper position.
     * @param params The strategy parameters defining the rebalancing logic, including strategy type, tick neighborhood, and desired position width.
     * @return isRebalanceRequired A boolean indicating if rebalancing is needed based on the current market condition and strategy parameters.
     * @return target Details of the target position if rebalancing is required, including new tick bounds and liquidity distribution.
     */
    function calculateTargetTamper(
        uint160 sqrtPriceX96,
        int24 tick,
        IAmmModule.AmmPosition memory lowerPosition,
        IAmmModule.AmmPosition memory upperPosition,
        StrategyParams memory params
    )
        external
        pure
        returns (
            bool isRebalanceRequired,
            ICore.TargetPositionInfo memory target
        );
}
