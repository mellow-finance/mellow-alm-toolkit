// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "src/interfaces/ICore.sol";

import "src/interfaces/modules/strategies/IPulseStrategyModule.sol";
import "src/interfaces/oracles/IVeloOracle.sol";

/**
 * @title ISugarHelper
 * @notice Interface for the SugarHelper contract, which provides utility functions to interact with
 *         and retrieve data from the core contracts, especially focusing on managed liquidity pool positions.
 */
interface ISugarHelper {
    /**
     * @dev Data about the core contracts.
     */
    struct CoreDeployment {
        address core;
        address ammModule;
        address depositWithdrawModule;
        address oracle;
        address strategyModule;
        address deployFactory;
        address lpWrapperImplementation;
        address lpStakerImplementation;
    }

    /**
     * @dev Data about a managed strategy position.
     */
    struct StrategyData {
        address pool; // pool address of managed position
        address lpStaker; // lpStaker address, can be zero
        address lpWrapper; // lpWrapper address
        uint256 supply; // total supply of lpWrapper
        uint256 supplyLimit; // supply limit of lpWrapper
        string name; // ERC20 name of lpWrapper
        string symbol; //  ERC20 symbol of lpWrapper
        int24 tickSpot; // current tick of the pool
        AmmPosition[] ammPositions; // all AMM positions of the managed position
        TokenData tokenData0; // pool token0 data
        TokenData tokenData1; // pool token1 data
    }

    /**
     * @dev Data about a single AMM position.
     */
    struct AmmPosition {
        int24 tickLower; // lower tick of the position
        int24 tickUpper; // upper tick of the position
        uint128 liquidity; // liquidity of the position
    }

    /**
     * @dev Data about a single token.
     */
    struct TokenData {
        address addr; // token address
        uint256 amountALM; // amount token in ALM positions
        uint256 amountPool; // amount token in the pool
        uint256 amountStaker; // amount of staker tokens
        uint8 decimals; // token decimals
        string symbol; // token symbol
    }

    /**
     * @dev Returns the addresses of all core contracts.
     */
    function getCoreDeployment() external view returns (CoreDeployment memory contracts);

    /**
     * @dev Returns the managed pool positions.
     */
    function getManagedPoolPositions() external view returns (StrategyData[] memory data);

    /**
     * @dev Returns the LP wrappers that need rebalancing.
     */
    function needRebalancePositions() external view returns (address[] memory lpWrappers);

    /**
     * @dev Returns whether the given LP wrapper needs rebalancing.
     */
    function needRebalancePosition(address lpWrapper)
        external
        view
        returns (bool isRebalanceRequired);

    /**
     * @dev Returns detailed data about the given LP wrapper position.
     */
    function positionData(address lpWrapper)
        external
        view
        returns (StrategyData memory data, bool belongFactory);

    /**
     * @dev Returns the managed position info for the given LP wrapper.
     */
    function managedPositionInfo(address lpWrapper)
        external
        view
        returns (uint256 positionId, ICore.ManagedPositionInfo memory managedPositionInfo);

    /**
     * @dev Returns the strategy params for the given LP wrapper.
     */
    function getStrategyParams(address lpWrapper)
        external
        view
        returns (IPulseStrategyModule.StrategyParams memory strategyParams);

    /**
     * @dev Returns the security params for the given LP wrapper.
     */
    function getSecurityParams(address lpWrapper)
        external
        view
        returns (IVeloOracle.SecurityParams memory securityParams);

    /**
     * @dev Returns the token data for the given address.
     */
    function getTokenData(address addr) external view returns (TokenData memory token);
}
