// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../ICore.sol";
import "../modules/strategies/IPulseStrategyModule.sol";
import "../modules/velo/IVeloAmmModule.sol";
import "../modules/velo/IVeloDepositWithdrawModule.sol";
import "./ILpWrapper.sol";
import "./IVeloFactoryHelper.sol";

/**
 * @title IVeloDeployFactory Interface
 * @dev Interface for the VeloDeployFactory contract, facilitating the creation of strategies,
 * LP wrappers, and managing their configurations for Velo pools.
 */
interface IVeloDeployFactory is IAccessControlEnumerable {
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
     * @dev Represents the parameters for configuring a strategy.
     */
    struct DeployParams {
        uint32 slippageD9;
        IPulseStrategyModule.StrategyParams strategyParams;
        IVeloOracle.SecurityParams securityParams;
        ICLPool pool;
        uint256 maxAmount0;
        uint256 maxAmount1;
        uint256 initialTotalSupply;
        uint256 totalSupplyLimit;
    }

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

    function setLpWrapperAdmin(address lpWrapperAdmin_) external;

    function setLpWrapperManager(address lpWrapperManager_) external;

    function setMinInitialTotalSupply(uint256 minInitialTotalSupply_) external;

    function configureNameAndSymbol(ICLPool pool)
        external
        view
        returns (string memory name, string memory symbol);
}
