// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.25;

import "./base/Constants.sol";

contract DeployStrategy is Script, Test, PoolParameters, Addresses {
    function run() public virtual {
        vm.startBroadcast(deployerPrivateKey);

        //  deployAllStrategies();

        vm.stopBroadcast();
    }

    function deployCreateStrategyHelper(address veloDeployFactoryAddress) internal {
        VeloDeployFactory veloDeployFactory = VeloDeployFactory(veloDeployFactoryAddress);

        vm.startBroadcast(deployerPrivateKey);
        /*  CreateStrategyHelper createStrategyHelper = new CreateStrategyHelper(
            address(veloDeployFactory),
            vm.addr(deployerPrivateKey)
        );
        veloDeployFactory.grantRole(
            veloDeployFactory.ADMIN_DELEGATE_ROLE(),
            address(createStrategyHelper)
        );
        console2.log("createStrategyHelper", address(createStrategyHelper)); */
    }

    function withdraw(address lpWrapper, address to) private {
        /// @dev withdraw whole assets
        (uint256 amount0, uint256 amount1, uint256 actualLpAmount) = ILpWrapper(lpWrapper).withdraw(
            type(uint256).max, // it will be truncated to the actual owned lpTokens
            0,
            0,
            to,
            type(uint256).max
        );

        console2.log(" ================== withdraw info ==================== ");
        console2.log("withdrawer: ", to);
        console2.log("   amount0: ", amount0);
        console2.log("   amount1: ", amount1);
        console2.log("  lpAmount: ", actualLpAmount);
    }
    /* 
    function deployAllStrategies() internal {
        for (uint i = 0; i < parameters.length; i++) {
            deployStrategy(
                address(deployFactory),
                address(createStrategyHelper),
                i
            );
        }
    }

    function deployStrategy(
        address veloDeployFactoryAddress,
        address createStrategyHelperAddress,
        uint256 poolId
    ) internal {
        IVeloDeployFactory veloDeployFactory = IVeloDeployFactory(
            veloDeployFactoryAddress
        );
        CreateStrategyHelper createStrategyHelper = CreateStrategyHelper(
            createStrategyHelperAddress
        );

        address operatorAddress = vm.addr(operatorPrivateKey);

        address lpWrapper = veloDeployFactory
            .poolToAddresses(address(parameters[poolId].pool))
            .lpWrapper;
        address synthetixFarm = veloDeployFactory
            .poolToAddresses(address(parameters[poolId].pool))
            .synthetixFarm;
        if (lpWrapper != address(0)) {
            withdraw(lpWrapper, operatorAddress);
        }

        if (lpWrapper != address(0) || synthetixFarm != address(0)) {
            veloDeployFactory.removeAddressesForPool(
                address(parameters[poolId].pool)
            );
        }

        require(
            parameters[poolId].width % parameters[poolId].pool.tickSpacing() ==
                0,
            "POOL_POSITION_WIDTH is not valid"
        );

        IERC20(parameters[poolId].pool.token0()).approve(
            address(createStrategyHelper),
            type(uint256).max
        );
        IERC20(parameters[poolId].pool.token1()).approve(
            address(createStrategyHelper),
            type(uint256).max
        );

        (
            IVeloDeployFactory.PoolAddresses memory poolAddresses,

        ) = createStrategyHelper.createStrategy(parameters[poolId]);

        // print(poolAddresses, address(parameters[poolId].pool));
    }
    */

    function print(
        ICore core,
        address veloDeployFactoryHelper,
        address veloDeployFactory,
        address pool,
        IVeloDeployFactory.PoolAddresses memory poolAddresses
    ) internal view {
        console2.log(" =======     POOL ", address(pool), "    ========");

        console2.log("        lpWrapper:", poolAddresses.lpWrapper);
        console2.log("   lpWrapper name:", ERC20(poolAddresses.lpWrapper).name());

        {
            bytes memory createCalldata = abi.encode(
                address(core),
                address(core.ammModule()),
                ERC20(poolAddresses.lpWrapper).name(),
                ERC20(poolAddresses.lpWrapper).symbol(),
                veloDeployFactoryHelper,
                Constants.WETH,
                veloDeployFactory,
                address(pool)
            );
            console2.log(" lpWrapper symbol:", ERC20(poolAddresses.lpWrapper).symbol());
            console2.logBytes(createCalldata);
        }
        console2.log("    synthetixFarm:", poolAddresses.synthetixFarm);
    }
}
