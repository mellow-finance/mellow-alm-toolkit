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
        address admin,
        address operator
    ) external returns (ILpWrapper) {
        LpWrapper wrapper = new LpWrapper(
            core,
            ammDepositWithdrawModule,
            name,
            symbol,
            address(this)
        );
        wrapper.grantRole(wrapper.ADMIN_ROLE(), admin);
        wrapper.grantRole(wrapper.ADMIN_DELEGATE_ROLE(), address(this));
        wrapper.grantRole(wrapper.OPERATOR(), operator);
        wrapper.revokeRole(wrapper.ADMIN_DELEGATE_ROLE(), address(this));
        wrapper.revokeRole(wrapper.ADMIN_ROLE(), address(this));
        return wrapper;
    }
}
