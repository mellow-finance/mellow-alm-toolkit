// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../IAmmDepositWithdrawModule.sol";

import "../../external/velo/INonfungiblePositionManager.sol";
import "../../external/velo/ICLPool.sol";

/**
 * @title IVeloDepositWithdrawModule Interface
 * @dev Implements the IAmmDepositWithdrawModule interface specifically for Velo protocol pools,
 * facilitating the deposit and withdrawal of liquidity in an efficient and protocol-compliant manner.
 */
interface IVeloDepositWithdrawModule is IAmmDepositWithdrawModule {
    /**
     * @dev Returns the address of the Velo protocol's non-fungible position manager contract.
     * @return INonfungiblePositionManager contract, facilitating interactions
     * with Velo protocol's liquidity positions.
     */
    function positionManager()
        external
        view
        returns (INonfungiblePositionManager);
}
