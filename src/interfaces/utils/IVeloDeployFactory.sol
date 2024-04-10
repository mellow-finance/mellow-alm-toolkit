// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../ICore.sol";
import "../modules/velo/IVeloAmmModule.sol";
import "../modules/velo/IVeloDepositWithdrawModule.sol";
import "../modules/strategies/IPulseStrategyModule.sol";

import "./IVeloDeployFactoryHelper.sol";

/**
 * @title IVeloDeployFactory Interface
 * @dev Interface for the VeloDeployFactory contract, facilitating the creation of strategies,
 * LP wrappers, and managing their configurations for Velo pools.
 */
interface IVeloDeployFactory {
    // Custom errors for operation failures
    error LpWrapperAlreadyCreated();
    error InvalidStrategyParams();
    error InvalidState();
    error PriceManipulationDetected();
    error PoolNotFound();

    /**
     * @dev Represents the immutable parameters for the VeloDeployFactory contract.
     */
    struct ImmutableParams {
        ICore core; // Core contract interface
        IPulseStrategyModule strategyModule; // Pulse strategy module contract interface
        IVeloAmmModule veloModule; // Velo AMM module contract interface
        IVeloDepositWithdrawModule depositWithdrawModule; // Velo deposit/withdraw module contract interface
        IVeloDeployFactoryHelper helper; // Helper contract interface for the VeloDeployFactory
    }

    /**
     * @dev Represents the mutable parameters for the VeloDeployFactory contract.
     */
    struct MutableParams {
        address lpWrapperAdmin; // Admin address for the LP wrapper
        address lpWrapperManager; // Manager address for the LP wrapper (strategyManager)
        address farmOwner; // Owner address for the farm
        address farmOperator; // Operator address for the farm (compounder)
        address rewardsToken; // Address of the rewards token
    }

    /**
     * @dev Holds the immutable and mutable parameters for the IVeloDeployFactory contract.
     */
    struct Storage {
        ImmutableParams immutableParams;
        MutableParams mutableParams;
    }

    /**
     * @dev Represents the parameters for configuring a strategy.
     */
    struct StrategyParams {
        int24 tickNeighborhood; // Neighborhood value for the tick
        int24 intervalWidth; // Width of the interval for strategy execution
        IPulseStrategyModule.StrategyType strategyType; // Type of strategy
        uint128 initialLiquidity; // Initial liquidity value
    }

    /**
     * @dev Stores addresses related to a specific pool.
     */
    struct PoolAddresses {
        address synthetixFarm; // Synthetix farm contract address
        address lpWrapper; // LP wrapper contract address
    }

    /**
     * @dev Maps tick spacing to strategy parameters.
     * @param tickSpacing Tick spacing value
     * @return Strategy parameters for the given tick spacing
     */
    function tickSpacingToStrategyParams(
        int24 tickSpacing
    ) external view returns (StrategyParams memory);

    /**
     * @dev Maps tick spacing to deposit parameters.
     * @param tickSpacing Tick spacing value
     * @return Deposit parameters for the given tick spacing
     */
    function tickSpacingToDepositParams(
        int24 tickSpacing
    ) external view returns (ICore.DepositParams memory);

    /**
     * @dev Updates the strategy parameters for a given tick spacing. Only users with the ADMIN_ROLE are authorized to call this function.
     * This allows for dynamic adjustment of strategy configurations based on changing market conditions or strategic insights, ensuring
     * that strategy operations can be optimized over time.
     *
     * @param tickSpacing The tick spacing value that identifies the specific context or pool for which the strategy parameters are being updated.
     * @param params The new strategy parameters to apply, including settings such as tick neighborhood, interval width, and liquidity thresholds.
     * Requirements:
     * - Caller must have the ADMIN_ROLE.
     */
    function updateStrategyParams(
        int24 tickSpacing,
        StrategyParams memory params
    ) external;

    /**
     * @dev Updates the deposit parameters for a given tick spacing. This function is restricted to users with the ADMIN role, allowing for
     * controlled modification of deposit behavior in response to protocol needs or governance decisions.
     *
     * @param tickSpacing The tick spacing value that identifies the specific context or pool for which the deposit parameters are being updated.
     * @param params The new deposit parameters to apply, aimed at managing liquidity positions effectively.
     * Requirements:
     * - Caller must have the ADMIN_ROLE.
     */
    function updateDepositParams(
        int24 tickSpacing,
        ICore.DepositParams memory params
    ) external;

    /**
     * @dev Updates the mutable parameters of the contract, accessible only to users with the ADMIN_ROLE. This function enables post-deployment
     * adjustments to key operational settings, reflecting the evolving nature of protocol management and governance.
     *
     * @param params The new mutable parameters to be applied, including administrative and operational settings crucial for protocol functionality.
     * Requirements:
     * - Caller must have the ADMIN_ROLE.
     */
    function updateMutableParams(MutableParams memory params) external;

    /**
     * @dev Creates a strategy for the given token pair and tick spacing.
     * @param token0 Address of the first token
     * @param token1 Address of the second token
     * @param tickSpacing Tick spacing value
     * @return PoolAddresses addresses related to the created pool
     */
    function createStrategy(
        address token0,
        address token1,
        int24 tickSpacing
    ) external returns (PoolAddresses memory);

    /**
     * @dev Maps a pool address to its associated addresses.
     * @param pool Pool address
     * @return PoolAddresses addresses associated with the pool
     */
    function poolToAddresses(
        address pool
    ) external view returns (PoolAddresses memory);

    /**
     * @dev Removes the addresses associated with a specific pool from the contract's records. This action is irreversible
     * and should be performed with caution. Only users with the ADMIN role are authorized to execute this function,
     * ensuring that such a critical operation is tightly controlled and aligned with the protocol's governance policies.
     *
     * Removing a pool's addresses can be necessary for protocol maintenance, updates, or in response to security concerns.
     * It effectively unlinks the pool from the factory's management and operational framework, requiring careful consideration
     * and alignment with strategic objectives.
     *
     * @param pool The address of the pool for which associated addresses are to be removed. This could include any contracts
     * or entities tied to the pool's operational lifecycle within the Velo ecosystem, such as LP wrappers or strategy modules.
     * Requirements:
     * - Caller must have the ADMIN role, ensuring that only authorized personnel can alter the protocol's configuration in this manner.
     */
    function removeAddressesForPool(address pool) external;

    /**
     * @dev Retrieves the contract's storage containing both immutable and mutable parameters.
     * @return The contract's storage
     */
    function getStorage() external view returns (Storage memory);
}
