// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IVeloFarm.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

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

    function lastRewardsUpdate(address account) external view returns (uint256);

    function claimable(address account) external view returns (uint256);

    function collectRewards() external;
}
