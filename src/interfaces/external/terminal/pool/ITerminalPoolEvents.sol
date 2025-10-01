// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
pragma abicoder v2;

import "../libraries/CollectAmounts.sol";

/// @title Events emitted by a pool
/// @notice Contains all events emitted by the pool
interface ITerminalPoolEvents {
    /// @notice Emitted exactly once by a pool when #initialize is first called on the pool
    /// @dev Mint/Burn/Swap cannot be emitted by the pool before Initialize
    /// @param sqrtPriceX96 The initial sqrt price of the pool, as a Q64.96
    /// @param tick The initial tick of the pool, i.e. log base 1.0001 of the starting price of the pool
    event Initialize(uint160 sqrtPriceX96, int24 tick);

    /// @notice Emitted exactly once by a pool when #setGauge is first called on the pool
    /// @param gauge The address of the gauge contract
    event SetGauge(address gauge);

    /// @notice Emitted when liquidity is minted for a given position
    /// @param sender The address that minted the liquidity
    /// @param owner The owner of the position and recipient of any minted liquidity
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param isStaked Whether the minted liquidity is staked
    /// @param amount The amount of liquidity minted to the position range
    /// @param amount0 How much token0 was required for the minted liquidity
    /// @param amount1 How much token1 was required for the minted liquidity
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        bool isStaked,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted when tokens are collected by the owner of a position
    /// @dev Collect events may be emitted with zero of an amount if the caller chooses not to collect any token
    /// @param owner The owner of the position for which revenue is collected
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param isStaked Whether the position's liquidity is staked
    /// @param amounts The amount of each token collected
    event Collect(
        address indexed owner,
        address recipient,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        bool isStaked,
        CollectAmounts.Info amounts
    );

    /// @notice Emitted when a position's liquidity is removed
    /// @dev Does not withdraw any fees earned by the liquidity position, which must be withdrawn via #collect
    /// @param owner The owner of the position for which liquidity is removed
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param isStaked Whether the burnt liquidity was staked
    /// @param amount The amount of liquidity to remove
    /// @param amount0 The amount of token0 withdrawn
    /// @param amount1 The amount of token1 withdrawn
    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        bool isStaked,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted by the pool for any swaps between token0 and token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param recipient The address that received the output of the swap
    /// @param amount0 The delta of the token0 balance of the pool
    /// @param amount1 The delta of the token1 balance of the pool
    /// @param sqrtPriceX96 The sqrt(price) of the pool after the swap, as a Q64.96
    /// @param liquidity The liquidity of the pool after the swap
    /// @param tick The log base 1.0001 of price of the pool after the swap
    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    /// @notice Emitted by the pool for any flashes of token0/token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param recipient The address that received the tokens from flash
    /// @param amount0 The amount of token0 that was flashed
    /// @param amount1 The amount of token1 that was flashed
    /// @param paid0 The amount of token0 paid for the flash, which can exceed the amount0 plus the fee
    /// @param paid1 The amount of token1 paid for the flash, which can exceed the amount1 plus the fee
    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1
    );

    /// @notice Emitted by the pool for increases to the number of observations that can be stored
    /// @dev observationCardinalityNext is not the observation cardinality until an observation is written at the index
    /// just before a mint/swap/burn.
    /// @param observationCardinalityNextOld The previous value of the next observation cardinality
    /// @param observationCardinalityNextNew The updated value of the next observation cardinality
    event IncreaseObservationCardinalityNext(
        uint16 observationCardinalityNextOld, uint16 observationCardinalityNextNew
    );

    /// @notice Emitted when the unstaked tax is changed in the pool
    /// @param feeTaxOld The previous value of the unstaked fee tax
    /// @param yieldTaxOld The previous value of the unstaked yield tax
    /// @param feeTaxNew The new value of the unstaked fee tax
    /// @param yieldTaxNew The new value of the unstaked yield tax
    event SetUnstakedTax(uint8 feeTaxOld, uint8 yieldTaxOld, uint8 feeTaxNew, uint8 yieldTaxNew);

    /// @notice Emitted when the accrued gauge revenue is collected by the gauge
    /// @param amount0 The amount of token0 gauge fees that is withdrawn
    /// @param amount0 The amount of token1 gauge fees that is withdrawn
    /// @param yield0 The amount of yield from token0 that is withdrawn
    /// @param yield1 The amount of yield from token1 that is withdrawn
    event CollectGauge(uint128 amount0, uint128 amount1, uint128 yield0, uint128 yield1);
}
