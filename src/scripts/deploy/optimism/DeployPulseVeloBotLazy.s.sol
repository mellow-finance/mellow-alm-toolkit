// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import "src/bots/PulseVeloBotLazy.sol";

uint128 constant MIN_INITIAL_LIQUDITY = 1000;
uint32 constant PROTOCOL_FEE_D9 = 1e8; // 10%

address constant CORE_ADDRESS = 0xd17613D91150a2345eCe9598D055C7197A1f5A71;
address constant VELO_DEPLOY_FACTORY_ADDRESS = 0x5B1b1aaC71bDca9Ed1dCb2AA357f678584db4029;
address constant NONFUNGIBLE_POSITION_MANAGER_ADDRESS = 0x827922686190790b37229fd06084350E74485b72;

contract Deploy is Script, Test {
    uint256 immutable deployerPrivateKey =
        vm.envUint("TEST_DEPLOYER_PRIVATE_KEY");
    address immutable deployerAddress = vm.addr(deployerPrivateKey);

    function run() public {
        console.log("Deployer address:", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

        PulseVeloBotLazy pulseVeloBotLazy = new PulseVeloBotLazy(
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            CORE_ADDRESS,
            VELO_DEPLOY_FACTORY_ADDRESS
        );
        address pulseVeloBotLazyAddress = address(pulseVeloBotLazy);
        console2.log("pulseVeloBotLazyAddress", pulseVeloBotLazyAddress);

        vm.stopBroadcast();
    }
}
