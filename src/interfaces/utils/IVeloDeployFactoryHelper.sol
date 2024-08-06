// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./ILpWrapper.sol";

interface IVeloDeployFactoryHelper {
    /**
     * @dev Creates a new LP wrapper contract.
     * @param core The address of the core contract.
     * @param ammDepositWithdrawModule The address of the AMM deposit/withdraw module contract.
     * @param name The name of the LP wrapper contract.
     * @param symbol The symbol of the LP wrapper contract.
     * @param admin The address of the admin for the LP wrapper contract.
     * @param manager The address of the manager contract for auto update of parameters.
     * @return ILpWrapper The newly created LP wrapper contract.
     */
    function createLpWrapper(
        ICore core,
        IAmmDepositWithdrawModule ammDepositWithdrawModule,
        string memory name,
        string memory symbol,
        address admin,
        address manager,
        address pool
    ) external returns (ILpWrapper);
}
