// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "src/scripts/deploy/DeployStrategy.s.sol";
import "src/scripts/deploy/DeployVeloLazy.s.sol";

contract DeployCoreAndStrategyTest is Test, DeployStrategy, DeployVeloLazy {
    function run() public override(DeployStrategy, DeployVeloLazy) {}

    function testDeploy() public {
        vm.startPrank(DEPLOYER);

        VeloDeployFactory veloDeployFactoryAddress = deployCore();
        IVeloDeployFactory.MutableParams memory params =
            IVeloDeployFactory(veloDeployFactoryAddress).getMutableParams();

        Compounder farmOperator = Compounder(params.farmOperator);

        address[] memory poolAddresses = new address[](parameters.length);

        for (uint256 i = 0; i < 1; i++) {
            poolAddresses[i] = address(parameters[i].pool);
            deployStrategy(veloDeployFactoryAddress, parameters[i]);
        }

        vm.stopPrank();

        skip(7 days + 1);

        vm.startPrank(CORE_OPERATOR);

        /*         farmOperator.compound(
            IVeloDeployFactory(veloDeployFactoryAddress),
            poolAddresses
        );
        */
        vm.stopPrank();
    }
}
