// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title Gauge Interface
interface IGauge {
    /// @notice Thrown when the caller is not the pool associated to the gauge
    error NotPool();

    /// @notice Thrown when the caller is not the Team
    error NotTeam();

    /// @notice Thrown when the caller is not the Govenor
    error NotGovernor();

    /// @notice Thrown when the caller is not the Voter
    error NotVoter();

    /// @notice Emitted when the gauge has flipped the vaults into a new epoch
    event EpochFlipped(uint256 indexed epochStart);

    /// @notice Emitted when reward is notified to the gauge
    event NotifyReward(address indexed sender, uint256 amount);

    /// @notice The address of the voter
    function voter() external view returns (address);

    /// @notice The address of the pool associated to the gauge
    function pool() external view returns (address);

    /// @notice The address of the term token
    function term() external view returns (address);

    /// @notice The address of token0 of the pool
    function token0() external view returns (address);

    /// @notice The address of token1 of the pool
    function token1() external view returns (address);

    /// @notice Whether token0 is redeemable
    function redeemable0() external view returns (bool);

    /// @notice Whether token1 is redeemable
    function redeemable1() external view returns (bool);

    /// @notice The address of the fee vault
    function feeVault() external view returns (address);

    /// @notice The address of the yield vault
    function yieldVault() external view returns (address);

    /// @notice The address of the bribe vault
    function bribeVault() external view returns (address);

    /// @notice The amount of reward per second emitted by the gauge
    function rewardRate() external view returns (uint256);

    /// @notice The amount of unemitted reward left in the gauge
    function rewardLeft() external view returns (uint256);

    /// @notice The latest time getReward was called
    function lastRewardUpdateTime() external view returns (uint256);

    /// @notice The amount of reward accrued but not distributed due to zero staked liquidity
    function rollover() external view returns (uint256);

    /// @notice The start timestamp of the last epoch the gauge has flipped vaults
    function lastEpochStart() external view returns (uint256);

    /// @notice Initialize the gauge with the vault addresses
    /// Called by the Voter when creating a new gauge
    /// Only the Voter may call this function
    /// @param _feeVault The address of the fee vault
    /// @param _yieldVault The address of the yield vault
    /// @param _bribeVault The address of the bribe vault
    function initialize(address _feeVault, address _yieldVault, address _bribeVault) external;

    /// @notice Flip the vaults into a new epoch, if it has not already been flipped this epoch
    function flipEpochIfNecessary() external;

    /// @notice Set shares, which entitle a veNFT to a proportional amount of revenue the gauge earns
    /// Only the Voter may call this function
    /// @param tokenId The veNFT that own the set shares
    /// @param amount The amount of shares to set
    function setShares(uint256 tokenId, uint256 amount) external;

    /// @notice Reset shares for a given veNFT to zero
    /// Only the Voter may call this function
    /// @param tokenId The veNFT to reset shares for
    function resetShares(uint256 tokenId) external;

    /// @notice Set the tax levied on fees/yield earned by unstaked positions in the pool
    /// Only the governor may call this function
    /// @param feeTax The new unstaked fee tax, represented as a denominator (1/x)
    /// @param yieldTax The new unstaked yield tax, represented as a denominator (1/x)
    function setUnstakedTax(uint8 feeTax, uint8 yieldTax) external;

    /// @notice Notify the gauge of reward to be pulled and emitted this epoch
    /// Simultaneously claim gauge revenue accrued in the pool
    /// Only the Voter may call this function
    /// @param amount The amount of reward in TERM
    function notifyRewardAmount(uint256 amount) external;

    /// @notice Notify the gauge of additional reward to be pulled and emitted this epoch
    /// Additional rewards are supplemetary to the base rewards distributed weekly by the Voter
    /// Only the team may call this function
    /// @param amount The amount of reward in TERM
    function notifyRewardBoost(uint256 amount) external;

    /// @notice Get the increase in reward growth per staked liquidity since the last time this method was called
    /// Only the pool associated to the gauge may call this method
    /// @return rewardGrowthDeltaX128 The amount of reward accrued as a Q128.128 per staked liquidity
    /// since the last time this method was called
    function getRewardGrowth(uint256 stakedLiquidity)
        external
        returns (uint256 rewardGrowthDeltaX128);
}
