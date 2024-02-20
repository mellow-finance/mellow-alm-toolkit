// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./ILpWrapper.sol";

interface IVeloDeployFactoryHelper {
    function createLpWrapper(
        ICore core,
        IAmmDepositWithdrawModule ammDepositWithdrawModule,
        string memory name,
        string memory symbol,
        address admin
    ) external returns (ILpWrapper);
}
