// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.25;

import "./base/Constants.sol";

contract Deploy is Script, Test, Addresses {
    function run() public {
        console.log("Deployer address:", DEPLOYER);

        vm.startBroadcast(deployerPrivateKey);

        PulseVeloBotLazy pulseVeloBotLazy = new PulseVeloBotLazy(
            Constants.NONFUNGIBLE_POSITION_MANAGER,
            address(core),
            address(deployFactory)
        );
        address pulseVeloBotLazyAddress = address(pulseVeloBotLazy);
        console2.log("pulseVeloBotLazyAddress", pulseVeloBotLazyAddress);

        vm.stopBroadcast();
    }
}
