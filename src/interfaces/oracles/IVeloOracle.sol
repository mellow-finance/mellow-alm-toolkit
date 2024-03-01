// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../external/velo/ICLPool.sol";
import "./IOracle.sol";

/**
 * @title VeloOracle
 * @dev A contract that implements the IOracle interface for Velo pools.
 */
interface IVeloOracle is IOracle {
    error InvalidLength();
    error InvalidParams();
    error PriceManipulationDetected();
    error NotEnoughObservations();

    /**
     * @dev Struct representing the security parameters for the Velo Oracle.
     */
    struct SecurityParams {
        uint16 lookback; // Number of historical data points to consider
        int24 maxAllowedDelta; // Maximum allowed change in the data points
    }

    /**
     * @dev Ensures that there is no Miner Extractable Value (MEV) manipulation in the CLPool.
     * @param poolAddress The address of the Velo pool.
     * @param params The parameters for security checks.
     * @notice throws PriceManipulationDetected if MEV manipulation is detected.
     */
    function ensureNoMEV(
        address poolAddress,
        bytes memory params
    ) external view;

    /**
     * @dev Retrieves the price information from an Velo pool oracle.
     * @param pool The address of the Velo pool.
     * @return uint160 square root price of the Velo pool.
     * @return int24 tick of the Velo pool.
     * @notice throws NotEnoughObservations if there are not enough observations in the pool.
     */
    function getOraclePrice(
        address pool
    ) external view override returns (uint160, int24);
    /**
     * @dev Validates the security parameters.
     * @param params The security parameters to be validated.
     * @notice This function checks if the security parameters are valid. It decodes the `params` parameter
     * and checks if the `lookback` value is non-zero and the `maxAllowedDelta` value is greater than or equal to zero.
     * If any of these conditions are not met, it reverts with an `InvalidParams` error.
     */
    function validateSecurityParams(bytes memory params) external view;
}
