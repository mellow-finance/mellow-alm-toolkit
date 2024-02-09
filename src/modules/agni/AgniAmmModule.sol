// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/modules/IAmmModule.sol";

import "../../interfaces/external/agni/IAgniPool.sol";
import "../../interfaces/external/agni/IAgniFactory.sol";
import "../../interfaces/external/agni/INonfungiblePositionManager.sol";
import "../../interfaces/external/agni/IMasterChefV3.sol";

import "../../libraries/external/LiquidityAmounts.sol";
import "../../libraries/external/agni/PositionValue.sol";

import "../../libraries/external/TickMath.sol";

contract AgniAmmModule is IAmmModule {
    using SafeERC20 for IERC20;

    INonfungiblePositionManager public immutable positionManager;
    IAgniFactory public immutable factory;

    constructor(INonfungiblePositionManager positionManager_) {
        positionManager = positionManager_;
        factory = IAgniFactory(positionManager.factory());
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
        address
    ) external view override returns (uint256, uint256) {
        return
            PositionValue.total(
                positionManager,
                tokenId,
                sqrtRatioX96,
                IAgniPool(pool)
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
        return IAgniPool(pool).fee();
    }

    function beforeRebalance(
        address farm,
        address synthetixFarm,
        uint256 tokenId
    ) external virtual {
        if (farm == address(0)) return;
        require(
            synthetixFarm != address(0),
            "AgniAmmModule: synthetixFarm is zero"
        );
        IMasterChefV3(farm).harvest(tokenId, synthetixFarm);
        IMasterChefV3(farm).withdraw(tokenId, address(this));
    }

    function afterRebalance(
        address farm,
        address,
        uint256 tokenId
    ) external virtual {
        if (farm == address(0)) return;
        positionManager.safeTransferFrom(address(this), address(farm), tokenId);
    }
}
