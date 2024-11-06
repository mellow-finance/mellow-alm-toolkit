// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.25;

interface IFactoryRegistry {
    function approve(address poolFactory, address votingRewardsFactory, address gaugeFactory)
        external;

    function isPoolFactoryApproved(address poolFactory) external returns (bool);

    function factoriesToPoolFactory(address poolFactory)
        external
        returns (address votingRewardsFactory, address gaugeFactory);
}
