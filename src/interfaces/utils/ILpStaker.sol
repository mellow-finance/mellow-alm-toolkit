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
    error RewardSwapFailed(address target, uint256 amountIn, address tokenOut);

    /// @dev Thrown when the slippage is exceeded during swap amounts
    error SlippageExceeded();

    /// @dev Thrown when trying to unstake more shares than the account has unlocked
    error InsufficientUnlockedShares(address account, uint256 lockedShares, uint256 shares);

    /// @dev Thrown when trying to create too many active locks for an account
    error TooManyActiveLocks(address account, uint32 activeLocks);

    /// @dev Thrown when trying to set a timelock duration that out of allowed range
    error InvalidTimeLock(uint32 newDuration);

    /**
     * @notice Emitted when rewards are compounded on the staker
     * @param rewardAmount The amount of reward tokens that were collected and reinvested.
     * @param lpAmount The amount of LP tokens that were minted from the reinvested rewards.
     * @param lpPrice The updated price of 1 LP token in shares, multiplied by 1 ether.
     */
    event RewardsCompounded(uint256 rewardAmount, uint256 lpAmount, uint256 lpPrice);

    /**
     * @notice Emitted when a account stakes their LP tokens
     * @param account The address of the account who performed the stake.
     * @param lpAmount The amount of LP tokens staked by the account.
     * @param shares The amount of shares minted to the account during the stake.
     * @param lpPrice The price of 1 LP token in shares at the time of staking, multiplied by 1 ether.
     */
    event Staked(address indexed account, uint256 lpAmount, uint256 shares, uint256 lpPrice);

    /**
     * @notice Emitted when a account unstakes their shares
     * @param account The address of the account who performed the unstake.
     * @param lpAmount The amount of underlying assets withdrawn from the liquidity pool.
     * @param shares The amount of shares that were burned during the unstake.
     * @param lpPrice The price of 1 LP token in shares at the time of unstaking, multiplied by 1 ether.
     */
    event Unstaked(address indexed account, uint256 lpAmount, uint256 shares, uint256 lpPrice);

    /**
     * @notice Emitted when rewards are swapped on a reward pool
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
     * @notice Emitted when the timelock duration is updated
     * @param oldDuration The previous duration of the timelock.
     * @param newDuration The new duration of the timelock.
     */
    event TimeLockUpdated(uint32 oldDuration, uint32 newDuration);

    /**
     * @notice Struct for parameters required to quote swap amounts
     * @param tokenIn The address of the token to be swapped.
     * @param tokenOut The address of the token to be received from the swap.
     * @param amountIn The amount of the token to be swapped.
     */
    struct QuoteParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
    }

    /**
     * @notice Struct for parameters required to perform a swap on a reward pool
     * @param target The address of the target contract where the call will be made.
     * @param amountIn The amount of the rewards token to be swapped.
     * @param tokenOut The address of the token to be received from the swap.
     * @param minAmountOut The minimum acceptable amount of tokenOut to be received from the swap.
     * @param data The calldata to be sent to the target contract to perform the swap
     */
    struct SwapParams {
        address target;
        uint256 amountIn;
        address tokenOut;
        uint256 minAmountOut;
        bytes data;
    }

    /**
     * @dev Initializes the staker with the given parameters.
     * This function sets up the staker with the specified LP wrapper, admin, and manager. It can only be called once.
     * @param lpWrapper_ The LP wrapper contract to be used by the staker.
     * @param admin_ The address of the admin for access control.
     * @param manager_ The address of the manager for access control.
     * @param operator_ The address of the operator for access control.
     * @param timelockDuration_ The initial duration for the timelock on unstaking.
     */
    function initialize(
        ILpWrapper lpWrapper_,
        address admin_,
        address manager_,
        address operator_,
        uint32 timelockDuration_
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
     * @dev Mints LP tokens using the provided mint parameters and stakes them into the staker.
     * This function calls the `mint` function of the LP wrapper with the provided parameters,
     * stakes the minted LP tokens, and mints the corresponding amount of shares to the caller
     * Emits a `Staked` event upon successful completion.
     * @param amount0 The amount of token0 to be used for minting.
     * @param amount1 The amount of token1 to be used for minting.
     * @return actualAmount0 The actual amount of token0 used for minting.
     * @return actualAmount1 The actual amount of token1 used for minting.
     * @return actualLpAmount The actual amount of LP tokens minted.
     * @return shares The amount of shares minted to the caller.
     */
    function mintAndStake(uint256 amount0, uint256 amount1)
        external
        returns (
            uint256 actualAmount0,
            uint256 actualAmount1,
            uint256 actualLpAmount,
            uint256 shares
        );

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
     * @dev Burns the specified amount of shares and withdraws the corresponding
     * amount of underlying assets from the liquidity pool, sending them to the specified recipient.
     * Emits an `Unstaked` event upon successful completion.
     * @param shares The amount of shares to burn.
     * @param amount0Min The minimum acceptable amount of token0 to be withdrawn.
     * @param amount1Min The minimum acceptable amount of token1 to be withdrawn.
     * @param recipient The address to receive the withdrawn underlying assets.
     * @return actualAmount0 The actual amount of token0 withdrawn.
     * @return actualAmount1 The actual amount of token1 withdrawn.
     * @return actualLpAmount The actual amount of LP tokens that were burned.
     */
    function unstakeAndWithdraw(
        uint256 shares,
        uint256 amount0Min,
        uint256 amount1Min,
        address recipient
    ) external returns (uint256 actualAmount0, uint256 actualAmount1, uint256 actualLpAmount);

    /**
     * @dev Compounds the rewards for the staker.
     * This function collects any pending rewards from the underlying liquidity pool,
     * swaps them for the appropriate tokens, and reinvests them back into the liquidity pool.
     * It ensures that the pools are not under MEV.
     * Emits a `RewardsUpdated` event upon successful completion.
     * @param swapParams An array of SwapParams structs containing the parameters for swapping rewards.
     */
    function compoundRewards(SwapParams[2] memory swapParams) external;

    /**
     * @dev Updates the duration of the timeLock for unstaking.
     * This function allows the admin to change the duration of the timeLock within the allowed range.
     * Emits a `TimeLockUpdated` event upon successful completion.
     * @param newTimeLock The new duration for the timeLock, in seconds.
     */
    function updateTimeLock(uint32 newTimeLock) external;

    /**
     * @dev Quotes the amounts to swap for the specified reward tokens.
     * It returns precise amounts to swap without slippage at the call moment.
     * In this case real amounts to swap should be decreased by some slippage tolerance.
     * @return quoteParams An array of QuoteParams structs containing the parameters for each swap.
     */
    function quoteSwapAmounts() external view returns (QuoteParams[2] memory quoteParams);

    /**
     * @dev Returns the current price of 1 LP token in shares, multiplied by 1e18.
     */
    function lpPrice() external view returns (uint256);

    /**
     * @dev Returns the current shares of the specified account.
     */
    function sharesOf(address account) external view returns (uint256);

    /**
     * @dev Returns the current amount of LP tokens staked by the specified account.
     */
    function lpAmountOf(address account) external view returns (uint256);

    /**
     * @dev Returns the current underlying assets of the specified account.
     */
    function assetsOf(address account) external view returns (uint256, uint256);

    /**
     * @dev Returns the current locked shares and active checkpoints for the specified account.
     * @param account The address of the account to query.
     * @param timestamp The timestamp to check the locked shares against.
     * @return lockedShares The amount of shares that are currently locked for the account.
     * @return activeCheckpoints The number of active lock checkpoints for the account.
     */
    function getLockedShares(address account, uint32 timestamp)
        external
        view
        returns (uint256 lockedShares, uint32 activeCheckpoints);

    /// @dev Duration of the timeLock for locked amounts
    function timeLock() external view returns (uint32);

    /// @dev Minimum duration of the timeLock for locked amounts
    function MIN_TIMELOCK_DURATION() external view returns (uint32);

    /// @dev Maximum duration of the timeLock for locked amounts
    function MAX_TIMELOCK_DURATION() external view returns (uint32);
}
