// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@synthetix/contracts/StakingRewards.sol";

import "../interfaces/utils/IVeloDeployFactoryHelper.sol";

import "./LpWrapper.sol";

contract VeloDeployFactoryHelper is IVeloDeployFactoryHelper {
    address private immutable _weth;

    constructor(address weth_) {
        _weth = weth_;
    }

    /// @inheritdoc IVeloDeployFactoryHelper
    function createLpWrapper(
        ICore core,
        IAmmDepositWithdrawModule ammDepositWithdrawModule,
        string memory name,
        string memory symbol,
        address admin,
        address manager
    ) external returns (ILpWrapper) {
        LpWrapper wrapper = new LpWrapper(
            core,
            ammDepositWithdrawModule,
            name,
            symbol,
            address(this),
            _weth
        );
        wrapper.grantRole(wrapper.ADMIN_ROLE(), admin);
        if (manager != address(0)) {
            wrapper.grantRole(wrapper.ADMIN_ROLE(), manager);
        }
        wrapper.renounceRole(wrapper.OPERATOR(), address(this));
        wrapper.renounceRole(wrapper.ADMIN_ROLE(), address(this));
        return wrapper;
    }

    /// @inheritdoc IVeloDeployFactoryHelper
    function createStakingRewards(
        address owner,
        address operator,
        address reward,
        address token
    ) external returns (address) {
        return address(new StakingRewards(owner, operator, reward, token));
    }
}
