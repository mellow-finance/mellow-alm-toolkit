// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.25;

interface ICLGaugeFactory {
    event SetNotifyAdmin(address indexed notifyAdmin);

    /// @notice Address of the voter contract
    function voter() external view returns (address);

    /// @notice Address of the gauge implementation contract
    function implementation() external view returns (address);

    /// @notice Address of the NonfungiblePositionManager used to create nfts that gauges will accept
    function nft() external view returns (address);

    /// @notice Administrator that can call `notifyRewardWithoutClaim` on gauges
    function notifyAdmin() external view returns (address);

    /// @notice Set Nonfungible Position Manager
    /// @dev Callable once only on initialize
    /// @param _nft The nonfungible position manager that will manage positions for this Factory
    function setNonfungiblePositionManager(address _nft) external;

    /// @notice Set notifyAdmin value on gauge factory
    /// @param _admin New administrator that will be able to call `notifyRewardWithoutClaim` on gauges.
    function setNotifyAdmin(address _admin) external;

    /// @notice Called by the voter contract via factory.createPool
    /// @param _forwarder The address of the forwarder contract
    /// @param _pool The address of the pool
    /// @param _feesVotingReward The address of the feesVotingReward contract
    /// @param _rewardToken The address of the reward token
    /// @param _isPool Whether the attached pool is a real pool or not
    /// @return The address of the created gauge
    function createGauge(
        address _forwarder,
        address _pool,
        address _feesVotingReward,
        address _rewardToken,
        bool _isPool
    ) external returns (address);
}
