// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IVeloFarm {
    struct CumulativeValue {
        uint256 timestamp;
        uint256 value;
    }

    function distribute(uint256 amount) external;

    // claimable + unclaimed rewards
    function earned(address account) external view returns (uint256);

    function getRewards(address recipient) external returns (uint256 amount);

    function rewardToken() external view returns (address);

    function initializationTimestamp() external view returns (uint256);

    function lastClaimTimestamp(address account) external view returns (uint256);

    function claimable(address account) external view returns (uint256);
}
