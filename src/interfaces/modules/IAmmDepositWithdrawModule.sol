// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

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
     * @param token0 The address of the token0 to deposit.
     * @param token1 The address of the token1 to deposit.
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
        address from,
        address token0,
        address token1
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
    function withdraw(uint256 tokenId, uint256 liquidity, address to)
        external
        returns (uint256 actualAmount0, uint256 actualAmount1);

    /**
     * @dev Mints a new AMM position token for a specified pool by depositing desired amounts of token0 and token1.
     * This operation creates a new liquidity position in the pool and returns the details of the minted token.
     * @param pool The address of the AMM pool where the position will be created.
     * @param tickLower The lower tick boundary for the liquidity position.
     * @param tickUpper The upper tick boundary for the liquidity position.
     * @param amount0Desired The desired amount of token0 to deposit for the new position.
     * @param amount1Desired The desired amount of token1 to deposit for the new position.
     * @param to The address that will receive the newly minted AMM position token.
     * @return tokenId The ID of the newly minted AMM position token.
     * @return liquidity The amount of liquidity that was created in the pool.
     * @return amount0Actual The actual amount of token0 that was deposited.
     * @return amount1Actual The actual amount of token1 that was deposited.
     * amounts of token0 and token1 on their behalf.
     */
    function mint(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired,
        address to
    )
        external
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0Actual, uint256 amount1Actual);

    /**
     * @dev Burns (deletes) an AMM position token identified by tokenId.
     * This operation removes the liquidity position from the AMM pool and deletes the token.
     * @param tokenId The ID of the AMM position token to be burned.
     * @notice The caller must be the owner of the tokenId or have been approved to manage it.
     * @notice The position associated with the tokenId must have zero liquidity before it can be burned.
     * @notice Any remaining tokens owed to the position must be collected before burning
     */
    function burn(uint256 tokenId) external;
}
