// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../external/velo/ICLPool.sol";
import "./IOracle.sol";

/**
 * @title VeloOracle
 * @dev Implements the IOracle interface specifically for Velo pools, providing price information and MEV protection functionalities.
 */
interface IVeloOracle is IOracle {
    // Custom errors to handle various validation and operational failures
    error InvalidLength(); // Thrown when input data length is incorrect
    error InvalidParams(); // Thrown when security parameters do not meet expected criteria
    error PriceManipulationDetected(); // Thrown when potential price manipulation is detected
    error NotEnoughObservations(); // Thrown when there are not enough data points for reliable calculation

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
     */
    struct SecurityParams {
        uint16 lookback; // Number of historical data points to consider for analysis
        int24 maxAllowedDelta; // Maximum allowed change between data points to be considered valid
    }
}
