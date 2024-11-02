// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../ICore.sol";
import "../modules/strategies/IPulseStrategyModule.sol";
import "../modules/velo/IVeloAmmModule.sol";
import "../modules/velo/IVeloDepositWithdrawModule.sol";
import "./ILpWrapper.sol";
import "./IVeloFactoryDeposit.sol";

/**
 * @title IVeloDeployFactory Interface
 * @dev Interface for the VeloDeployFactory contract, facilitating the creation of strategies,
 * LP wrappers, and managing their configurations for Velo pools.
 */
interface IVeloDeployFactory {
    // Custom errors for operation failures
    error InvalidParams();
    error LpWrapperAlreadyCreated();

    struct StrategyCreatedParams {
        address pool;
        IVeloAmmModule.AmmPosition[] ammPosition;
        IPulseStrategyModule.StrategyParams strategyParams;
        address lpWrapper;
        address caller;
    }

    event StrategyCreated(StrategyCreatedParams params);

    /**
     * @dev Represents the mutable parameters for the VeloDeployFactory contract.
     */
    struct MutableParams {
        address lpWrapperAdmin; // Admin address for the LP wrapper
        address lpWrapperManager; // Manager address for the LP wrapper
        uint256 minInitialTotalSupply; // Minimum initial liquidity for the LP wrapper
    }

    /**
     * @dev Represents the parameters for configuring a strategy.
     */
    struct DeployParams {
        IPulseStrategyModule.StrategyParams strategyParams;
        ICLPool pool;
        uint32 slippageD9;
        uint256 maxAmount0;
        uint256 maxAmount1;
        uint256 initialTotalSupply;
        uint256 totalSupplyLimit;
        bytes securityParams;
        uint256[] tokenId;
    }

    /**
     * @dev Updates the mutable parameters of the contract, accessible only to users with the ADMIN_ROLE. This function enables post-deployment
     * adjustments to key operational settings, reflecting the evolving nature of protocol management and governance.
     *
     * @param newMutableParams The new mutable parameters to be applied, including administrative and operational settings crucial for protocol functionality.
     * Requirements:
     * - Caller must have the ADMIN_ROLE.
     */
    function updateMutableParams(MutableParams memory newMutableParams) external;

    /**
     * @dev Creates a strategy for the given deployParams
     * @param params DeployParams for the strategy
     * @return lpWrapper lp wrapper address - ERC20 representation of the LP token
     */
    function createStrategy(DeployParams calldata params) external returns (ILpWrapper lpWrapper);

    /**
     * @dev Maps a pool address to its associated addresses.
     * @param pool Pool address
     */
    function poolToWrapper(address pool) external view returns (address lpWrapper);

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
    function removeWrapperForPool(address pool) external;

    /**
     * @dev Retrieves the mutable parameters for the VeloDeployFactory contract.
     * @return MutableParams Mutable parameters for the VeloDeployFactory
     */
    function getMutableParams() external view returns (MutableParams memory);
}
