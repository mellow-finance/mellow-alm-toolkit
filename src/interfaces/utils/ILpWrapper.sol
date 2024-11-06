// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../libraries/PositionLibrary.sol";
import "../modules/strategies/IPulseStrategyModule.sol";
import "../modules/velo/IVeloAmmModule.sol";
import "../oracles/IVeloOracle.sol";
import "./IVeloFarm.sol";
import "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";

/**
 * @title ILpWrapper Interface
 * @notice Interface for the LP token wrapper that combines functionalities for managing liquidity pool positions.
 * @dev This contract extends functionalities from `IVeloFarm`, `IAccessControlEnumerable`, and `IERC20`, and is designed
 *      to facilitate deposit, withdrawal, and parameter management for liquidity positions within a pool.
 *      It provides role-based access control, emits events for critical operations, and handles errors gracefully.
 */
interface ILpWrapper is IVeloFarm, IAccessControlEnumerable, IERC20 {
    /**
     * @notice Thrown when provided amounts are insufficient to execute the operation.
     */
    error InsufficientAmounts();

    /**
     * @notice Thrown when the LP amount is insufficient for a withdrawal operation.
     */
    error InsufficientLpAmount();

    /**
     * @notice Thrown when the deadline for a function call has passed.
     */
    error Deadline();

    /**
     * @notice Thrown when the liquidity amount exceeds the total supply limit.
     */
    error TotalSupplyLimitReached();

    /**
     * @notice Emitted when a deposit is made into the `LpWrapper`.
     * @param sender The address initiating the deposit.
     * @param recipient The address receiving the deposited LP tokens.
     * @param pool The address of the liquidity pool where the deposit is made.
     * @param amount0 The amount of token0 deposited.
     * @param amount1 The amount of token1 deposited.
     * @param lpAmount The amount of LP tokens minted as a result of the deposit.
     * @param totalSupply The updated total supply of LP tokens after the deposit.
     */
    event Deposit(
        address indexed sender,
        address indexed recipient,
        address indexed pool,
        uint256 amount0,
        uint256 amount1,
        uint256 lpAmount,
        uint256 totalSupply
    );

    /**
     * @notice Emitted when a withdrawal is made from the `LpWrapper`.
     * @param sender The address initiating the withdrawal.
     * @param recipient The address receiving the withdrawn tokens.
     * @param pool The address of the liquidity pool from which the withdrawal is made.
     * @param amount0 The amount of token0 withdrawn.
     * @param amount1 The amount of token1 withdrawn.
     * @param lpAmount The amount of LP tokens burned as a result of the withdrawal.
     * @param totalSupply The updated total supply of LP tokens after the withdrawal.
     */
    event Withdraw(
        address indexed sender,
        address indexed recipient,
        address indexed pool,
        uint256 amount0,
        uint256 amount1,
        uint256 lpAmount,
        uint256 totalSupply
    );

    /**
     * @notice Emitted when position parameters are updated.
     * @param slippageD9 The slippage tolerance set, in decimal format with 9 decimals.
     * @param callbackParams The callback parameters for AMM interactions.
     * @param strategyParams The strategy parameters configuring the trading strategy.
     * @param securityParams The security parameters for managing oracle and risk controls.
     */
    event PositionParamsSet(
        uint56 slippageD9,
        IVeloAmmModule.CallbackParams callbackParams,
        IPulseStrategyModule.StrategyParams strategyParams,
        IVeloOracle.SecurityParams securityParams
    );

    /**
     * @notice Emitted when the total supply limit is updated.
     * @param newTotalSupplyLimit The new limit for the total supply of LP tokens.
     * @param totalSupplyLimitOld The previous limit for the total supply of LP tokens.
     * @param totalSupplyCurrent The current total supply of LP tokens at the time of update.
     */
    event TotalSupplyLimitUpdated(
        uint256 newTotalSupplyLimit, uint256 totalSupplyLimitOld, uint256 totalSupplyCurrent
    );

    /**
     * @notice Stores data related to a specific liquidity position.
     * @dev This struct holds detailed information on the parameters and state of a liquidity position within a pool.
     * @param tokenId The unique identifier of the position.
     * @param nonce A nonce used for position uniqueness and tracking changes.
     * @param operator The address authorized to manage or operate this position.
     * @param token0 The address of the first token in the pair (token0).
     * @param token1 The address of the second token in the pair (token1).
     * @param tickSpacing The tick spacing of the pool, representing the minimum tick interval.
     * @param tickLower The lower bound tick of the position’s range.
     * @param tickUpper The upper bound tick of the position’s range.
     * @param liquidity The amount of liquidity provided by this position.
     * @param feeGrowthInside0LastX128 The last recorded fee growth for token0 inside the position’s tick range, in Q128 format.
     * @param feeGrowthInside1LastX128 The last recorded fee growth for token1 inside the position’s tick range, in Q128 format.
     * @param tokensOwed0 The amount of token0 owed to the position due to earned fees.
     * @param tokensOwed1 The amount of token1 owed to the position due to earned fees.
     */
    struct PositionData {
        uint256 tokenId;
        uint96 nonce;
        address operator;
        address token0;
        address token1;
        int24 tickSpacing;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    /**
     * @dev Returns corresponding position info
     * @return data - PositionData struct containing the position's data
     */
    function getInfo() external view returns (PositionLibrary.Position[] memory data);

    /**
     * @dev Returns protocol params of the corresponding Core.sol
     */
    function protocolParams()
        external
        view
        returns (IVeloAmmModule.ProtocolParams memory params, uint256 d9);

    /**
     * @dev Returns the address of the position manager.
     * @return Address of the position manager.
     */
    function positionManager() external view returns (address);

    /**
     * @dev Returns the core contract address.
     * @return Address of the core contract.
     */
    function core() external view returns (ICore);

    /**
     * @dev Returns the address of the AMM module associated with this LP wrapper.
     * @return Address of the AMM module.
     */
    function ammModule() external view returns (IVeloAmmModule);

    /**
     * @dev Returns the oracle contract address.
     * @return Address of the oracle contract.
     */
    function oracle() external view returns (IOracle);

    /**
     * @dev Returns the ID of managed position associated with the LP wrapper contract.
     * @return uint256 - id of the managed position.
     */
    function positionId() external view returns (uint256);

    /**
     * @dev Returns the limit of the total supply.
     * @return Value of the limit of the total supply.
     */
    function totalSupplyLimit() external view returns (uint256);

    /**
     * @notice Initializes the contract with the specified configuration parameters.
     * @dev This function sets up initial values for the position ID, total supply, supply limit, and assigns administrative roles.
     *      This function should be called only once to initialize the contract.
     * @param positionId_ The unique identifier for the `Core` position.
     * @param initialTotalSupply The initial total supply of LP tokens.
     * @param totalSupplyLimit_ The maximum allowable total supply of LP tokens.
     * @param admin_ The address of the contract administrator, with elevated permissions.
     * @param manager_ The address of the contract manager, responsible for managing positions.
     * @param name_ The name of the LP token.
     * @param symbol_ The symbol of the LPtoken.
     */
    function initialize(
        uint256 positionId_,
        uint256 initialTotalSupply,
        uint256 totalSupplyLimit_,
        address admin_,
        address manager_,
        string memory name_,
        string memory symbol_
    ) external;

    /**
     * @dev Deposits specified amounts of tokens into corresponding managed position and mints LP tokens to the specified address.
     * @param amount0 Amount of token0 to deposit.
     * @param amount1 Amount of token1 to deposit.
     * @param minLpAmount Minimum amount of LP tokens required to be minted.
     * @param to Address to receive the minted LP tokens.
     * @param deadline Timestamp by which the deposit operation must be executed.
     * @return actualAmount0 Actual amount of token0 deposited.
     * @return actualAmount1 Actual amount of token1 deposited.
     * @return lpAmount Amount of LP tokens minted.
     */
    function deposit(
        uint256 amount0,
        uint256 amount1,
        uint256 minLpAmount,
        address to,
        uint256 deadline
    ) external returns (uint256 actualAmount0, uint256 actualAmount1, uint256 lpAmount);

    /**
     * @dev Burns LP tokens and transfers the underlying assets to the specified address.
     * @param lpAmount Amount of LP tokens to withdraw.
     * @param minAmount0 Minimum amount of asset 0 to receive.
     * @param minAmount1 Minimum amount of asset 1 to receive.
     * @param to Address to transfer the underlying assets to.
     * @param deadline Timestamp by which the withdrawal operation must be executed.
     * @return amount0 Actual amount of asset 0 received.
     * @return amount1 Actual amount of asset 1 received.
     * @return actualLpAmount Actual amount of LP tokens withdrawn.
     */
    function withdraw(
        uint256 lpAmount,
        uint256 minAmount0,
        uint256 minAmount1,
        address to,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount);

    /**
     * @dev Sets the managed position parameters for a specified ID, including slippage, strategy, and security parameters.
     * @param slippageD9 Maximum permissible proportion of capital allocated to positions for compensating rebalancers, scaled by 1e9.
     * @param callbackParams Callback parameters for the position.
     * @param strategyParams Strategy parameters for managing the position.
     * @param securityParams Security parameters for protecting the position.
     * Requirements:
     * - Caller must have the ADMIN_ROLE.
     */
    function setPositionParams(
        uint32 slippageD9,
        IVeloAmmModule.CallbackParams memory callbackParams,
        IPulseStrategyModule.StrategyParams memory strategyParams,
        IVeloOracle.SecurityParams memory securityParams
    ) external;

    /**
     * @dev Sets the managed position parameters for a specified ID, including slippage, strategy, and security parameters.
     * @param slippageD9 Maximum permissible proportion of capital allocated to positions for compensating rebalancers, scaled by 1e9.
     * @param callbackParams Callback parameters for the position.
     * @param strategyParams Strategy parameters for managing the position.
     * @param securityParams Security parameters for protecting the position.
     * Requirements:
     * - Caller must have the ADMIN_ROLE.
     */
    function setPositionParams(
        uint32 slippageD9,
        bytes memory callbackParams,
        bytes memory strategyParams,
        bytes memory securityParams
    ) external;

    /**
     * @notice Sets the slippage tolerance for the strategy, in decimal format with 9 decimal places.
     * @dev This function updates the slippage tolerance parameter, allowing fine control over acceptable price movement during rebalance.
     * @param slippageD9 The slippage tolerance expressed as a uint32 value, with 9 decimal places (e.g., 500000000 represents 0.5%).
     * Requirements:
     * - Caller must have the ADMIN_ROLE.
     */
    function setSlippageD9(uint32 slippageD9) external;

    /**
     * @notice Sets the callback parameters for AMM interactions.
     * @dev This function updates the callback parameters that define specific configurations or behaviors
     *      when interacting with the AMM (Automated Market Maker).
     * @param callbackParams A struct containing the callback parameters, which may include settings
     *        like minimum expected output, slippage tolerance, or other AMM-specific configurations.
     */
    function setCallbackParams(IVeloAmmModule.CallbackParams calldata callbackParams) external;

    /**
     * @notice Sets the parameters for the strategy.
     * @dev This function updates the strategy parameters for managing the position.
     * @param strategyParams A struct containing the strategy parameters, including details like position width, tick spacing, and other relevant settings for strategy configuration.
     * Requirements:
     * - Caller must have the ADMIN_ROLE.
     */
    function setStrategyParams(IPulseStrategyModule.StrategyParams calldata strategyParams)
        external;

    /**
     * @notice Sets the security parameters for the oracle or system.
     * @dev This function updates security-related parameters, providing control over risk management settings such as price limits, validation intervals, or other security thresholds.
     * @param securityParams A struct containing security parameters, including configurations relevant to maintaining oracle integrity and risk controls.
     * Requirements:
     * - Caller must have the ADMIN_ROLE.
     */
    function setSecurityParams(IVeloOracle.SecurityParams calldata securityParams) external;

    /**
     * @dev Sets a new value of `totalSupplyLimit`
     * @param totalSupplyLimitNew The value of a new `totalSupplyLimit`.
     * Requirements:
     * - Caller must have the ADMIN_ROLE.
     */
    function setTotalSupplyLimit(uint256 totalSupplyLimitNew) external;

    /**
     * @dev This function is used to perform an empty rebalance for a specific position.
     * @notice This function calls the `beforeRebalance` and `afterRebalance` functions of the `IAmmModule` contract for each tokenId of the position.
     * @notice If any of the delegate calls fail, the function will revert.
     * Requirements:
     * - Caller must have the OPERATOR role.
     */
    function emptyRebalance() external;

    /**
     * @notice Returns the address of the liquidity pool associated with this contract.
     * @return The address of the liquidity pool.
     */
    function pool() external view returns (address);

    /**
     * @notice Returns the ERC20 token contract for token0 in the pool.
     * @return The IERC20 contract of token0.
     */
    function token0() external view returns (IERC20);

    /**
     * @notice Returns the ERC20 token contract for token1 in the pool.
     * @return The IERC20 contract of token1.
     */
    function token1() external view returns (IERC20);
}
