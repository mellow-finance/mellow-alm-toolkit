// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.6;
pragma abicoder v2;

/// @title An interface for a contract that is capable of deploying Terminal Pools
/// @notice A contract that constructs a pool must implement this to pass arguments to the pool
/// @dev This is used to avoid having constructor arguments in the pool contract, which results in the init code hash
/// of the pool being constant allowing the CREATE2 address of the pool to be cheaply computed on-chain
interface ITerminalPoolDeployer {
    struct Parameters {
        // The factory address
        address factory;
        // The address of the TERM token
        address term;
        // The first token of the pool by address sort order
        address token0;
        // The second token of the pool by address sort order
        address token1;
        // The fee collected upon every swap in the pool, denominated in hundredths of a bip
        uint24 fee;
        // The minimum number of ticks between initialized ticks
        int24 tickSpacing;
        // Whether token0 has redeemable yield
        bool redeemable0;
        // Whether token1 has redeemable yield
        bool redeemable1;
        // The maximum liquidity allocation for a single tick
        uint128 maxLiquidityPerTick;
    }
    /// @notice Get the parameters to be used in constructing the pool, set transiently during pool creation.
    /// @dev Called by the pool constructor to fetch the parameters of the pool

    function parameters() external view returns (Parameters memory);
}
