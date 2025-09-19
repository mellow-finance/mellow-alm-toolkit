// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title Minimal Gauge interface for Terminal AMM
/// @notice Contains a subset of the full Gauge interface that is used by the pool
interface IGaugeMinimal {
    /// @notice Get the increase in reward growth per staked liquidity since the last time this method was called
    /// Only the pool associated to the gauge may call this method
    /// @return rewardGrowthDeltaX128 The amount of reward accrued as a Q128.128 per staked liquidity since the last time this method was called
    function getRewardGrowth(uint256 stakedLiquidity)
        external
        returns (uint256 rewardGrowthDeltaX128);
}
