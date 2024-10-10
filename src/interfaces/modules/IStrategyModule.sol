// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../oracles/IOracle.sol";
import "../ICore.sol";

import "./IAmmModule.sol";

interface IStrategyModule {

    // Enum representing different types of strategies
    enum StrategyType {
        Original, // Original Pulse V1 strategy
        LazySyncing, // Lazy syncing strategy
        LazyAscending, // Lazy ascending strategy
        LazyDescending // Lazy descending strategy
    }

    /**
     * @dev Struct for strategy parameters.
     * Encapsulates the details required to execute different types of strategies.
     */
    struct StrategyParams {
        StrategyType strategyType; // Type of strategy
        int24 tickNeighborhood; // Neighborhood of ticks to consider for rebalancing
        int24 tickSpacing; // tickSpacing of the corresponding amm pool
        int24 width; // Width of the interval
        uint256 maxLiquidityRatioDeviationX96; // The maximum allowed deviation of the liquidity ratio for lower position.
    }

    /**
     * @dev Validates the strategy parameters.
     * @param params The encoded strategy parameters.
     */
    function validateStrategyParams(StrategyParams memory params) external view;

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
