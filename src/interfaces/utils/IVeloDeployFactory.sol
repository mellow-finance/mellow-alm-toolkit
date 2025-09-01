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
     * @notice Thrown when the deployment parameters are invalid.
     */
    error InvalidDeployParams();

    /**
     * @notice Thrown when the deployment parameters are already accepted.
     */
    error DeployParamsAlreadyAccepted(bytes32);

    /**
     * @notice Thrown when the deployment parameters are not proposed.
     */
    error DeployParamsNotProposed(bytes32);

    /**
     * @notice Thrown when the deployment parameters are already proposed.
     */
    error DeployParamsAlreadyProposed(bytes32);

    /**
     * @notice Thrown when the deployment parameters are not accepted.
     */
    error DeployParamsNotAccepted(bytes32);

    /**
     * @notice Thrown when the deployment parameters are already deployed.
     */
    error DeployParamsAlreadyDeployed(bytes32, address);

    /**
     * @notice Thrown when the deployment parameters are not deployed.
     */
    error DeployParamsNotDeployed(bytes32);

    /**
     * @notice Thrown when the total supply value is invalid.
     */
    error InvalidTotalSupplyValue();

    /**
     * @notice Thrown when the minting of a non-fungible position fails.
     */
    error NonfungiblePositionMintError();

    /**
     * @notice Thrown when the approval of a non-fungible position fails.
     */
    error NonfungiblePositionApproveFailed();

    /**
     * @notice Thrown when an LP wrapper already exists for a pool.
     */
    error LpWrapperAlreadyExists(address);

    /**
     * @notice Thrown when the provided index is invalid.
     */
    error InvalidIndex();

    /**
     * @notice Thrown when attempting to perform an operation on a forbidden pool.
     */
    error ForbiddenPool();

    enum DeployParamsStatus {
        None,
        Proposed,
        Accepted
    }

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
     * @notice Emitted when deployment parameters are proposed.
     * @param proposalId The ID of the proposal.
     * @param proposer The address of the proposer.
     * @param params The deployment parameters.
     */
    event DeployParamsProposed(
        bytes32 indexed proposalId, address indexed proposer, DeployParams params
    );

    /**
     * @notice Emitted when deployment parameters are accepted.
     * @param proposalId The ID of the proposal.
     */
    event DeployParamsAccepted(bytes32 indexed proposalId);

    /**
     * @notice Emitted when a strategy is successfully created.
     * @param params The parameters associated with the newly created strategy.
     */
    event StrategyCreated(StrategyCreatedParams params);

    /**
     * @notice Emitted when a wrapper is removed from a pool.
     * @param pool The address of the pool.
     * @param lpWrapper The address of the LP wrapper.
     * @param sender The address of the sender.
     */
    event WrapperRemoved(address indexed pool, address indexed lpWrapper, address indexed sender);

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
        address pool;
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
        address pool;
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
     * @notice Proposes a new set of deployment parameters. Make all possible parameter checks.
     * If any check fails, revert with an appropriate error.
     * @param params The deployment parameters to propose.
     * @return The ID of the created proposal.
     */
    function proposeDeployParams(DeployParams memory params) external returns (bytes32);

    /**
     * @notice Accepts a proposed set of deployment parameters.
     * @param proposalId The ID of the proposal to accept.
     */
    function acceptDeployParams(bytes32 proposalId) external;

    /**
     * @notice Creates a strategy based on provided deployment parameters.
     * @param proposalId The ID of the accepted proposal containing the deployment parameters.
     * @return The address of the LP wrapper, which is an ERC20 representation of the LP token.
     */
    function deployStrategy(bytes32 proposalId) external returns (ILpWrapper);

    /**
     * @notice Retrieves the LP wrapper associated with the given deployment parameters.
     * @param deployParams The deployment parameters for which to retrieve the LP wrapper.
     * @return The address of the LP wrapper associated with the given deployment parameters.
     */
    function deployParamsToWrapper(DeployParams memory deployParams)
        external
        view
        returns (ILpWrapper);

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
     * @notice Allows the caller to claim any pending tokens.
     * @dev If the specified token address is the zero address (address(0)),
     *      the function transfers pending Ether (ETH) to the caller. Otherwise,
     *      it transfers the pending tokens of the specified ERC20 token.
     * @param token The address of the token to claim. Use address(0) to claim ETH.
     */
    function claim(address token) external;

    /**
     * @notice Retrieves the name and symbol for a given pool's associated LP wrapper.
     * @param pool The address of the pool.
     * @return name The name of the LP wrapper.
     * @return symbol The symbol of the LP wrapper.
     */
    function configureNameAndSymbol(address pool)
        external
        view
        returns (string memory name, string memory symbol);

    /**
     * @notice Computes the hash of the deployment parameters.
     * @param deployParams The deployment parameters to hash.
     * @return The hash of the deployment parameters.
     */
    function deployParamsHash(DeployParams memory deployParams) external pure returns (bytes32);

    /**
     * @notice Retrieves the deployment parameters status associated with a specific proposal ID.
     * @param proposalId The ID of the proposal to retrieve.
     * @return The deployment parameters status associated with the specified proposal ID.
     */
    function getDeployParamsStatusById(bytes32 proposalId) external view returns (uint160);

    /**
     * @notice Retrieves the deployment parameters status associated with a specific set of deployment parameters.
     * @param deployParams The deployment parameters to retrieve the status for.
     * @return The deployment parameters status associated with the specified set of deployment parameters.
     */
    function getDeployParamsStatus(DeployParams memory deployParams)
        external
        view
        returns (uint160);

    /**
     * @notice Retrieves the total count of LP wrappers.
     * @return The total count of LP wrappers.
     */
    function getLpWrapperCount() external view returns (uint256);

    /**
     * @notice Retrieves the LP wrapper associated with a specific index.
     * @param index The index of the LP wrapper to retrieve.
     * @return The LP wrapper associated with the specified index.
     */
    function getLpWrapperByIndex(uint256 index) external view returns (ILpWrapper);

    /**
     * @notice Retrieves the deployment parameters associated with a specific proposal ID.
     * @param proposalId The ID of the proposal to retrieve.
     * @return The deployment parameters associated with the specified proposal ID.
     */
    function getDeployParamsById(bytes32 proposalId) external view returns (DeployParams memory);

    /**
     * @notice Checks if a given set of deployment parameters has been proposed.
     * @param deployParams The deployment parameters to check.
     * @return isProposed True if the deployment parameters have been proposed, false otherwise.
     */
    function isProposedDeployParams(DeployParams memory deployParams)
        external
        view
        returns (bool);

    /**
     * @notice Checks if a given set of deployment parameters has been accepted.
     * @param deployParams The deployment parameters to check.
     * @return isAccepted True if the deployment parameters have been accepted, false otherwise.
     */
    function isAcceptedDeployParams(DeployParams memory deployParams)
        external
        view
        returns (bool);

    /**
     * @notice Checks if a given set of deployment parameters has been deployed.
     * @param deployParams The deployment parameters to check.
     * @return isDeployed True if the deployment parameters have been deployed, false otherwise.
     */
    function isDeployedDeployParams(DeployParams memory deployParams)
        external
        view
        returns (bool);

    /**
     * @notice Checks if a given LP wrapper is an entity.
     * @param lpWrapper The address of the LP wrapper.
     * @return isEntity True if the LP wrapper is an entity, false otherwise.
     */
    function isEntity(address lpWrapper) external view returns (bool);

    /**
     * @notice Checks if a given LP wrapper belongs to a specific pool.
     * @param lpWrapper The address of the LP wrapper.
     * @param pool The address of the pool.
     * @return isEntity True if the LP wrapper is associated with the pool, false otherwise.
     */
    function isEntity(address lpWrapper, address pool) external view returns (bool);

    /**
     * @notice Maps a pool address to its associated LP wrapper addresses.
     * @param pool The address of the pool.
     * @return Array of addresses of the LP wrappers associated with the specified pool.
     */
    function poolToWrappers(address pool) external view returns (address[] memory);

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
