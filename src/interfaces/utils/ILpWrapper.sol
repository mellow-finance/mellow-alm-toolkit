// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "../modules/IAmmModule.sol";
import "../modules/IAmmDepositWithdrawModule.sol";

import "../ICore.sol";

interface ILpWrapper {
    error InsufficientAmounts();
    error InsufficientLpAmount();
    error AlreadyInitialized();
    error DepositCallFailed();
    error WithdrawCallFailed();

    function positionManager() external view returns (address);

    function ammDepositWithdrawModule()
        external
        view
        returns (IAmmDepositWithdrawModule);

    function core() external view returns (ICore);

    function ammModule() external view returns (IAmmModule);

    function oracle() external view returns (IOracle);

    function tokenId() external view returns (uint256);

    /**
     * @dev Initializes the LP wrapper contract with the given token ID and initial total supply.
     * @param tokenId_ The token ID to be associated with the LP wrapper contract.
     * @param initialTotalSupply The initial total supply of the LP wrapper contract.
     */
    function initialize(uint256 tokenId_, uint256 initialTotalSupply) external;

    /**
     * @dev Deposits specified amounts of tokens into the LP wrapper contract and mints LP tokens to the specified address.
     * @param amount0 The amount of token0 to deposit.
     * @param amount1 The amount of token1 to deposit.
     * @param minLpAmount The minimum amount of LP tokens required to be minted.
     * @param to The address to receive the minted LP tokens.
     * @return actualAmount0 The actual amount of token0 deposited.
     * @return actualAmount1 The actual amount of token1 deposited.
     * @return lpAmount The amount of LP tokens minted.
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
     * @param lpAmount The amount of LP tokens to withdraw.
     * @param minAmount0 The minimum amount of asset 0 to receive.
     * @param minAmount1 The minimum amount of asset 1 to receive.
     * @param to The address to transfer the underlying assets to.
     * @return amount0 The actual amount of asset 0 received.
     * @return amount1 The actual amount of asset 1 received.
     * @return actualLpAmount The actual amount of LP tokens withdrawn.
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
     * @dev Sets the position parameters for a given ID.
     * @param slippageD4 The maximum permissible proportion of the capital allocated to positions
     * that can be used to compensate rebalancers for their services. A value of 10,000 (1e4) represents 100%.
     * @param strategyParams The strategy parameters.
     * @param securityParams The security parameters.
     * Requirements:
     * - The caller must have the ADMIN_ROLE.
     * - The strategy parameters must be valid.
     * - The security parameters must be valid.
     */
    function setPositionParams(
        uint16 slippageD4,
        bytes memory strategyParams,
        bytes memory securityParams
    ) external;

    function emptyRebalance() external;
}
