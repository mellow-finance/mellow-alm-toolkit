// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "src/scripts/deploy/optimism/DeployStrategy.s.sol";
import "src/scripts/deploy/optimism/DeployVeloLazy.s.sol";

contract DeployCoreAndStrategyTest is Test, DeployStrategy, DeployVeloLazy {

    address immutable deployer = 0xeccba048Fd1fcD5c26f3aAfb7aBf3737e163d0FD;

    function run() public override (DeployStrategy, DeployVeloLazy) {}

    function testDeploy() public {

        vm.startPrank(deployer);

        CreateStrategyHelper.PoolParameter[] memory parameters = setPoolParameters();

        (address veloDeployFactoryAddress, address createStrategyHelperAddress) = deployCore();

        IVeloDeployFactory.MutableParams memory params = IVeloDeployFactory(veloDeployFactoryAddress).getMutableParams();

        Compounder farmOperator = Compounder(params.farmOperator);

        deployStrategy(veloDeployFactoryAddress, createStrategyHelperAddress, 0);

        address[] memory poolAddresses = new address[](1);

        poolAddresses[0] = address(parameters[0].pool);

        vm.warp(block.timestamp + 7 days + 1);

        farmOperator.compound(IVeloDeployFactory(veloDeployFactoryAddress), poolAddresses);
    }
}