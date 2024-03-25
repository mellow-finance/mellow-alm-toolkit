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
     * Defines criteria for historical data analysis and threshold settings for MEV detection.
     */
    struct SecurityParams {
        uint16 lookback; // Number of historical data points to consider for analysis
        int24 maxAllowedDelta; // Maximum allowed change between data points to be considered valid
    }
}
