// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/strategies/IAmmIntent.sol";
import "./IAmmModule.sol";
import "./IOracleModule.sol";

interface IStrategyModule {
    function validateStrategyParams(bytes memory params) external view;

    function getTarget(
        IAmmIntent.NftInfo memory info,
        IAmmModule module,
        IOracleModule oracleModule
    )
        external
        view
        returns (
            bool isRebalanceRequired,
            IAmmIntent.TargetNftInfo memory target
        );
}
