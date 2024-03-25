// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title Oracle Interface
 * @dev Interface for interacting with oracles that provide price information for liquidity pools.
 * Allows contracts to query such oracles for price information pertinent to specific pools.
 */
interface IOracle {
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
    function ensureNoMEV(address pool, bytes memory params) external view;

    /**
     * @dev Validates the security parameters provided to the oracle.
     * This method allows contracts to ensure that the parameters they intend to use for oracle interactions
     * conform to expected formats, ranges, or other criteria established by the oracle for secure operation.
     * It's a preemptive measure to catch and correct potential issues in the parameters that could affect
     * the reliability or accuracy of the oracle's data.
     *
     * @param params The security parameters to be validated by the oracle.
     */
    function validateSecurityParams(bytes memory params) external view;
}
