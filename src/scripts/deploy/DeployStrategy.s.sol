// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "./optimism/Constants.sol";

contract DeployStrategy is Script, Test, PoolParameters, Addresses {
    ICore private core;
    IVeloDeployFactoryHelper private deployFactoryHelper;
    IVeloFactoryDeposit private factoryDeposit;

    function run() public virtual {
        IVeloDeployFactory.ImmutableParams memory immutableParams =
            deployFactory.getImmutableParams();
        core = immutableParams.core;
        deployFactoryHelper = immutableParams.helper;
        factoryDeposit = immutableParams.factoryDeposit;

        vm.startBroadcast(deployerPrivateKey);

        //  deployAllStrategies(deployFactory);

        vm.stopBroadcast();
    }

    function deployAllStrategies(IVeloDeployFactory veloFactory) internal {
        for (uint256 i = 0; i < parameters.length; i++) {
            deployStrategy(veloFactory, parameters[i]);
        }
    }

    function deployStrategy(
        IVeloDeployFactory veloFactory,
        IVeloDeployFactory.DeployParams memory deployParams
    ) public returns (IVeloDeployFactory.PoolAddresses memory addresses) {}

    function print(IVeloDeployFactory veloFactory, ICLPool pool) internal view {
        IVeloDeployFactory.PoolAddresses memory poolAddresses =
            veloFactory.poolToAddresses(address(pool));

        console2.log(" =======     POOL ", address(pool), "    ========");

        console2.log("        lpWrapper:", poolAddresses.lpWrapper);
        console2.log("   lpWrapper name:", ERC20(poolAddresses.lpWrapper).name());

        {
            bytes memory createCalldata = abi.encode(
                address(core),
                address(core.ammModule()),
                ERC20(poolAddresses.lpWrapper).name(),
                ERC20(poolAddresses.lpWrapper).symbol(),
                deployFactoryHelper,
                Constants.WETH,
                veloFactory,
                address(pool)
            );
            console2.log(" lpWrapper symbol:", ERC20(poolAddresses.lpWrapper).symbol());
            console2.logBytes(createCalldata);
        }
        console2.log("    synthetixFarm:", poolAddresses.synthetixFarm);
    }
}
