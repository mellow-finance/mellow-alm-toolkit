// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./utils/IRebalanceCallback.sol";

import "./modules/IAmmModule.sol";
import "./modules/IStrategyModule.sol";
import "./oracles/IOracle.sol";

interface ICore {
    struct NftsInfo {
        uint16 slippageD4;
        uint24 property;
        address owner;
        address pool;
        address farm;
        uint256[] tokenIds;
        bytes securityParams;
        bytes strategyParams;
    }

    struct TargetNftsInfo {
        int24[] lowerTicks;
        int24[] upperTicks;
        uint256[] liquidityRatiosX96;
        uint256[] minLiquidities;
        uint256 id;
        address farm;
        address pool;
        NftsInfo info;
    }

    struct DepositParams {
        uint256[] tokenIds;
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

    function nfts(uint256 index) external view returns (NftsInfo memory);

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

    function D4() external view returns (uint256);

    function ammModule() external view returns (IAmmModule);

    function oracle() external view returns (IOracle);

    function strategyModule() external view returns (IStrategyModule);

    function positionManager() external view returns (address);

    function operatorFlag() external view returns (bool);
}
