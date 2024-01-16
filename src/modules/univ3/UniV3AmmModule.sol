// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/modules/IAmmModule.sol";

import "../../interfaces/external/univ3/IUniswapV3Pool.sol";
import "../../interfaces/external/univ3/IUniswapV3Factory.sol";
import "../../interfaces/external/univ3/INonfungiblePositionManager.sol";

import "../../libraries/external/LiquidityAmounts.sol";
import "../../libraries/external/PositionValue.sol";
import "../../libraries/external/TickMath.sol";

contract UniV3AmmModule is IAmmModule {
    using SafeERC20 for IERC20;

    INonfungiblePositionManager public immutable positionManager;
    IUniswapV3Factory public immutable factory;

    constructor(INonfungiblePositionManager positionManager_) {
        positionManager = positionManager_;
        factory = IUniswapV3Factory(positionManager.factory());
    }

    function getAmountsForLiquidity(
        uint128 liquidity,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) external pure override returns (uint256, uint256) {
        return
            LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );
    }

    function tvl(
        uint256 tokenId,
        uint160 sqrtRatioX96,
        address pool,
        address farm
    ) external view override returns (uint256, uint256) {
        require(address(farm) == address(0));
        return
            PositionValue.total(
                positionManager,
                tokenId,
                sqrtRatioX96,
                IUniswapV3Pool(pool)
            );
    }

    function getPositionInfo(
        uint256 tokenId
    ) public view override returns (Position memory position) {
        (
            ,
            ,
            position.token0,
            position.token1,
            position.property,
            position.tickLower,
            position.tickUpper,
            position.liquidity,
            ,
            ,
            ,

        ) = positionManager.positions(tokenId);
    }

    function getPool(
        address token0,
        address token1,
        uint24 fee
    ) external view override returns (address) {
        return factory.getPool(token0, token1, fee);
    }

    function getProperty(address pool) external view override returns (uint24) {
        return IUniswapV3Pool(pool).fee();
    }

    function beforeRebalance(
        address,
        address,
        uint256 tokenId
    ) external pure virtual {}

    function afterRebalance(address, address, uint256) external pure virtual {}
}
