// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import "src/bots/PulseVeloBotLazy.sol";

uint128 constant MIN_INITIAL_LIQUDITY = 1000;
uint32 constant PROTOCOL_FEE_D9 = 1e8; // 10%

address constant CORE_ADDRESS = 0xB4AbEf6f42bA5F89Dc060f4372642A1C700b22bC;
address constant NONFUNGIBLE_POSITION_MANAGER_ADDRESS = 0x416b433906b1B72FA758e166e239c43d68dC6F29;

contract Deploy is Script, Test {
    uint256 immutable deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address immutable deployerAddress = vm.addr(deployerPrivateKey);

    function run() public {
        console.log("Deployer address:", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

        PulseVeloBotLazy pulseVeloBotLazy = new PulseVeloBotLazy(
            NONFUNGIBLE_POSITION_MANAGER_ADDRESS,
            CORE_ADDRESS
        );
        address pulseVeloBotLazyAddress = address(pulseVeloBotLazy);
        console2.log("pulseVeloBotLazyAddress", pulseVeloBotLazyAddress);

        vm.stopBroadcast();
    }
}
