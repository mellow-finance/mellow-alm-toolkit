// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "src/scripts/deploy/optimism/DeployStrategy.s.sol";
import "src/scripts/deploy/optimism/DeployVeloLazy.s.sol";

contract DeployCoreAndStrategyTest is Test, DeployStrategy, DeployVeloLazy {

    function run() public override(DeployStrategy, DeployVeloLazy) {}

    function testDeploy() public {
        vm.startPrank(DEPLOYER);

        CreateStrategyHelper.PoolParameter[]
            memory parameters = setPoolParameters();

        (
            address veloDeployFactoryAddress,
            address createStrategyHelperAddress
        ) = deployCore();

        IVeloDeployFactory.MutableParams memory params = IVeloDeployFactory(
            veloDeployFactoryAddress
        ).getMutableParams();

        Compounder farmOperator = Compounder(params.farmOperator);

        deployStrategy(
            veloDeployFactoryAddress,
            createStrategyHelperAddress,
            0
        );

        vm.stopPrank();

        address[] memory poolAddresses = new address[](1);

        poolAddresses[0] = address(parameters[0].pool);

        skip(7 days + 1);

        vm.startPrank(CORE_OPERATOR);

        farmOperator.compound(
            IVeloDeployFactory(veloDeployFactoryAddress),
            poolAddresses
        );

        vm.stopPrank();
    }
}
