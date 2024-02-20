// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../IAmmModule.sol";
import "../IAmmDepositWithdrawModule.sol";

import "../../external/velo/INonfungiblePositionManager.sol";
import "../../external/velo/ICLPool.sol";

/**
 * @title VeloDepositWithdrawModule
 * @dev A contract that implements the IAmmDepositWithdrawModule interface for Velo pools.
 */
interface IVeloDepositWithdrawModule is IAmmDepositWithdrawModule {
    function positionManager()
        external
        view
        returns (INonfungiblePositionManager);

    function ammModule() external view returns (IAmmModule);

    /**
     * @dev Deposits the specified amounts of token0 and token1 into the pool.
     * @param tokenId The ID of the token.
     * @param amount0 The amount of token0 to deposit.
     * @param amount1 The amount of token1 to deposit.
     * @param from The address from which the tokens are to be transferred.
     * @notice The caller must approve the contract to spend the tokens.
     * @notice Tokens distributes proportionally accross all positions.
     */
    function deposit(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1,
        address from
    ) external override returns (uint256 actualAmount0, uint256 actualAmount1);

    /**
     * @dev Withdraws liquidity from a position and transfers the collected tokens to the specified recipient.
     * @param tokenId The ID of the position.
     * @param liquidity The amount of liquidity to withdraw.
     * @param to The address to transfer the collected tokens to.
     * @return actualAmount0 The actual amount of token0 collected.
     * @return actualAmount1 The actual amount of token1 collected.
     * @notice Function collects tokens proportionally from all positions.
     */
    function withdraw(
        uint256 tokenId,
        uint256 liquidity,
        address to
    ) external override returns (uint256 actualAmount0, uint256 actualAmount1);
}
