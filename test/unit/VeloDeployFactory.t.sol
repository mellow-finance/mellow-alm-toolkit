// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    ICLPool public pool =
        ICLPool(factory.getPool(Constants.OPTIMISM_OP, Constants.OPTIMISM_WETH, 200));

    IERC20 token0 = IERC20(pool.token0());
    IERC20 token1 = IERC20(pool.token1());
    int24 tickSpacing = pool.tickSpacing();

    function testConstructor() external {
        vm.expectRevert();
        new VeloDeployFactory(
            address(0), ICore(address(0)), IPulseStrategyModule(address(0)), address(0)
        );

        DeployScript.CoreDeployment memory contracts = deployContracts();
        VeloDeployFactory factory;

        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        factory = new VeloDeployFactory(
            address(0),
            contracts.core,
            contracts.strategyModule,
            address(contracts.lpWrapperImplementation)
        );

        vm.expectRevert();
        factory = new VeloDeployFactory(
            Constants.OPTIMISM_DEPLOYER,
            ICore(address(0)),
            contracts.strategyModule,
            address(contracts.lpWrapperImplementation)
        );

        factory = new VeloDeployFactory(
            Constants.OPTIMISM_DEPLOYER,
            contracts.core,
            contracts.strategyModule,
            address(contracts.lpWrapperImplementation)
        );
    }

    function testRemoveWrapperForPool() public {
        DeployScript.CoreDeployment memory contracts = deployContracts();

        vm.prank(params.mellowAdmin);
        contracts.deployFactory.removeWrapperForPool(address(pool));
        assertTrue(contracts.deployFactory.poolToWrapper(address(pool)) == address(0));

        (ILpWrapper lpWrapper,) = deployLpWrapper(pool, contracts);

        assertTrue(address(lpWrapper) != address(0));
        assertTrue(contracts.deployFactory.poolToWrapper(address(pool)) == address(lpWrapper));

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        contracts.deployFactory.removeWrapperForPool(address(pool));

        vm.prank(params.mellowAdmin);
        contracts.deployFactory.removeWrapperForPool(address(pool));
        assertTrue(contracts.deployFactory.poolToWrapper(address(pool)) == address(0));
    }

    function testSetLpWrapperAdmin() public {
        DeployScript.CoreDeployment memory contracts = deployContracts();

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        contracts.deployFactory.setLpWrapperAdmin(address(1234));

        vm.startPrank(params.mellowAdmin);
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        contracts.deployFactory.setLpWrapperAdmin(address(0));

        contracts.deployFactory.setLpWrapperAdmin(address(1234));
        assertTrue(contracts.deployFactory.lpWrapperAdmin() == address(1234));
    }

    function testSetMinInitialTotalSupply() public {
        DeployScript.CoreDeployment memory contracts = deployContracts();

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        contracts.deployFactory.setMinInitialTotalSupply(123);

        vm.startPrank(params.mellowAdmin);
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        contracts.deployFactory.setMinInitialTotalSupply(0);

        vm.startPrank(params.mellowAdmin);
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        contracts.deployFactory.setMinInitialTotalSupply(1 ether + 1);

        contracts.deployFactory.setMinInitialTotalSupply(10 ** 18);
        assertTrue(contracts.deployFactory.minInitialTotalSupply() == 10 ** 18);
    }

    function testCreateStrategyRevert() public {
        DeployScript.CoreDeployment memory contracts = deployContracts();

        ICLPool poolBad =
            ICLPool(address(new CLPoolMock(pool.token0(), pool.token1(), pool.tickSpacing())));

        IVeloDeployFactory.DeployParams memory deployParams;
        deployParams.slippageD9 = 1e6;
        deployParams.strategyParams = IPulseStrategyModule.StrategyParams({
            strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
            tickNeighborhood: 0, // Neighborhood of ticks to consider for rebalancing
            tickSpacing: poolBad.tickSpacing(), // tickSpacing of the corresponding amm pool
            width: poolBad.tickSpacing() * 10, // Width of the interval
            maxLiquidityRatioDeviationX96: 0 // The maximum allowed deviation of the liquidity ratio for lower position.
        });

        deployParams.securityParams =
            IVeloOracle.SecurityParams({lookback: 100, maxAge: 5 days, maxAllowedDelta: 10});

        deployParams.pool = poolBad;
        deployParams.maxAmount0 = 1000 wei;
        deployParams.maxAmount1 = 1000 wei;
        deployParams.initialTotalSupply = 1000 wei;
        deployParams.totalSupplyLimit = 1000 ether;

        vm.startPrank(params.factoryOperator);
        deal(poolBad.token0(), address(contracts.deployFactory), 1 ether);
        deal(poolBad.token1(), address(contracts.deployFactory), 1 ether);

        vm.expectRevert(abi.encodeWithSignature("ForbiddenPool()"));
        contracts.deployFactory.createStrategy(deployParams);

        deployParams.pool = pool;
        deployParams.strategyParams.width = pool.tickSpacing() * 10;
        deployParams.strategyParams.tickSpacing = pool.tickSpacing() / 2;
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        contracts.deployFactory.createStrategy(deployParams);
    }

    function testCreateStrategy() public {
        DeployScript.CoreDeployment memory contracts = deployContracts();

        (ILpWrapper lpWrapper, IVeloDeployFactory.DeployParams memory deployParams) =
            deployLpWrapper(pool, contracts);
        assertFalse(address(lpWrapper) == address(0));
        assertEq(contracts.core.positionCount(), 1);

        ICore.ManagedPositionInfo memory postition = contracts.core.managedPositionAt(0);
        assertEq(postition.slippageD9, deployParams.slippageD9);
        assertEq(postition.property, uint24(tickSpacing));
        assertEq(postition.owner, address(lpWrapper));
        assertEq(postition.pool, address(pool));

        IAmmModule.AmmPosition memory ammPosition =
            contracts.core.ammModule().getAmmPosition(postition.ammPositionIds[0]);
        assertEq(ammPosition.token0, address(token0));
        assertEq(ammPosition.token1, address(token1));
        assertEq(ammPosition.property, uint24(tickSpacing));
        assertEq(ammPosition.tickUpper - ammPosition.tickLower, deployParams.strategyParams.width);
        assertTrue(ammPosition.liquidity > 0);

        IPulseStrategyModule.StrategyParams memory strategyParams =
            abi.decode(postition.strategyParams, (IPulseStrategyModule.StrategyParams));
        assertEq(
            uint256(strategyParams.strategyType), uint256(deployParams.strategyParams.strategyType)
        );
        assertEq(strategyParams.tickNeighborhood, deployParams.strategyParams.tickNeighborhood);
        assertEq(strategyParams.tickSpacing, tickSpacing);
        assertEq(strategyParams.width, deployParams.strategyParams.width);
        assertEq(
            strategyParams.maxLiquidityRatioDeviationX96,
            deployParams.strategyParams.maxLiquidityRatioDeviationX96
        );

        IVeloAmmModule.CallbackParams memory callbackParams =
            abi.decode(postition.callbackParams, (IVeloAmmModule.CallbackParams));
        assertEq(callbackParams.gauge, address(pool.gauge()));

        IVeloOracle.SecurityParams memory securityParams =
            abi.decode(postition.securityParams, (IVeloOracle.SecurityParams));
        assertEq(securityParams.lookback, deployParams.securityParams.lookback);
        assertEq(securityParams.maxAllowedDelta, deployParams.securityParams.maxAllowedDelta);
        assertEq(securityParams.maxAge, deployParams.securityParams.maxAge);
    }

    function testCreateStrategyTamper() public {
        DeployScript.CoreDeployment memory contracts = deployContracts();

        IVeloDeployFactory.DeployParams memory deployParams;
        deployParams.slippageD9 = 1e6;
        deployParams.strategyParams = IPulseStrategyModule.StrategyParams({
            strategyType: IPulseStrategyModule.StrategyType.Tamper,
            tickNeighborhood: 0, // Neighborhood of ticks to consider for rebalancing
            tickSpacing: pool.tickSpacing(), // tickSpacing of the corresponding amm pool
            width: pool.tickSpacing() * 10, // Width of the interval
            maxLiquidityRatioDeviationX96: Q96 / 2 // The maximum allowed deviation of the liquidity ratio for lower position.
        });

        deployParams.securityParams =
            IVeloOracle.SecurityParams({lookback: 100, maxAge: 5 days, maxAllowedDelta: 10});

        deployParams.pool = pool;
        deployParams.maxAmount0 = 100 ether;
        deployParams.maxAmount1 = 1 ether;
        deployParams.initialTotalSupply = 1000 wei;
        deployParams.totalSupplyLimit = 1000 ether;

        deal(pool.token0(), params.factoryOperator, 100 ether);
        deal(pool.token1(), params.factoryOperator, 1 ether);
        deal(pool.token0(), address(contracts.deployFactory), 1 ether);
        deal(pool.token1(), address(contracts.deployFactory), 1 ether);

        vm.startPrank(params.factoryOperator);
        IERC20(pool.token0()).approve(address(contracts.deployFactory), 100 ether);
        IERC20(pool.token1()).approve(address(contracts.deployFactory), 1 ether);
        contracts.deployFactory.createStrategy(deployParams);

        ICore.ManagedPositionInfo memory postition = contracts.core.managedPositionAt(0);
        assertEq(postition.ammPositionIds.length, 2);
        (uint160 sqrtPriceX96, int24 tick,,,,) = pool.slot0();

        IAmmModule.AmmPosition[] memory positions = new IAmmModule.AmmPosition[](2);
        positions[0] = contracts.ammModule.getAmmPosition(postition.ammPositionIds[0]);
        positions[1] = contracts.ammModule.getAmmPosition(postition.ammPositionIds[1]);

        (bool isRebalanceRequired,) = contracts.strategyModule.calculateTargetTamper(
            sqrtPriceX96, tick, positions, deployParams.strategyParams
        );

        assertEq(isRebalanceRequired, false);
    }
}
