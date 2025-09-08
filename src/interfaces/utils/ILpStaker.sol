// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./ILpWrapper.sol";

interface ILpStaker {
    /// @dev Thrown when an address provided is zero
    error InvalidPool();

    /// @dev Thrown when an amount provided is zero
    error ZeroAmount();

    /// @dev Thrown when the provided LP wrapper is not compatible with the staker
    error InvalidLpWrapper();

    /// @dev Thrown when trying to swap rewards on a reward pool and the swap fails
    error RewardSwapFailed(address pool, bool zeroForOne, uint256 amountIn);

    /**
     * --- Emitted when rewards are updated on the staker ---
     * @param rewardAmount The amount of reward tokens that were collected and reinvested.
     * @param lpAmount The amount of LP tokens that were minted from the reinvested rewards.
     * @param lpPrice The updated price of 1 LP token in shares, multiplied by 1 ether.
     */
    event RewardsUpdated(uint256 rewardAmount, uint256 lpAmount, uint256 lpPrice);

    /**
     * --- Emitted when a user stakes their LP tokens ---
     * @param user The address of the user who performed the stake.
     * @param amount The amount of LP tokens staked by the user.
     * @param shares The amount of shares minted to the user during the stake.
     * @param lpPrice The price of 1 LP token in shares at the time of staking, multiplied by 1 ether.
     */
    event Staked(address indexed user, uint256 amount, uint256 shares, uint256 lpPrice);

    /**
     * --- Emitted when a user unstakes their shares ---
     * @param user The address of the user who performed the unstake.
     * @param amount The amount of underlying assets withdrawn from the liquidity pool.
     * @param shares The amount of shares that were burned during the unstake.
     * @param lpPrice The price of 1 LP token in shares at the time of unstaking, multiplied by 1 ether.
     */
    event Unstaked(address indexed user, uint256 amount, uint256 shares, uint256 lpPrice);

    /**
     * --- Emitted when rewards are swapped on a reward pool ---
     * @param pool The address of the reward pool where the swap occurred.
     * @param rewardsToken The address of the token that was swapped from (the rewards token).
     * @param tokenOut The address of the token that was received from the swap.
     * @param rewardsAmount The amount of the rewards token that was swapped.
     * @param amountOut The amount of the tokenOut that was received from the swap.
     */
    event RewardsSwapped(
        address indexed pool,
        address indexed rewardsToken,
        address indexed tokenOut,
        uint256 rewardsAmount,
        uint256 amountOut
    );

    /**
     * @dev Initializes the staker with the given parameters.
     * This function sets up the staker with the specified LP wrapper, reward pools,
     * admin, and manager. It can only be called once.
     * @param lpWrapper_ The LP wrapper contract to be used by the staker.
     * @param pool0_ The address of the first reward pool.
     * @param pool1_ The address of the second reward pool.
     * @param admin_ The address of the admin for access control.
     * @param manager_ The address of the manager for access control.
     */
    function initialize(
        ILpWrapper lpWrapper_,
        address pool0_,
        address pool1_,
        address admin_,
        address manager_
    ) external;

    /**
     * @dev Stakes the specified amount of LP tokens into the staker.
     * This function transfers the specified amount of LP tokens from the caller to the staker
     * and mints the corresponding amount of shares to the caller.
     * Emits a `Staked` event upon successful completion.
     * @param amount The amount of LP tokens to stake.
     * @return shares The amount of shares minted to the caller.
     */
    function stake(uint256 amount) external returns (uint256 shares);

    /**
     * @dev Unstakes the specified amount of shares from the staker.
     * This function burns the specified amount of shares and withdraws the corresponding
     * amount of underlying assets from the liquidity pool.
     * Emits an `Unstaked` event upon successful completion.
     * @param shares The amount of shares to unstake.
     * @return amount The amount of underlying assets withdrawn from the liquidity pool.
     */
    function unstake(uint256 shares) external returns (uint256 amount);

    /**
     * @dev Updates the rewards for the staker.
     * This function collects any pending rewards from the underlying liquidity pool,
     * swaps them for the appropriate tokens, and reinvests them back into the liquidity pool.
     * It ensures that the pools are not under MEV.
     * Emits a `RewardsUpdated` event upon successful completion.
     */
    function updateRewards() external;
}
