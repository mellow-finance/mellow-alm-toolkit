// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title Oracle Interface
 * @dev Interface for interacting with oracles that provide price information for liquidity pools.
 * Allows contracts to query such oracles for price information pertinent to specific pools.
 */
interface IOracle {
    /**
     * @dev Struct to represent security parameters for the Velo Oracle.
     * Defines the criteria for detecting Miner Extractable Value (MEV) manipulations based on historical observations.
     * These parameters are crucial for safeguarding against price manipulations by evaluating price movements over time.
     *
     * In the `ensureNoMEV` function, these parameters are utilized as follows:
     * - The function examines the last `lookback + 1` observations, which contain cumulative time-weighted ticks.
     * - From these observations, it calculates `lookback` average ticks. Considering the current spot tick, the function then computes `lookback`
     * deltas between them.
     * - If any of these deltas is greater in magnitude than `maxAllowedDelta`, the function reverts with the `PriceManipulationDetected` error,
     * indicating a potential MEV manipulation attempt.
     * - If there are insufficient observations at any step of the process, the function reverts with the `NotEnoughObservations` error,
     * indicating that the available data is not adequate for a reliable MEV check.
     *
     * Parameters:
     * @param lookback The number of historical observations to analyze, not including the most recent observation.
     * This parameter determines the depth of the historical data analysis for MEV detection. The oracle function effectively
     * examines `lookback + 1` observations to include the current state in the analysis, offering a comprehensive view of market behavior.
     * @param maxAllowedDelta The threshold for acceptable deviation between average ticks within the lookback period and the current tick.
     * This value defines the boundary for normal versus manipulative market behavior, serving as a critical parameter in identifying
     * potential price manipulations.
     * @param maxAge The maximum age of observations to consider for analysis. This parameter ensures that the oracle only
     * uses recent observations. Older data points are excluded from the analysis to maintain
     * the integrity of the MEV detection mechanism.
     */
    struct SecurityParams {
        uint16 lookback; // Maximum number of historical data points to consider for analysis
        uint32 maxAge; // Maximum age of observations to be used in the analysis
        int24 maxAllowedDelta; // Maximum allowed change between data points to be considered valid
    }

    /**
     * @dev Retrieves the price information from an oracle for a given pool.
     * This method returns the square root of the price formatted in a fixed-point number with 96 bits of precision,
     * along with the tick value associated with the pool's current state. This information is essential
     * for contracts that need to perform calculations or make decisions based on the current price dynamics
     * of tokens within a liquidity pool.
     *
     * @param pool The address of the liquidity pool for which price information is requested.
     * @return sqrtPriceX96 The square root of the current price in the pool, represented as a 96-bit fixed-point number.
     * @return tick The current tick value of the pool, which is an integral value representing the price level.
     */
    function getOraclePrice(
        address pool
    ) external view returns (uint160 sqrtPriceX96, int24 tick);

    /**
     * @dev Ensures that there is no Miner Extractable Value (MEV) opportunity for the specified pool
     * based on the current transaction and market conditions. MEV can lead to adverse effects like front-running
     * or sandwich attacks, where miners or other participants can exploit users' transactions for profit.
     * This method allows contracts to verify the absence of such exploitable conditions before proceeding
     * with transactions that might otherwise be vulnerable to MEV.
     *
     * @param pool The address of the pool for which MEV conditions are being checked.
     * @param params Additional parameters that may influence the MEV check, such as transaction details or market conditions.
     */
    function ensureNoMEV(
        address pool,
        SecurityParams memory params
    ) external view;

    /**
     * @dev Validates the security parameters provided to the oracle.
     * This method allows contracts to ensure that the parameters they intend to use for oracle interactions
     * conform to expected formats, ranges, or other criteria established by the oracle for secure operation.
     * It's a preemptive measure to catch and correct potential issues in the parameters that could affect
     * the reliability or accuracy of the oracle's data.
     *
     * @param params The security parameters to be validated by the oracle.
     */
    function validateSecurityParams(SecurityParams memory params) external view;
}
