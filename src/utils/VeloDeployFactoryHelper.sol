// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/utils/IVeloDeployFactoryHelper.sol";

import "./LpWrapper.sol";

contract VeloDeployFactoryHelper is IVeloDeployFactoryHelper {
    function createLpWrapper(
        ICore core,
        IAmmDepositWithdrawModule ammDepositWithdrawModule,
        string memory name,
        string memory symbol,
        address admin
    ) external returns (ILpWrapper) {
        return
            new LpWrapper(core, ammDepositWithdrawModule, name, symbol, admin);
    }
}
