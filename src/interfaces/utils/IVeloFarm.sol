// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IVeloFarm.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface IVeloFarm {
    error InvalidDistributor();
    error InvalidState();

    struct RewardRates {
        uint256 timestamp;
        uint256 rewardRateX96;
    }

    function rewardDistributor() external view returns (address);

    function rewardToken() external view returns (address);

    function initializationTimestamp() external view returns (uint256);

    function lastBalancesUpdate(address account) external view returns (uint256 timestamp);

    function claimable(address account) external view returns (uint256 claimable_);

    function rewardRates(uint256 index) external view returns (uint256 timestamp, uint256 value);

    function timestampToRewardRatesIndex(uint256 timestamp) external view returns (uint256);

    function collectRewards() external;

    function distribute(uint256 amount) external;

    function earned(address account) external view returns (uint256 earned_);

    function getRewards(address recipient) external returns (uint256 amount);
}
