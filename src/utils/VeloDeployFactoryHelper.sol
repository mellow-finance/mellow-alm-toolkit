// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/utils/IVeloDeployFactoryHelper.sol";

import "./LpWrapper.sol";

contract VeloDeployFactoryHelper is IVeloDeployFactoryHelper {
    address private immutable _weth;

    constructor(address weth_) {
        _weth = weth_;
    }

    /// @inheritdoc IVeloDeployFactoryHelper
    function createLpWrapper(
        string memory name,
        string memory symbol,
        address admin,
        address manager,
        address pool
    ) external returns (ILpWrapper) {
        LpWrapper wrapper = new LpWrapper(name, symbol, address(this), _weth, msg.sender, pool);
        wrapper.grantRole(wrapper.ADMIN_ROLE(), admin);
        if (manager != address(0)) {
            wrapper.grantRole(wrapper.ADMIN_ROLE(), manager);
        }
        wrapper.renounceRole(wrapper.OPERATOR(), address(this));
        wrapper.renounceRole(wrapper.ADMIN_ROLE(), address(this));
        return wrapper;
    }
}
