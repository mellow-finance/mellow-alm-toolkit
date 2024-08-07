// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import "src/utils/VeloSugarHelper.sol";

address constant DEPLOY_FACTORY_ADDRESS = 0x3F9E6301E76d83A7c6e19461a08d27f844E316D3;

contract DeployVeloSugarHelper is Script, Test {
    uint256 immutable deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address immutable deployerAddress = vm.addr(deployerPrivateKey);

    function run() public {
        console.log("Deployer address:", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);
        
        VeloSugarHelper veloSugarHelper = new VeloSugarHelper(DEPLOY_FACTORY_ADDRESS);

        vm.stopBroadcast();

        console2.log("VeloSugarHelper address", address(veloSugarHelper));
    }
}