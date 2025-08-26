// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IDepositBalancer {
    /**
     * @dev Performs a single-token deposit into a concentrated liquidity pool managed by Mellow ALM.
     * Accepts one of the pool's tokens, computes the optimal liquidity provisioning split,
     * performs any necessary internal swaps, and mints LP tokens on the user's behalf.
     *
     * The contract ensures capital-efficient liquidity provisioning by calculating the
     * required token ratios, rebalancing as needed, and returning unused tokens.
     *
     * @param pool The address of the target ICLPool.
     * @param tokenIn The input token to deposit (must be one of the pool's tokens).
     * @param amountIn The amount of `tokenIn` to deposit.
     * @param recipient The address receiving the resulting LP tokens.
     * @param deadline The latest timestamp by which the transaction must complete.
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
        address pool,
        address tokenIn,
        uint256 amountIn,
        address recipient,
        uint256 deadline
    ) external returns (uint256 actualAmount0, uint256 actualAmount1, uint256 actualLpAmount);

    /**
     * @dev Burns LP tokens from a user and returns the underlying assets.
     * The user can optionally request a single token as output. In that case,
     * the contract internally swaps the undesired token into the target token.
     *
     * @param pool The address of the pool from which LP tokens are being burned.
     * @param lpAmount The maximum amount of LP tokens to burn.
     * @param tokenTarget The desired token to receive (token0, token1, or address(0) for both).
     * @param recipient The address receiving the underlying assets.
     * @param deadline The latest timestamp by which the transaction must complete.
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
        address pool,
        uint256 lpAmount,
        address tokenTarget,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount);
}
