// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../oracles/IOracle.sol";
import "../ICore.sol";

import "./IAmmModule.sol";

interface IStrategyModule {
    function validateStrategyParams(bytes memory params) external view;

    function getTarget(
        ICore.NftInfo memory info,
        IAmmModule module,
        IOracle oracleModule
    )
        external
        view
        returns (bool isRebalanceRequired, ICore.TargetNftInfo memory target);
}
