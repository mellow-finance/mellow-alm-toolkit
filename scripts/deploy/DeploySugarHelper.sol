// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "src/sugar/SugarHelper.sol";

contract DeploySugarHelper is Script {
    address immutable deployFactoryAddress = 0xAc5726bb220F6d75DD737047320E57dF60Be0D1B;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_DEPLOYER_KEY");
        address DEPLOYER = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        SugarHelper helper = deploySugarHelper(deployFactoryAddress);
        console2.log("SugarHelper deployed at:", address(helper));
        vm.stopBroadcast();
        // revert("success");
    }

    function deploySugarHelper(address deployFactoryAddress)
        internal
        returns (SugarHelper helper)
    {
        helper = new SugarHelper(deployFactoryAddress);
    }
}
