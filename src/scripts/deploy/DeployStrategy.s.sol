// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "./optimism/Constants.sol";

contract DeployStrategy is Script, Test, PoolParameters, Addresses {
    //IVeloDeployFactory immutable private deployFactory;

    function run() public virtual {
        vm.startBroadcast(deployerPrivateKey);

        //  deployAllStrategies(deployFactory);

        vm.stopBroadcast();
    }

    function deployAllStrategies(IVeloDeployFactory deployFactory) internal {
        for (uint256 i = 0; i < parameters.length; i++) {
            deployStrategy(deployFactory, parameters[i]);
        }
    }

    function deployStrategy(
        IVeloDeployFactory deployFactory,
        IVeloDeployFactory.DeployParams memory deployParams
    ) public returns (IVeloDeployFactory.PoolAddresses memory addresses) {
        ICLPool pool = deployParams.pool;
        VeloDeployFactory.ImmutableParams memory immutableParams =
            deployFactory.getImmutableParams();
        IVeloFactoryDeposit factoryDeposit = immutableParams.factoryDeposit;

        if (deployFactory.poolToAddresses(address(pool)).lpWrapper != address(0)) {
            deployFactory.removeAddressesForPool(address(pool));
        }

        IERC20(pool.token0()).approve(address(factoryDeposit), type(uint256).max);
        IERC20(pool.token1()).approve(address(factoryDeposit), type(uint256).max);

        addresses = deployFactory.createStrategy(deployParams);

        print(deployFactory, pool);
    }

    function print(IVeloDeployFactory deployFactory, ICLPool pool) internal view {
        IVeloDeployFactory.PoolAddresses memory poolAddresses =
            deployFactory.poolToAddresses(address(pool));

        IVeloDeployFactory.ImmutableParams memory immutableParams =
            deployFactory.getImmutableParams();
        ICore core = immutableParams.core;
        IVeloDeployFactoryHelper deployFactoryHelper = immutableParams.helper;

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
                deployFactory,
                address(pool)
            );
            console2.log(" lpWrapper symbol:", ERC20(poolAddresses.lpWrapper).symbol());
            console2.logBytes(createCalldata);
        }
        console2.log("    synthetixFarm:", poolAddresses.synthetixFarm);
    }
}
