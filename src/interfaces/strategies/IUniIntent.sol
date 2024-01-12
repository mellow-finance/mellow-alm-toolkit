// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../external/univ3/IUniswapV3Pool.sol";
import "../external/univ3/IUniswapV3Factory.sol";
import "../external/univ3/INonfungiblePositionManager.sol";

import "../utils/IUniIntentCallback.sol";

interface IUniIntent {
    struct NftInfo {
        int24 tickNeighborhood;
        int24 tickSpacing;
        int24 tickLower;
        int24 tickUpper;
        address owner;
        uint16 slippageD4;
        uint80 tokenId;
        address pool;
        uint128 minLiquidityGross;
        int24 maxDeviation;
        uint32[] timespans;
    }

    struct TargetNftInfo {
        int24 tickLower;
        int24 tickUpper;
        uint128 minLiquidity;
        uint256 id;
        NftInfo nftInfo;
    }

    struct DepositParams {
        uint256 tokenId;
        address owner;
        int24 tickNeighborhood;
        uint16 slippageD4;
        int24 maxDeviation;
        uint128 minLiquidityGross;
        uint32[] timespans;
    }

    struct RebalanceParams {
        uint256[] ids;
        int24[] offchainTicks;
        address callback;
        bytes data;
    }
}
