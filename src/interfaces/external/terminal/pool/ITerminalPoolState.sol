// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
pragma abicoder v2;

import "../libraries/CollectAmounts.sol";

/// @title Pool state that can change
/// @notice These methods compose the pool's state, and can change with any frequency including multiple times
/// per transaction
interface ITerminalPoolState {
    /// @notice The 0th storage slot in the pool stores many values, and is exposed as a single method to save gas
    /// when accessed externally.
    /// @return sqrtPriceX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
    /// tick The current tick of the pool, i.e. according to the last tick transition that was run.
    /// This value may not always be equal to SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96) if the price is on a tick
    /// boundary.
    /// observationIndex The index of the last oracle observation that was written,
    /// observationCardinality The current maximum number of observations stored in the pool,
    /// observationCardinalityNext The next maximum number of observations, to be updated when the observation.
    /// unstakedFeeTax The tax levied on fees earned by unstaked positions in the pool, represented as a denominator
    /// unstakedYieldTax The tax levied on yield earned by unstaked positions in the pool, represented as a denominator
    /// unlocked Whether the pool is currently locked to reentrancy
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 unstakedFeeTax,
            uint8 unstakedYieldTax,
            bool unlocked
        );

    /// @notice The growth of revenue per unit of liquidity for the entire life of the pool
    /// @dev This does not include the reward and yield that has been dripped since the last update of growth globals to the current timestamp. To update, call #updateGrowthGlobals()
    /// @return revenueGrowthGlobal0X128 The revenue growth as a Q128.128 fees of token0 collected per unit of unstaked liquidity for the entire life of the pool,
    /// revenueGrowthGlobal1X128 The revenue growth as a Q128.128 fees of token1 collected per unit of unstaked liquidity for the entire life of the pool,
    /// rewardGrowthGlobalX128 The reward growth as a Q128.128 collected per unit of staked liquidity for the entire life of the pool
    function growthGlobals()
        external
        view
        returns (
            uint256 revenueGrowthGlobal0X128,
            uint256 revenueGrowthGlobal1X128,
            uint256 rewardGrowthGlobalX128
        );

    /// @notice The amounts of revenue that is owed to the gauge
    /// @dev Gauge revenue will never exceed uint128 max in any token
    function gaugeRevenue()
        external
        view
        returns (uint128 fee0, uint128 fee1, uint128 yield0, uint128 yield1);

    /// @notice The currently in range liquidity available to the pool
    /// @dev This value has no relationship to the total liquidity across all ticks
    function liquidity() external view returns (uint128);

    /// @notice The currently in range staked liquidity available to the pool
    /// @dev This value has no relationship to the total staked liquidity across all ticks
    function stakedLiquidity() external view returns (uint128);

    /// @notice The information about the pending yield from token0
    /// @param amount The total amount of yield in token0 being dripped
    /// @param endTime The timestamp when the drip will be complete
    /// @param lastDrip The timestamp when the last drip occurred
    function pendingYield0()
        external
        view
        returns (uint128 amount, uint32 endTime, uint32 lastDrip);

    /// @notice The information about the pending yield from token1
    /// @param amount The total amount of yield in token1 being dripped
    /// @param endTime The timestamp when the drip will be complete
    /// @param lastDrip The timestamp when the last drip occurred
    function pendingYield1()
        external
        view
        returns (uint128 amount, uint32 endTime, uint32 lastDrip);

    /// @notice Look up information about a specific tick in the pool
    /// @param tick The tick to look up
    /// @return liquidityGross the total amount of position liquidity that uses the pool either as tick lower or
    /// tick upper,
    /// liquidityNet how much liquidity changes when the pool price crosses the tick,
    /// stakedLiquidityNet how much staked liquidity changes when the pool price crosses the tick,
    /// revenueGrowthOutside0X128 the revenue growth on the other side of the tick from the current tick in token0,
    /// revenueGrowthOutside1X128 the revenue growth on the other side of the tick from the current tick in token1,
    /// rewardGrowthOutsideX128 the reward growth on the other side of the tick from the current tick,
    /// tickCumulativeOutside the cumulative tick value on the other side of the tick from the current tick
    /// secondsPerLiquidityOutsideX128 the seconds spent per liquidity on the other side of the tick from the current tick,
    /// secondsOutside the seconds spent on the other side of the tick from the current tick,
    /// initialized Set to true if the tick is initialized, i.e. liquidityGross is greater than 0, otherwise equal to false.
    /// Outside values can only be used if the tick is initialized, i.e. if liquidityGross is greater than 0.
    /// In addition, these values are only relative and must be used only in comparison to previous snapshots for
    /// a specific position.
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            int128 stakedLiquidityNet,
            uint256 revenueGrowthOutside0X128,
            uint256 revenueGrowthOutside1X128,
            uint256 rewardGrowthOutsideX128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    /// @notice Returns 256 packed tick initialized boolean values. See TickBitmap for more information
    function tickBitmap(int16 wordPosition) external view returns (uint256);

    /// @notice Returns the information about a position by the position's key
    /// @param key The position's key is a hash of a preimage composed by the owner, tickLower and tickUpper
    /// @return _liquidity The amount of liquidity in the position,
    /// Returns revenueGrowthInside0LastX128 revenue growth of token0 inside the tick range as of the last mint/burn/poke,
    /// Returns revenueGrowthInside1LastX128 revenue growth of token1 inside the tick range as of the last mint/burn/poke,
    /// Returns owed The amounts of each token owed to the position
    function positions(bytes32 key)
        external
        view
        returns (
            uint128 _liquidity,
            uint256 revenueGrowthInside0LastX128,
            uint256 revenueGrowthInside1LastX128,
            uint256 rewardGrowthInsideLastX128,
            CollectAmounts.Info memory owed
        );

    /// @notice Returns data about a specific observation index
    /// @param index The element of the observations array to fetch
    /// @dev You most likely want to use #observe() instead of this method to get an observation as of some amount of time
    /// ago, rather than at a specific index in the array.
    /// @return blockTimestamp The timestamp of the observation,
    /// Returns tickCumulative the tick multiplied by seconds elapsed for the life of the pool as of the observation timestamp,
    /// Returns secondsPerLiquidityCumulativeX128 the seconds per in range liquidity for the life of the pool as of the observation timestamp,
    /// Returns initialized whether the observation has been initialized and the values are safe to use
    function observations(uint256 index)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );
}
