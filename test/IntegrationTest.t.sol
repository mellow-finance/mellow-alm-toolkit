// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../scripts/deploy/Constants.sol";
import "../scripts/deploy/DeployScript.sol";

contract IntegrationTest is Test, DeployScript {
    function test() external {
        CoreDeploymentParams memory params = Constants.getDeploymentParams();
        vm.startPrank(params.deployer);
        CoreDeployment memory contracts = deployCore(params);
        console2.log("Core: %b", address(contracts.core));
        vm.stopPrank();
    }
}
