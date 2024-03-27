// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../modules/IAmmDepositWithdrawModule.sol";

import "../ICore.sol";

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
     * @return actualAmount0 Actual amount of token0 deposited.
     * @return actualAmount1 Actual amount of token1 deposited.
     * @return lpAmount Amount of LP tokens minted.
     */
    function deposit(
        uint256 amount0,
        uint256 amount1,
        uint256 minLpAmount,
        address to
    )
        external
        returns (
            uint256 actualAmount0,
            uint256 actualAmount1,
            uint256 lpAmount
        );

    /**
     * @dev Withdraws LP tokens and transfers the underlying assets to the specified address.
     * @param lpAmount Amount of LP tokens to withdraw.
     * @param minAmount0 Minimum amount of asset 0 to receive.
     * @param minAmount1 Minimum amount of asset 1 to receive.
     * @param to Address to transfer the underlying assets to.
     * @return amount0 Actual amount of asset 0 received.
     * @return amount1 Actual amount of asset 1 received.
     * @return actualLpAmount Actual amount of LP tokens withdrawn.
     */
    function withdraw(
        uint256 lpAmount,
        uint256 minAmount0,
        uint256 minAmount1,
        address to
    )
        external
        returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount);

    /**
     * @dev Sets the managed position parameters for a specified ID, including slippage, strategy, and security parameters.
     * @param slippageD4 Maximum permissible proportion of capital allocated to positions for compensating rebalancers, scaled by 1e4.
     * @param callbackParams Callback parameters for the position.
     * @param strategyParams Strategy parameters for managing the position.
     * @param securityParams Security parameters for protecting the position.
     * Requirements:
     * - Caller must have the ADMIN_ROLE.
     */
    function setPositionParams(
        uint16 slippageD4,
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
