// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

/**
 * @title IAmmModule Interface
 * @dev Interface for interacting with a specific Automated Market Maker (AMM) protocol,
 * including functionalities for staking and collecting rewards through pre and post rebalance hooks.
 */
interface IAmmModule {
    /**
     * @dev Struct representing an AMM position.
     * Contains details about the liquidity position in an AMM pool.
     */
    struct AmmPosition {
        address token0; // Address of the first token in the AMM pair
        address token1; // Address of the second token in the AMM pair
        uint24 property; // Represents a fee or tickSpacing property
        int24 tickLower; // Lower tick of the position
        int24 tickUpper; // Upper tick of the position
        uint128 liquidity; // Liquidity of the position
    }

    /**
     * @notice Information about minting in a specified tick range.
     * @param amount0 Amount of token0 for the mint operation.
     * @param amount1 Amount of token1 for the mint operation.
     * @param tickLower Lower bound of the tick range for minting.
     * @param tickUpper Upper bound of the tick range for minting.
     */
    struct MintInfo {
        address pool;
        uint256 amount0;
        uint256 amount1;
        int24 tickLower;
        int24 tickUpper;
    }

    /**
     * @dev Returns the name of the AMM protocol.
     */
    function protocolName() external view returns (string memory);

    /**
     * @dev Returns the symbol of the AMM protocol.
     */
    function protocolSymbol() external view returns (string memory);

    /**
     * @dev Returns the letter of the AMM protocol.
     */
    function protocolLetter() external view returns (string memory);

    /**
     * @dev Validates protocol parameters.
     * @param params The protocol parameters to be validated.
     */
    function validateProtocolParams(bytes memory params) external view;

    /**
     * @dev Validates callback parameters.
     * @param pool The address of the pool for which the callback is being validated.
     * @param params The callback parameters to be validated.
     */
    function validateCallbackParams(address pool, bytes memory params) external view;

    /**
     * @dev Returns the Total Value Locked (TVL) for a token and liquidity pool state.
     * @param tokenId Token ID.
     * @return amount0 Amount of token0 locked.
     * @return amount1 Amount of token1 locked.
     */
    function tvl(uint256 tokenId) external view returns (uint256 amount0, uint256 amount1);

    /**
     * @dev Returns the Total Value Locked (TVL) for a token and liquidity pool state.
     * @param tokenId Token ID.
     * @param sqrtPriceX96 Square root of the price for calculation.
     * @return amount0 Amount of token0 locked.
     * @return amount1 Amount of token1 locked.
     */
    function tvl(uint256 tokenId, uint160 sqrtPriceX96)
        external
        view
        returns (uint256 amount0, uint256 amount1);

    /**
     * @dev Retrieves the AMM position for a given token ID.
     * @param tokenId Token ID.
     * @return AmmPosition struct with position details.
     */
    function getAmmPosition(uint256 tokenId) external view returns (AmmPosition memory);

    /**
     * @dev Returns the pool address for given tokens and property.
     * @param token0 First token address.
     * @param token1 Second token address.
     * @param property Pool property - fee or tickSpacing.
     * @return Pool address.
     */
    function getPool(address token0, address token1, uint24 property)
        external
        view
        returns (address);

    /**
     * @dev Returns whether the given pool address belongs to the factory.
     * @param pool Address of pool
     */
    function isPool(address pool) external view returns (bool);

    /**
     * @dev Retrieves the property of a pool.
     * @param pool Pool address.
     * @return Property value of the pool.
     */
    function getProperty(address pool) external view returns (uint24);

    /**
     * @dev Returns the square root price for a given pool.
     * @param pool Address of the pool.
     */
    function getSqrtPriceX96(address pool) external view returns (uint160);

    /**
     * @dev Returns the square root price and tick for a given pool.
     * @param pool Address of the pool.
     */
    function getSqrtPriceX96AndTick(address pool) external view returns (uint160, int24);

    /**
     * @dev Returns the token addresses for a given pool.
     * @param pool Address of the pool.
     * @return token0 Address of the first token.
     * @return token1 Address of the second token.
     */
    function getPoolTokens(address pool) external view returns (address, address);

    /**
     * @dev Returns the reward token address for the AMM.
     * @param pool Address of the pool.
     */
    function getRewardToken(address pool) external view returns (address);

    /**
     * @dev Returns the gauge address for a given pool.
     * @param pool Address of the pool.
     */
    function getGauge(address pool) external view returns (address);

    /**
     * @notice Collects accumulated rewards for a specific token ID.
     * @dev This function allows the caller to collect rewards associated with a specified token,
     *      using additional parameters for customization of the collection process.
     * @param tokenId The unique identifier of the token for which rewards are to be collected.
     * @param callbackParams Additional parameters for callback configuration during reward collection.
     * @param protocolParams Protocol-specific parameters that influence the reward collection process.
     */
    function collectRewards(
        uint256 tokenId,
        bytes memory callbackParams,
        bytes memory protocolParams
    ) external;

    /**
     * @dev Hook called before rebalancing a token or before any deposit/withdraw actions.
     * @param tokenId Token ID being rebalanced.
     * @param callbackParams Callback parameters.
     * @param protocolParams Protocol-specific parameters.
     */
    function beforeRebalance(
        uint256 tokenId,
        bytes memory callbackParams,
        bytes memory protocolParams
    ) external;

    /**
     * @dev Hook called after rebalancing a token or before any deposit/withdraw actions.
     * @param tokenId Token ID rebalanced.
     * @param callbackParams Callback parameters.
     * @param protocolParams Protocol-specific parameters.
     */
    function afterRebalance(
        uint256 tokenId,
        bytes memory callbackParams,
        bytes memory protocolParams
    ) external;

    /**
     * @dev Transfers a token ERC721 from one address to another.
     * @param from Address to transfer from.
     * @param to Address to transfer to.
     * @param tokenId Token ID to be transferred.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Mints new tokens.
     * @param depositor Address of the depositor.
     * @param mintInfo Array of minting information.
     * @return tokenIds Array of minted token IDs.
     */
    function mint(address depositor, MintInfo[] memory mintInfo)
        external
        returns (uint256[] memory tokenIds);

    /**
     * @dev Approves a token ID for a specific address.
     * @param to Address to approve.
     * @param tokenId Token ID to be approved.
     */
    function approveTokenId(address to, uint256 tokenId) external;

    /**
     * @dev Returns the address of the position manager.
     */
    function positionManager() external view returns (address);

    /**
     * @dev Swaps tokens on a specified pool.
     * @param pool Address of the pool to swap on.
     * @param zeroForOne Boolean indicating the swap direction.
     * @param amountIn Amount of tokens to swap.
     * @return amount0 Amount of token0 received.
     * @return amount1 Amount of token1 received.
     */
    function swapOnPool(address pool, bool zeroForOne, uint256 amountIn)
        external
        returns (int256 amount0, int256 amount1);

    /**
     * @dev Callback function for the pool.
     * @param pool Address of the pool.
     * @param selector Selector of the callback function.
     * @param data Additional data for the callback.
     */
    function poolCallback(address pool, bytes4 selector, bytes memory data) external;
}
