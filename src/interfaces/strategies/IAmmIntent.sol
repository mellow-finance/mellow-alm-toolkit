// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../utils/IAmmIntentCallback.sol";

interface IAmmIntent {
    struct NftInfo {
        int24 tickLower;
        int24 tickUpper;
        uint24 property;
        address owner;
        uint16 slippageD4;
        uint80 tokenId;
        address pool;
        address farm;
        bytes securityParams;
        bytes strategyParams;
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
        address farm;
        uint16 slippageD4;
        bytes strategyParams;
        bytes securityParams;
    }

    struct RebalanceParams {
        uint256[] ids;
        address callback;
        bytes data;
    }

    function nfts(uint256 index) external view returns (NftInfo memory);

    function getUserIds(
        address user
    ) external view returns (uint256[] memory ids);

    function setOperatorFlag(bool operatorFlag_) external;

    function setPositionParams(
        uint256 id,
        uint16 slippageD4,
        bytes memory strategyParams,
        bytes memory securityParams
    ) external;

    function deposit(DepositParams memory params) external returns (uint256 id);

    function withdraw(uint256 id, address to) external;

    function rebalance(RebalanceParams memory params) external;
}
