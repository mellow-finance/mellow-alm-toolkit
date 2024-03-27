// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IAmmDepositWithdrawModule Interface
 * @dev Interface for depositing into and withdrawing from Automated Market Maker (AMM) liquidity pools.
 * Provides functionality to manage liquidity by depositing and withdrawing tokens in a controlled manner.
 */
interface IAmmDepositWithdrawModule {
    /**
     * @dev Deposits specified amounts of token0 and token1 into the AMM pool for a given tokenId.
     * This operation increases the liquidity in the pool corresponding to the tokenId.
     *
     * @param tokenId The ID of the AMM position token.
     * @param amount0 The amount of token0 to deposit.
     * @param amount1 The amount of token1 to deposit.
     * @param from The address from which the tokens will be transferred.
     * @return actualAmount0 The actual amount of token0 that was deposited.
     * @return actualAmount1 The actual amount of token1 that was deposited.
     *
     * @notice The caller must have previously approved this contract to spend the specified
     * amounts of token0 and token1 on their behalf.
     */
    function deposit(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1,
        address from
    ) external returns (uint256 actualAmount0, uint256 actualAmount1);

    /**
     * @dev Withdraws a specified amount of liquidity from a position identified by tokenId and
     * transfers the corresponding amounts of token0 and token1 to a recipient address. This operation
     * reduces the liquidity in the pool and collects tokens from the position associated with the tokenId.
     *
     * @param tokenId The ID of the AMM position token from which liquidity is to be withdrawn.
     * @param liquidity The amount of liquidity to withdraw.
     * @param to The address to which the withdrawn tokens will be transferred.
     * @return actualAmount0 The actual amount of token0 that was collected and transferred.
     * @return actualAmount1 The actual amount of token1 that was collected and transferred.
     *
     * @notice This function will collect tokens from position associated with the specified tokenId.
     */
    function withdraw(
        uint256 tokenId,
        uint256 liquidity,
        address to
    ) external returns (uint256 actualAmount0, uint256 actualAmount1);
}
