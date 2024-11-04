// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../libraries/PositionLibrary.sol";
import "../modules/strategies/IPulseStrategyModule.sol";
import "../modules/velo/IVeloAmmModule.sol";
import "../oracles/IVeloOracle.sol";
import "./IVeloFarm.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ILpWrapper Interface
 * @dev Interface for a liquidity pool wrapper, facilitating interactions between LP tokens, AMM modules, and core contract functionalities.
 */
interface ILpWrapper is IVeloFarm, IAccessControlEnumerable, IERC20 {
    // Custom errors for handling operation failures
    error InsufficientAmounts(); // Thrown when provided amounts are insufficient for operation execution
    error InsufficientAllowance(); // Thrown when provided allowance are insufficient for operation execution
    error InsufficientLpAmount(); // Thrown when the LP amount for withdrawal is insufficient
    error AlreadyInitialized(); // Thrown if the wrapper is already initialized
    error DepositCallFailed(); // Thrown when a deposit operation fails due to deletage call to the AmmDepositWithdrawModule
    error WithdrawCallFailed(); // Thrown when a withdrawal operation fails due to deletage call to the AmmDepositWithdrawModule
    error Deadline(); // Thrown when the deadline for a function call has passed
    error InvalidPositionsCount(); // Thrown when the number of positions is invalid
    error TotalSupplyLimitReached(); // Thrown when the amount of liquidity is above the limit

    event Deposit(
        address indexed sender,
        address indexed recipient,
        address indexed pool,
        uint256 amount0,
        uint256 amount1,
        uint256 lpAmount,
        uint256 totalSupply
    );

    event Withdraw(
        address indexed sender,
        address indexed recipient,
        address indexed pool,
        uint256 amount0,
        uint256 amount1,
        uint256 lpAmount,
        uint256 totalSupply
    );

    event PositionParamsSet(
        uint56 slippageD9,
        IVeloAmmModule.CallbackParams callbackParams,
        IPulseStrategyModule.StrategyParams strategyParams,
        IVeloOracle.SecurityParams securityParams
    );

    event TotalSupplyLimitUpdated(
        uint256 newTotalSupplyLimit, uint256 totalSupplyLimitOld, uint256 totalSupplyCurrent
    );

    // Position data structure
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

    function pool() external view returns (address);
    function token0() external view returns (IERC20);
    function token1() external view returns (IERC20);
}
