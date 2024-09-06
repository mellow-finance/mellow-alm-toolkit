// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../modules/IAmmDepositWithdrawModule.sol";
import "../external/IWETH9.sol";

import "../ICore.sol";

import "../modules/velo/IVeloAmmModule.sol";
import "../modules/strategies/IPulseStrategyModule.sol";
import "../oracles/IVeloOracle.sol";

/**
 * @title ILpWrapper Interface
 * @dev Interface for a liquidity pool wrapper, facilitating interactions between LP tokens, AMM modules, and core contract functionalities.
 */
interface ILpWrapper {
    // Custom errors for handling operation failures
    error InsufficientAmounts(); // Thrown when provided amounts are insufficient for operation execution
    error InsufficientLpAmount(); // Thrown when the LP amount for withdrawal is insufficient
    error AlreadyInitialized(); // Thrown if the wrapper is already initialized
    error DepositCallFailed(); // Thrown when a deposit operation fails due to deletage call to the AmmDepositWithdrawModule
    error WithdrawCallFailed(); // Thrown when a withdrawal operation fails due to deletage call to the AmmDepositWithdrawModule
    error Deadline(); // Thrown when the deadline for a function call has passed
    error InvalidPositionsCount(); // Thrown when the number of positions is invalid

    event Deposit(
        address indexed recipient,
        address indexed pool,
        uint256 lpAmount,
        uint256 amount0,
        uint256 amount1
    );

    event Withdraw(
        address indexed recipient,
        address indexed pool,
        uint256 lpAmount,
        uint256 amount0,
        uint256 amount1
    );

    event PositionParamsSet(
        uint56 slippageD9,
        IVeloAmmModule.CallbackParams callbackParams,
        IPulseStrategyModule.StrategyParams strategyParams,
        IVeloOracle.SecurityParams securityParams
    );

    // Position data structure
    struct PositionData {
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
     * @return tokenId - ID of the NFT representing the position
     * @return data - PositionData struct containing the position's data
     */
    function getInfo()
        external
        view
        returns (uint256 tokenId, PositionData memory data);

    /**
     * @dev Returns the address of the synthetix farm contract.
     * @return Address of the farm contract.
     */
    function getFarm() external view returns (address);

    /**
     * @dev Deposits specified amounts of tokens into corresponding managed position, mints LP tokens and stakes them in the farm on behalf of `to`.
     * @param amount0 Amount of token0 to deposit.
     * @param amount1 Amount of token1 to deposit.
     * @param minLpAmount Minimum amount of LP tokens required to be minted.
     * @param to Address to receive the minted LP tokens.
     * @param deadline Timestamp by which the deposit operation must be executed.
     * @return actualAmount0 Actual amount of token0 deposited.
     * @return actualAmount1 Actual amount of token1 deposited.
     * @return lpAmount Amount of LP tokens minted.
     */
    function depositAndStake(
        uint256 amount0,
        uint256 amount1,
        uint256 minLpAmount,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 actualAmount0,
            uint256 actualAmount1,
            uint256 lpAmount
        );

    /**
     * @dev Withdraws LP tokens from the farm, burns them, and transfers the underlying assets to the specified address.
     * @param lpAmount Amount of LP tokens to withdraw.
     * @param minAmount0 Minimum amount of asset 0 to receive.
     * @param minAmount1 Minimum amount of asset 1 to receive.
     * @param to Address to transfer the underlying assets to.
     * @param deadline Timestamp by which the withdrawal operation must be executed.
     * @return amount0 Actual amount of asset 0 received.
     * @return amount1 Actual amount of asset 1 received.
     * @return actualLpAmount Actual amount of LP tokens withdrawn.
     */
    function unstakeAndWithdraw(
        uint256 lpAmount,
        uint256 minAmount0,
        uint256 minAmount1,
        address to,
        uint256 deadline
    )
        external
        returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount);

    /**
     * @dev Harvests the reward tokens from the farm to msg.sender.
     */
    function getReward() external;

    /**
     * @dev Returns the amount of reward tokens earned by the specified user.
     */
    function earned(address user) external view returns (uint256 amount);

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
     * @dev Returns the AMM Deposit Withdraw Module contract address.
     * @return Address of the IAmmDepositWithdrawModule contract.
     */
    function ammDepositWithdrawModule()
        external
        view
        returns (IAmmDepositWithdrawModule);

    /**
     * @dev Returns the core contract address.
     * @return Address of the core contract.
     */
    function core() external view returns (ICore);

    /**
     * @dev Returns the address of the AMM module associated with this LP wrapper.
     * @return Address of the AMM module.
     */
    function ammModule() external view returns (IAmmModule);

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
     * @dev Initializes the LP wrapper contract with the specified token ID and initial total supply.
     * @param positionId_ Managed position ID to be associated with the LP wrapper contract.
     * @param initialTotalSupply Initial total supply of the LP wrapper contract.
     */
    function initialize(
        uint256 positionId_,
        uint256 initialTotalSupply
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
    )
        external
        returns (
            uint256 actualAmount0,
            uint256 actualAmount1,
            uint256 lpAmount
        );

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
    )
        external
        returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount);

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
     * @dev This function is used to perform an empty rebalance for a specific position.
     * @notice This function calls the `beforeRebalance` and `afterRebalance` functions of the `IAmmModule` contract for each tokenId of the position.
     * @notice If any of the delegate calls fail, the function will revert.
     * Requirements:
     * - Caller must have the OPERATOR role.
     */
    function emptyRebalance() external;
}
