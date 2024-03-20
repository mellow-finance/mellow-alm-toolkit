// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../IStrategyModule.sol";

/**
 * @title PulseStrategyModule
 * @dev A strategy module that implements the Pulse V1 strategy and Lazy Pulse strategy.
 */
interface IPulseStrategyModule is IStrategyModule {
    error InvalidParams();
    error InvalidLength();

    enum StrategyType {
        Original,
        LazySyncing,
        LazyAscending,
        LazyDescending
    }

    struct StrategyParams {
        StrategyType strategyType;
        int24 tickNeighborhood;
        int24 tickSpacing;
        int24 width;
    }

    function Q96() external view returns (uint256);

    /**
     * @dev Validates the strategy parameters.
     * @param params The encoded strategy parameters.
     * @notice throws InvalidParams if the tick neighborhood or tick spacing is zero.
     */
    function validateStrategyParams(bytes memory params) external pure;

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
        override
        returns (
            bool isRebalanceRequired,
            ICore.TargetPositionInfo memory target
        );

    function calculateTarget(
        int24 tick,
        int24 tickLower,
        int24 tickUpper,
        StrategyParams memory params
    )
        external
        pure
        returns (
            bool isRebalanceRequired,
            ICore.TargetPositionInfo memory target
        );
}
