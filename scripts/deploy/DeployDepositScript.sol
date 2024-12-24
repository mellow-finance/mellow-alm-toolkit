// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "src/utils/DepositHelper.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/Vm.sol";

contract DeployScript is Script {
    uint256 immutable deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address immutable DEPLOYER = vm.addr(deployerPrivateKey);
    
    function run() external {
        vm.startBroadcast(deployerPrivateKey);
        DepositHelper depositHelper = new DepositHelper();
        console2.log("DepositHelper address", address(depositHelper));
      //  revert("success");
    }
}