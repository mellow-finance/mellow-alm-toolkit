// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../ICore.sol";
import "../modules/velo/IVeloAmmModule.sol";
import "../modules/velo/IVeloDepositWithdrawModule.sol";
import "../modules/strategies/IPulseStrategyModule.sol";

import "./IVeloDeployFactoryHelper.sol";

interface IVeloDeployFactory {
    error LpWrapperAlreadyCreated();
    error InvalidStrategyParams();
    error InvalidState();
    error PriceManipulationDetected();
    error PoolNotFound();

    struct ImmutableParams {
        ICore core;
        IPulseStrategyModule strategyModule;
        IVeloAmmModule veloModule;
        IVeloDepositWithdrawModule depositWithdrawModule;
        IVeloDeployFactoryHelper helper;
    }

    struct MutableParams {
        address lpWrapperAdmin;
        address farmOwner;
        address farmOperator;
        address rewardsToken;
    }

    struct Storage {
        ImmutableParams immutableParams;
        MutableParams mutableParams;
    }

    struct StrategyParams {
        int24 tickNeighborhood;
        int24 intervalWidth;
        IPulseStrategyModule.StrategyType strategyType;
        uint128 initialLiquidity;
        uint128 minInitialLiquidity;
    }

    struct PoolAddresses {
        address synthetixFarm;
        address lpWrapper;
    }

    function tickSpacingToStrategyParams(
        int24
    ) external view returns (StrategyParams memory);

    function tickSpacingToDepositParams(
        int24
    ) external view returns (ICore.DepositParams memory);

    function STORAGE_SLOT() external view returns (bytes32);

    function updateStrategyParams(
        int24 tickSpacing,
        StrategyParams memory params
    ) external;

    function updateDepositParams(
        int24 tickSpacing,
        ICore.DepositParams memory params
    ) external;

    function updateMutableParams(MutableParams memory params) external;

    function createStrategy(
        address token0,
        address token1,
        int24 tickSpacing
    ) external returns (PoolAddresses memory);

    function poolToAddresses(
        address pool
    ) external view returns (PoolAddresses memory);

    function removeAddressesForPool(address pool) external;
}
