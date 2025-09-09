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

    /**
     * --- Emitted when rewards are compounded on the staker ---
     * @param rewardAmount The amount of reward tokens that were collected and reinvested.
     * @param lpAmount The amount of LP tokens that were minted from the reinvested rewards.
     * @param lpPrice The updated price of 1 LP token in shares, multiplied by 1 ether.
     */
    event RewardsCompounded(uint256 rewardAmount, uint256 lpAmount, uint256 lpPrice);

    /**
     * --- Emitted when a account stakes their LP tokens ---
     * @param account The address of the account who performed the stake.
     * @param amount The amount of LP tokens staked by the account.
     * @param shares The amount of shares minted to the account during the stake.
     * @param lpPrice The price of 1 LP token in shares at the time of staking, multiplied by 1 ether.
     */
    event Staked(address indexed account, uint256 amount, uint256 shares, uint256 lpPrice);

    /**
     * --- Emitted when a account unstakes their shares ---
     * @param account The address of the account who performed the unstake.
     * @param amount The amount of underlying assets withdrawn from the liquidity pool.
     * @param shares The amount of shares that were burned during the unstake.
     * @param lpPrice The price of 1 LP token in shares at the time of unstaking, multiplied by 1 ether.
     */
    event Unstaked(address indexed account, uint256 amount, uint256 shares, uint256 lpPrice);

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
     * --- Struct for parameters required to quote swap amounts ---
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
     * --- Struct for parameters required to perform a swap on a reward pool ---
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
     */
    function initialize(ILpWrapper lpWrapper_, address admin_, address manager_, address operator_)
        external;

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
     * @dev Compounds the rewards for the staker.
     * This function collects any pending rewards from the underlying liquidity pool,
     * swaps them for the appropriate tokens, and reinvests them back into the liquidity pool.
     * It ensures that the pools are not under MEV.
     * Emits a `RewardsUpdated` event upon successful completion.
     * @param swapParams An array of SwapParams structs containing the parameters for swapping rewards.
     */
    function compoundRewards(SwapParams[2] memory swapParams) external;

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
     * @dev Returns the current assets of the specified account.
     */
    function assetsOf(address account) external view returns (uint256);
}
