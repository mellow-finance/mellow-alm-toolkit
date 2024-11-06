// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./IVeloFarm.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title IVeloFarm
 * @notice Interface for a rewards distribution contract that allows eligible accounts to accumulate, claim, and manage rewards.
 * @dev This contract includes functionalities for collecting and distributing rewards, as well as for setting and viewing reward rates.
 *      It supports role-based access to reward distribution and error handling for invalid states and distributors.
 */
interface IVeloFarm {
    /**
     * @notice Thrown when an invalid distributor address is encountered.
     */
    error InvalidDistributor();

    /**
     * @notice Thrown when an operation is attempted in an invalid state.
     */
    error InvalidState();

    /**
     * @notice Struct representing reward rate information at a specific timestamp.
     * @param timestamp The timestamp at which the reward rate was set.
     * @param rewardRateX96 The reward rate, in Q96 fixed-point format.
     */
    struct RewardRates {
        uint256 timestamp;
        uint256 rewardRateX96;
    }

    /**
     * @notice Collects any accumulated rewards for the caller.
     * @dev This function gathers all rewards the caller has earned and resets the accumulated rewards.
     */
    function collectRewards() external;

    /**
     * @notice Distributes a specified amount of rewards to eligible recipients.
     * @dev This function triggers reward distribution and may only be called by an authorized distributor.
     * @param amount The amount of rewards to distribute.
     */
    function distribute(uint256 amount) external;

    /**
     * @notice Retrieves the amount of rewards available for a specific recipient.
     * @param recipient The address of the account for which rewards are being retrieved.
     * @return amount The amount of rewards available to the specified recipient.
     */
    function getRewards(address recipient) external returns (uint256 amount);

    /**
     * @notice Returns the total rewards earned by an account.
     * @param account The address of the account.
     * @return earned_ The total rewards earned by the specified account.
     */
    function earned(address account) external view returns (uint256 earned_);

    /**
     * @notice Calculates the rewards earned by a specified account based on the current state.
     * @param account The address of the account.
     * @return rewardsEarned The calculated amount of rewards the account has earned.
     */
    function calculateEarnedRewards(address account)
        external
        view
        returns (uint256 rewardsEarned);

    /**
     * @notice Returns the address of the reward distributor.
     * @return The address authorized to distribute rewards.
     */
    function rewardDistributor() external view returns (address);

    /**
     * @notice Returns the address of the reward token.
     * @return The address of the token used for rewards.
     */
    function rewardToken() external view returns (address);

    /**
     * @notice Returns the timestamp when the rewards contract was initialized.
     * @return The timestamp of the contract’s initialization.
     */
    function initializationTimestamp() external view returns (uint256);

    /**
     * @notice Returns the last timestamp when the balance of a specific account was updated.
     * @param account The address of the account.
     * @return timestamp The timestamp of the last balance update for the specified account.
     */
    function lastBalancesUpdate(address account) external view returns (uint256 timestamp);

    /**
     * @notice Returns the claimable rewards amount for a specified account.
     * @param account The address of the account.
     * @return claimable_ The amount of rewards currently claimable by the specified account.
     */
    function claimable(address account) external view returns (uint256 claimable_);

    /**
     * @notice Retrieves the reward rate at a specific index.
     * @param index The index of the reward rate to retrieve.
     * @return timestamp The timestamp associated with the reward rate.
     * @return value The reward rate at the specified index, in Q96 format.
     */
    function rewardRates(uint256 index) external view returns (uint256 timestamp, uint256 value);

    /**
     * @notice Retrieves the index of the reward rate based on a specific timestamp.
     * @param timestamp The timestamp to find the associated reward rate index.
     * @return The index corresponding to the provided timestamp.
     */
    function timestampToRewardRatesIndex(uint256 timestamp) external view returns (uint256);
}
