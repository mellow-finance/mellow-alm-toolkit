// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./ILpWrapper.sol";
import "./IVeloDeployFactory.sol";

/**
 * @title DepositBalancer
 * @dev Handles deposits and withdrawals into Mellow ALM.
 * This contract abstracts the complexity of splitting assets, computing target amounts,
 * performing necessary swaps, and minting LP tokens with optimal capital efficiency.
 *
 * It integrates with LpWrapper contracts and pool factories to ensure consistent interaction with
 * managed liquidity positions, while enforcing safety checks and rebalancing logic.
 *
 * Key Features:
 * - Converts single-token deposits into dual-token liquidity for LP minting.
 * - Rebalances token proportions via internal swaps before minting.
 * - Supports withdrawals with optional single-token output via internal swapping.
 * - Enforces safety via non-reentrancy and authorization checks.
 *
 * Requirements:
 * - Only valid pools and wrappers should be used.
 * - Token balances and approvals must be properly handled by the caller.
 * - Tokens must conform to the ERC20 standard.
 */
interface IDepositBalancer {
    /// @dev Thrown when a zero address is provided.
    error ZeroAddress();
    /// @dev Thrown when a zero amount is provided.
    error ZeroAmount();
    /// @dev Thrown when a zero LP amount is provided.
    error ZeroLpAmount();
    /// @dev Thrown when a zero swap data is provided.
    error ZeroSwapData();
    /// @dev Thrown when an action is forbidden.
    error Forbidden();
    /// @dev Thrown when a user has insufficient LP tokens.
    error InsufficientLpAmount();
    /// @dev Thrown when a user has insufficient tokens.
    error InsufficientAmount();
    /// @dev Thrown when a swap operation fails.
    error SwapFailed(address target, bytes swapData, bytes revertData);

    /**
     * @dev Data structure for swap operations.
     * @param minReturn The minimum amount of output tokens to receive.
     * @param target The address of the target token.
     * @param data Additional data to call target.
     */
    struct SwapData {
        uint256 minReturn;
        address target;
        bytes data;
    }

    /**
     * @dev Performs a single-token deposit into a concentrated liquidity pool managed by Mellow ALM.
     * Accepts one of the pool's tokens, computes the optimal liquidity provisioning split,
     * performs any necessary internal swaps, and mints LP tokens on the @param recipient's behalf.
     *
     * The contract ensures capital-efficient liquidity provisioning by calculating the
     * required token ratios, rebalancing as needed, and returning unused tokens.
     *
     * @param lpWrapper The address of the target LpWrapper.
     * @param recipient The address receiving the resulting LP tokens.
     * @param deadline The latest timestamp by which the transaction must complete.
     * @param data Optional data with SwapData encoded structure.
     *
     * @return actualAmount0 The actual amount of token0 used in minting.
     * @return actualAmount1 The actual amount of token1 used in minting.
     * @return actualLpAmount The amount of LP tokens minted and transferred to the recipient.
     *
     * Requirements:
     * - `amountIn` must be greater than zero.
     * - The `tokenIn` must be either token0 or token1 of the pool.
     * - The LpWrapper for the pool must exist.
     * - The resulting LP amount must be greater than zero.
     */
    function deposit(
        address lpWrapper,
        address token,
        uint256 amount,
        address recipient,
        uint256 deadline,
        bytes memory data
    ) external returns (uint256 actualAmount0, uint256 actualAmount1, uint256 actualLpAmount);

    /**
     * @dev Burns LP tokens from a user and returns the underlying assets.
     * The user can optionally request a single token as output (if `token` is not zero). In that case,
     * the contract internally swaps the undesired token into the target token.
     *
     * @param lpWrapper The address of the LpWrapper.
     * @param token The address of the token to withdraw. In case of zero address, assets will be withdrawn as is.
     * @param lpAmount The amount of LP tokens to burn.
     * @param recipient The address receiving the underlying assets.
     * @param deadline The latest timestamp by which the transaction must complete.
     * @param data Optional data with SwapData encoded structure.
     *
     * @return amount0 The amount of token0 received from the withdrawal.
     * @return amount1 The amount of token1 received from the withdrawal.
     * @return actualLpAmount The actual LP amount burned (may be less than requested).
     *
     * Requirements:
     * - `lpAmount` must be positive and less than or equal to the caller’s LP balance.
     * - If `tokenTarget` is set, it must match either token0 or token1 of the pool.
     * - The LpWrapper for the pool must exist.
     */
    function withdraw(
        address lpWrapper,
        address token,
        uint256 lpAmount,
        address recipient,
        uint256 deadline,
        bytes memory data
    ) external returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount);

    /**
     * @dev Estimates the amounts of LP tokens and target tokens for a given input.
     * @param lpWrapper The address of the LpWrapper.
     * @param amount0 The amount of token0 to deposit.
     * @param amount1 The amount of token1 to deposit.
     * @return lpAmount The estimated amount of LP tokens that would be minted.
     * @return targetAmount0 The adjusted amount of token0 based on the pool's spot price.
     * @return targetAmount1 The adjusted amount of token1 based on the pool's spot price.
     */
    function previewDepositAmounts(address lpWrapper, uint256 amount0, uint256 amount1)
        external
        view
        returns (uint256 lpAmount, uint256 targetAmount0, uint256 targetAmount1);

    /**
     * @dev Estimates the amounts of underlying tokens for a given LP token amount.
     * @param lpWrapper The address of the LpWrapper.
     * @param lpAmount The amount of LP tokens to withdraw.
     * @return amount0 The estimated amount of token0 that would be received.
     * @return amount1 The estimated amount of token1 that would be received.
     */
    function previewWithdrawAmounts(address lpWrapper, uint256 lpAmount)
        external
        view
        returns (uint256 amount0, uint256 amount1);
}
