// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./ILpWrapper.sol";

import "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

/**
 * @title IVeloDeployFactory Interface
 * @notice Interface for the VeloDeployFactory contract, facilitating the creation of strategies, LP wrappers,
 *         and managing configurations for Velo pools.
 * @dev This interface enables the deployment and configuration of various components in the Velo ecosystem.
 *      It includes functions for creating strategies, managing pool associations, and updating administrative parameters.
 */
interface IVeloDeployFactory is IAccessControlEnumerable {
    /**
     * @notice Thrown when provided parameters are invalid.
     */
    error InvalidParams();

    /**
     * @notice Thrown when attempting to perform an operation on a forbidden pool.
     */
    error ForbiddenPool();

    /**
     * @notice Parameters for a newly created strategy.
     * @param pool The address of the liquidity pool associated with the strategy.
     * @param ammPosition Array of positions for the AMM within the strategy.
     * @param strategyParams Parameters governing the strategy’s behavior and configuration.
     * @param lpWrapper The address of the LP wrapper associated with the strategy.
     * @param caller The address of the account that initiated the strategy creation.
     */
    struct StrategyCreatedParams {
        address pool;
        IVeloAmmModule.AmmPosition[] ammPosition;
        IPulseStrategyModule.StrategyParams strategyParams;
        address lpWrapper;
        address caller;
    }

    /**
     * @notice Emitted when a strategy is successfully created.
     * @param params The parameters associated with the newly created strategy.
     */
    event StrategyCreated(StrategyCreatedParams params);

    /**
     * @notice Emitted when
     * @param pool The address of the pool.
     * @param sender The address of the sender.
     */
    event WrapperRemoved(address indexed pool, address indexed sender);

    /**
     * @notice Emitted when the LP wrapper admin address is updated.
     * @param lpWrapperAdmin The new LP wrapper admin address.
     * @param sender The address of the sender.
     */
    event LpWrapperAdminSet(address indexed lpWrapperAdmin, address indexed sender);

    /**
     * @notice Emitted when the LP wrapper manager address is updated.
     * @param lpWrapperManager The new LP wrapper manager address.
     * @param sender The address of the sender.
     */
    event LpWrapperManagerSet(address indexed lpWrapperManager, address indexed sender);

    /**
     * @notice Emitted when the minimum initial total supply is updated.
     * @param minInitialTotalSupply The new minimum initial total supply.
     * @param sender The address of the sender.
     */
    event MinInitialTotalSupplySet(uint256 indexed minInitialTotalSupply, address indexed sender);

    /**
     * @notice Parameters for deploying a new strategy.
     * @param slippageD9 Slippage tolerance with 9 decimals, affecting strategy operations.
     * @param strategyParams The strategy parameters defining behavior and thresholds.
     * @param securityParams Security parameters for managing risk within the strategy.
     * @param pool The address of the CLPool associated with this strategy.
     * @param maxAmount0 Maximum amount of token0 allowed for the strategy.
     * @param maxAmount1 Maximum amount of token1 allowed for the strategy.
     * @param initialTotalSupply Initial total supply of the LP wrapper tokens.
     * @param totalSupplyLimit Maximum allowable total supply of the LP wrapper tokens.
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
     * @notice Parameters for configuring a pool strategy.
     * @param pool The address of the CLPool.
     * @param strategyParams Strategy parameters defining behavior for the pool.
     * @param maxAmount0 Maximum amount of token0 allowed for the strategy.
     * @param maxAmount1 Maximum amount of token1 allowed for the strategy.
     * @param securityParams Additional security parameters, encoded as bytes, for risk control.
     */
    struct PoolStrategyParameter {
        ICLPool pool;
        IPulseStrategyModule.StrategyParams strategyParams;
        uint256 maxAmount0;
        uint256 maxAmount1;
        bytes securityParams;
    }

    /**
     * @notice Information about minting in a specified tick range.
     * @param amount0 Amount of token0 for the mint operation.
     * @param amount1 Amount of token1 for the mint operation.
     * @param tickLower Lower bound of the tick range for minting.
     * @param tickUpper Upper bound of the tick range for minting.
     */
    struct MintInfo {
        uint256 amount0;
        uint256 amount1;
        int24 tickLower;
        int24 tickUpper;
    }

    /**
     * @notice Creates a strategy based on provided deployment parameters.
     * @param params The parameters for deploying the strategy, encapsulated in `DeployParams`.
     * @return lpWrapper The address of the LP wrapper, which is an ERC20 representation of the LP token.
     */
    function createStrategy(DeployParams calldata params) external returns (ILpWrapper lpWrapper);

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
     * @notice Sets a new LP wrapper admin address.
     * @param lpWrapperAdmin_ The address to set as the LP wrapper admin.
     */
    function setLpWrapperAdmin(address lpWrapperAdmin_) external;

    /**
     * @notice Sets a new LP wrapper manager address.
     * @param lpWrapperManager_ The address to set as the LP wrapper manager.
     */
    function setLpWrapperManager(address lpWrapperManager_) external;

    /**
     * @notice Sets the minimum initial total supply required for an LP wrapper.
     * @param minInitialTotalSupply_ The minimum initial total supply for new LP wrappers.
     */
    function setMinInitialTotalSupply(uint256 minInitialTotalSupply_) external;

    /**
     * @notice Retrieves the name and symbol for a given pool's associated LP wrapper.
     * @param pool The address of the pool.
     * @return name The name of the LP wrapper.
     * @return symbol The symbol of the LP wrapper.
     */
    function configureNameAndSymbol(ICLPool pool)
        external
        view
        returns (string memory name, string memory symbol);

    /**
     * @notice Maps a pool address to its associated LP wrapper address.
     * @param pool The address of the pool.
     * @return lpWrapper The address of the LP wrapper associated with the specified pool.
     */
    function poolToWrapper(address pool) external view returns (address lpWrapper);

    /**
     * @notice Gets the LP wrapper admin address.
     * @return lpWrapperAdmin The address of the LP wrapper admin.
     */
    function lpWrapperAdmin() external view returns (address lpWrapperAdmin);

    /**
     * @notice Gets value of `minInitialTotalSupply`.
     * @return minInitialTotalSupply Value of minimal initial total supply of LpWrapper.
     */
    function minInitialTotalSupply() external view returns (uint256 minInitialTotalSupply);
}
