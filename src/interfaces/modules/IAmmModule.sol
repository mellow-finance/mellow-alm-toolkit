// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

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
     * @dev Validates protocol parameters.
     * @param params The protocol parameters to be validated.
     */
    function validateProtocolParams(bytes memory params) external view;

    /**
     * @dev Validates callback parameters.
     * @param params The callback parameters to be validated.
     */
    function validateCallbackParams(bytes memory params) external view;

    /**
     * @dev Calculates token amounts for a given liquidity amount in a position.
     * @param liquidity Liquidity amount.
     * @param sqrtPriceX96 Square root of the current price in the pool.
     * @param tickLower Lower tick of the position.
     * @param tickUpper Upper tick of the position.
     * @return amount0 Amount of token0.
     * @return amount1 Amount of token1.
     */
    function getAmountsForLiquidity(
        uint128 liquidity,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) external pure returns (uint256 amount0, uint256 amount1);

    /**
     * @dev Returns the Total Value Locked (TVL) for a token and liquidity pool state.
     * @param tokenId Token ID.
     * @param sqrtRatioX96 Square root of the current tick value in the pool.
     * @param callbackParams Callback function parameters.
     * @param protocolParams Protocol-specific parameters.
     * @return amount0 Amount of token0 locked.
     * @return amount1 Amount of token1 locked.
     */
    function tvl(
        uint256 tokenId,
        uint160 sqrtRatioX96,
        bytes memory callbackParams,
        bytes memory protocolParams
    ) external view returns (uint256 amount0, uint256 amount1);

    /**
     * @dev Retrieves the AMM position for a given token ID.
     * @param tokenId Token ID.
     * @return AmmPosition struct with position details.
     */
    function getAmmPosition(
        uint256 tokenId
    ) external view returns (AmmPosition memory);

    /**
     * @dev Returns the pool address for given tokens and property.
     * @param token0 First token address.
     * @param token1 Second token address.
     * @param property Pool property - fee or tickSpacing.
     * @return Pool address.
     */
    function getPool(
        address token0,
        address token1,
        uint24 property
    ) external view returns (address);

    /**
     * @dev Retrieves the property of a pool.
     * @param pool Pool address.
     * @return Property value of the pool.
     */
    function getProperty(address pool) external view returns (uint24);

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
     * @dev Returns the address of the position manager.
     */
    function positionManager() external view returns (address);
}
