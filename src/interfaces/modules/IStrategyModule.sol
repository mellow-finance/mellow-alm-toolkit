// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../oracles/IOracle.sol";
import "../ICore.sol";

import "./IAmmModule.sol";

interface IStrategyModule {
    function validateStrategyParams(bytes memory params) external view;

    function getTargets(
        ICore.PositionInfo memory info,
        IAmmModule ammModule,
        IOracle oracleModule
    )
        external
        view
        returns (
            bool isRebalanceRequired,
            ICore.TargetPositionInfo memory targets
        );
}
