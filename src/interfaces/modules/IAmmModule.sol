// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

interface IAmmModule {
    struct AmmPosition {
        address token0;
        address token1;
        uint24 property; // fee or tickSpacing
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    function validateProtocolParams(bytes memory) external view;

    function validateCallbackParams(bytes memory) external view;

    function getAmountsForLiquidity(
        uint128 liquidity,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) external pure returns (uint256 amount0, uint256 amount1);

    function tvl(
        uint256 tokenId,
        uint160 sqrtRatioX96,
        bytes memory,
        bytes memory
    ) external view returns (uint256 amount0, uint256 amount1);

    function getAmmPosition(
        uint256 tokenId
    ) external view returns (AmmPosition memory);

    function getPool(
        address token0,
        address token1,
        uint24 fee
    ) external view returns (address);

    function getProperty(address pool) external view returns (uint24);

    function beforeRebalance(uint256, bytes memory, bytes memory) external;

    function afterRebalance(uint256, bytes memory, bytes memory) external;

    function transferFrom(address, address, uint256) external;

    function positionManager() external view returns (address);
}
