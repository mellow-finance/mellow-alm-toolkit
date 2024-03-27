// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../oracles/IOracle.sol";
import "../ICore.sol";

import "./IAmmModule.sol";

interface IStrategyModule {
    /**
     * @dev Validates the strategy parameters.
     * @param params The encoded strategy parameters.
     */
    function validateStrategyParams(bytes memory params) external view;

    /**
     * @dev Retrieves the target information for rebalancing based on the given parameters.
     * @param info position information.
     * @param ammModule The AMM module.
     * @param oracle The oracle.
     * @return isRebalanceRequired A boolean indicating whether rebalancing is required.
     * @return target The target position information for rebalancing.
     */
    function getTargets(
        ICore.ManagedPositionInfo memory info,
        IAmmModule ammModule,
        IOracle oracle
    )
        external
        view
        returns (
            bool isRebalanceRequired,
            ICore.TargetPositionInfo memory target
        );
}
