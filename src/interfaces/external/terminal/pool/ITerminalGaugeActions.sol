// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Permissioned pool actions
/// @notice Contains pool methods that may only be called by the gauge
interface ITerminalGaugeActions {
    /// @notice Set the gauge of the pool
    /// Only callable if the gauge has not been set
    /// @param gauge The address of the gauge
    function setGauge(address gauge) external;

    /// @notice Set the tax levied on fees/yield earned by unstaked positions in the pool
    /// Only the gauge may call this method
    /// @param feeTax new unstaked fee tax of the pool, represented as a denominator (1/x)
    /// @param yieldTax new unstaked yield tax of the pool, represented as a denominator (1/x)
    function setUnstakedTax(uint8 feeTax, uint8 yieldTax) external;

    /// @notice Collect the gauge fees accrued to the pool
    /// Only the gauge may call this method
    /// @return amount0 The gauge fee collected in token0
    /// @return amount1 The gauge fee collected in token1
    /// @return yield0 The gauge yield collected from token0
    /// @return yield1 The gauge yield collected from token1
    function collectGaugeRevenue()
        external
        returns (uint128 amount0, uint128 amount1, uint128 yield0, uint128 yield1);
}
