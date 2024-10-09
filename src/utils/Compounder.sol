// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IVeloDeployFactory, ILpWrapper, ICore, ICounter, IVeloAmmModule} from "./VeloDeployFactory.sol";
import {StakingRewards} from "./VeloDeployFactoryHelper.sol";
import {DefaultAccessControl} from "./DefaultAccessControl.sol";

contract Compounder is DefaultAccessControl {
    constructor(address admin) DefaultAccessControl(admin) {}

    function compound(
        IVeloDeployFactory factory,
        address[] memory pools
    ) external {
        _requireAtLeastOperator();

        uint256 timestamp = block.timestamp;
        for (uint256 i = 0; i < pools.length; i++) {
            address pool = pools[i];
            IVeloDeployFactory.PoolAddresses memory addresses = factory
                .poolToAddresses(pool);
            StakingRewards farm = StakingRewards(addresses.synthetixFarm);
            if (address(farm) == address(0)) continue;
            if (timestamp < farm.periodFinish()) continue;
            ILpWrapper wrapper = ILpWrapper(addresses.lpWrapper);
            wrapper.emptyRebalance();
            IVeloAmmModule.CallbackParams memory params_ = ICore(wrapper.core())
                .managedPositionAt(wrapper.positionId())
                .coreParams
                .callbackParams;
            ICounter counter = ICounter(params_.counter);
            farm.notifyRewardAmount(counter.value());
            counter.reset();
        }
    }
}
