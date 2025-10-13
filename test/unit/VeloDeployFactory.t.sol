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
        vm.expectRevert(IVeloDeployFactory.AddressZero.selector);
        new VeloDeployFactory(
            ICore(address(0)), IPulseStrategyModule(address(0)), address(0), address(0)
        );

        DeployScript.CoreDeployment memory contracts = deployContracts();
        VeloDeployFactory factory;

        vm.expectRevert(IVeloDeployFactory.AddressZero.selector);
        factory = new VeloDeployFactory(
            ICore(address(0)),
            contracts.strategyModule,
            address(contracts.lpWrapperImplementation),
            address(contracts.lpStakerImplementation)
        );

        vm.expectRevert(IVeloDeployFactory.AddressZero.selector);
        factory = new VeloDeployFactory(
            contracts.core,
            IPulseStrategyModule(address(0)),
            address(contracts.lpWrapperImplementation),
            address(contracts.lpStakerImplementation)
        );

        vm.expectRevert(IVeloDeployFactory.AddressZero.selector);
        factory = new VeloDeployFactory(
            contracts.core,
            contracts.strategyModule,
            address(0),
            address(contracts.lpStakerImplementation)
        );

        vm.expectRevert(IVeloDeployFactory.AddressZero.selector);
        factory = new VeloDeployFactory(
            contracts.core,
            contracts.strategyModule,
            address(contracts.lpWrapperImplementation),
            address(0)
        );
        /* 
        vm.expectRevert(IVeloDeployFactory.AddressZero.selector);
        factory.initialize(
            address(0),
            params.factoryOperator,
            params.factoryProposer,
            params.lpWrapperAdmin,
            params.lpWrapperManager,
            params.lpWrapperOperator,
            params.minInitialTotalSupply
        );
        
        vm.expectRevert(IVeloDeployFactory.AddressZero.selector);
        factory.initialize(
            params.mellowAdmin,
            address(0),
            params.factoryProposer,
            params.lpWrapperAdmin,
            params.lpWrapperManager,
            params.lpWrapperOperator,
            params.minInitialTotalSupply
        );

        vm.expectRevert(IVeloDeployFactory.AddressZero.selector);
        factory.initialize(
            params.mellowAdmin,
            params.factoryOperator,
            address(0),
            params.lpWrapperAdmin,
            params.lpWrapperManager,
            params.lpWrapperOperator,
            params.minInitialTotalSupply
        );

        vm.expectRevert(IVeloDeployFactory.AddressZero.selector);
        factory.initialize(
            params.mellowAdmin,
            params.factoryOperator,
            params.factoryProposer,
            address(0),
            params.lpWrapperManager,
            params.lpWrapperOperator,
            params.minInitialTotalSupply
        );

        vm.expectRevert(IVeloDeployFactory.AddressZero.selector);
        factory.initialize(
            params.mellowAdmin,
            params.factoryOperator,
            params.factoryProposer,
            params.lpWrapperAdmin,
            address(0),
            params.lpWrapperOperator,
            params.minInitialTotalSupply
        );

        vm.expectRevert(IVeloDeployFactory.AddressZero.selector);
        factory.initialize(
            params.mellowAdmin,
            params.factoryOperator,
            params.factoryProposer,
            params.lpWrapperAdmin,
            params.lpWrapperManager,
            address(0),
            params.minInitialTotalSupply
        );

        vm.expectRevert(IVeloDeployFactory.InvalidTotalSupplyValue.selector);
        factory.initialize(
            params.mellowAdmin,
            params.factoryOperator,
            params.factoryProposer,
            params.lpWrapperAdmin,
            params.lpWrapperManager,
            params.lpWrapperOperator,
            0
        ); */
    }

    function testProposeStrategy() public {
        DeployScript.CoreDeployment memory contracts = deployContracts();
        IVeloDeployFactory factory = contracts.deployFactory;

        IVeloDeployFactory.DeployParams memory deployParams =
            getValidDeployParams(pool, IPulseStrategyModule.StrategyType.LazySyncing);

        vm.prank(params.factoryProposer);
        bytes32 proposalId = factory.proposeDeployParams(deployParams);

        assertTrue(
            proposalId == factory.deployParamsHash(deployParams), "Proposal ID does not match hash"
        );

        assertTrue(
            factory.isProposedDeployParams(deployParams), "Deployment parameters were not proposed"
        );
        assertFalse(
            factory.isAcceptedDeployParams(deployParams), "Deployment parameters were accepted"
        );

        IVeloDeployFactory.DeployParams memory proposedParams =
            factory.getDeployParamsById(proposalId);
        assertTrue(
            compareDeployParams(deployParams, proposedParams), "Proposed parameters do not match"
        );

        proposalId = factory.deployParamsHash(deployParams);

        vm.prank(params.factoryProposer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IVeloDeployFactory.DeployParamsAlreadyProposed.selector, proposalId
            )
        );
        proposalId = factory.proposeDeployParams(deployParams);

        /// @dev a bit change deploy params
        deployParams.slippageD9 *= 2;

        vm.prank(params.factoryProposer);
        proposalId = factory.proposeDeployParams(deployParams);

        assertTrue(
            factory.isProposedDeployParams(deployParams), "Deployment parameters were not proposed"
        );
        assertFalse(
            factory.isAcceptedDeployParams(deployParams), "Deployment parameters were accepted"
        );

        proposedParams = factory.getDeployParamsById(proposalId);
        assertTrue(
            compareDeployParams(deployParams, proposedParams), "Proposed parameters do not match"
        );
    }

    function testAcceptProposedStrategy() external {
        DeployScript.CoreDeployment memory contracts = deployContracts();
        IVeloDeployFactory factory = contracts.deployFactory;

        IVeloDeployFactory.DeployParams memory deployParams =
            getValidDeployParams(pool, IPulseStrategyModule.StrategyType.LazySyncing);

        vm.prank(params.factoryProposer);
        bytes32 proposalId = factory.proposeDeployParams(deployParams);

        assertTrue(
            factory.isProposedDeployParams(deployParams), "Deployment parameters were not proposed"
        );

        vm.startPrank(params.factoryManager);

        bytes32 invalidProposalId = keccak256("invalid");
        vm.expectRevert(
            abi.encodeWithSelector(
                IVeloDeployFactory.DeployParamsNotProposed.selector, invalidProposalId
            )
        );
        factory.acceptDeployParams(invalidProposalId);

        factory.acceptDeployParams(proposalId);

        vm.expectRevert(
            abi.encodeWithSelector(
                IVeloDeployFactory.DeployParamsAlreadyAccepted.selector, proposalId
            )
        );
        factory.acceptDeployParams(proposalId);

        assertTrue(
            factory.isAcceptedDeployParams(deployParams), "Deployment parameters were not accepted"
        );
        vm.stopPrank();
    }

    function testDeployStrategyReverts() external {
        DeployScript.CoreDeployment memory contracts = deployContracts();
        IVeloDeployFactory factory = contracts.deployFactory;

        IVeloDeployFactory.DeployParams memory deployParams =
            getValidDeployParams(pool, IPulseStrategyModule.StrategyType.LazySyncing);

        bytes32 invalidProposalId = keccak256("invalid");

        vm.expectRevert(
            abi.encodeWithSelector(
                IVeloDeployFactory.DeployParamsNotProposed.selector, invalidProposalId
            )
        );
        factory.deployStrategy(invalidProposalId);

        vm.prank(params.factoryProposer);
        bytes32 proposalId = factory.proposeDeployParams(deployParams);

        assertTrue(
            factory.isProposedDeployParams(deployParams), "Deployment parameters were not proposed"
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IVeloDeployFactory.DeployParamsNotProposed.selector, invalidProposalId
            )
        );
        factory.deployStrategy(invalidProposalId);

        vm.expectRevert(
            abi.encodeWithSelector(IVeloDeployFactory.DeployParamsNotAccepted.selector, proposalId)
        );
        factory.deployStrategy(proposalId);

        vm.startPrank(params.factoryManager);
        factory.acceptDeployParams(proposalId);

        assertTrue(
            factory.isAcceptedDeployParams(deployParams), "Deployment parameters were not accepted"
        );

        deal(pool.token0(), address(contracts.deployFactory), deployParams.maxAmount0);
        deal(pool.token1(), address(contracts.deployFactory), deployParams.maxAmount1);
        IERC20(pool.token0()).approve(address(factory), deployParams.maxAmount0);
        IERC20(pool.token1()).approve(address(factory), deployParams.maxAmount1);
        ILpWrapper lpWrapper = factory.deployStrategy(proposalId);

        vm.expectRevert(
            abi.encodeWithSelector(
                IVeloDeployFactory.DeployParamsAlreadyDeployed.selector,
                proposalId,
                address(lpWrapper)
            )
        );
        factory.deployStrategy(proposalId);

        factory.deployParamsHash(deployParams);
        assertTrue(
            factory.isDeployedDeployParams(deployParams), "Deployment parameters were not deployed"
        );

        vm.stopPrank();
    }

    function testSetLpWrapperAdmin() public {
        DeployScript.CoreDeployment memory contracts = deployContracts();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                contracts.deployFactory.MANAGER_ROLE()
            )
        );
        contracts.deployFactory.setLpWrapperAdmin(address(1234));

        vm.startPrank(params.factoryManager);
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        contracts.deployFactory.setLpWrapperAdmin(address(0));

        contracts.deployFactory.setLpWrapperAdmin(address(1234));
        assertTrue(contracts.deployFactory.lpWrapperAdmin() == address(1234));
    }

    function testSetMinInitialTotalSupply() public {
        DeployScript.CoreDeployment memory contracts = deployContracts();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                contracts.deployFactory.MANAGER_ROLE()
            )
        );
        contracts.deployFactory.setMinInitialTotalSupply(123);

        vm.startPrank(params.factoryManager);
        vm.expectRevert(IVeloDeployFactory.InvalidTotalSupplyValue.selector);
        contracts.deployFactory.setMinInitialTotalSupply(0);

        vm.expectRevert(IVeloDeployFactory.InvalidTotalSupplyValue.selector);
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
            priceOracle: address(0), // The address of the custom price oracle used for market data
            maxLiquidityRatioDeviationX96: 0 // The maximum allowed deviation of the liquidity ratio for lower position.
        });

        deployParams.securityParams = IVeloOracle.SecurityParams({
            lookback: 100,
            maxAge: 5 days,
            maxAllowedDelta: 10,
            extraData: ""
        });

        deployParams.pool = address(poolBad);
        deployParams.maxAmount0 = 1000 wei;
        deployParams.maxAmount1 = 1000 wei;
        deployParams.initialTotalSupply = 1000 wei;
        deployParams.totalSupplyLimit = 1000 ether;

        {
            vm.prank(params.factoryProposer);
            vm.expectRevert(IVeloDeployFactory.ForbiddenPool.selector);
            bytes32 proposalId = contracts.deployFactory.proposeDeployParams(deployParams);

            vm.startPrank(params.factoryManager);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IVeloDeployFactory.DeployParamsNotProposed.selector, proposalId
                )
            );
            contracts.deployFactory.acceptDeployParams(proposalId);

            vm.expectRevert(
                abi.encodeWithSelector(
                    IVeloDeployFactory.DeployParamsNotProposed.selector, proposalId
                )
            );
            contracts.deployFactory.deployStrategy(proposalId);
            vm.stopPrank();
        }
        {
            deployParams.pool = address(pool);
            deployParams.strategyParams.width = pool.tickSpacing() * 10;
            deployParams.strategyParams.tickSpacing = pool.tickSpacing() / 2;

            vm.prank(params.factoryProposer);
            vm.expectRevert(IVeloDeployFactory.InvalidDeployParams.selector);
            bytes32 proposalId = contracts.deployFactory.proposeDeployParams(deployParams);

            vm.expectRevert(
                abi.encodeWithSelector(
                    IVeloDeployFactory.DeployParamsNotProposed.selector, proposalId
                )
            );
            contracts.deployFactory.deployStrategy(proposalId);
        }
    }

    function testCreateStrategy() public {
        DeployScript.CoreDeployment memory contracts = deployContracts();

        (ILpWrapper lpWrapper, IVeloDeployFactory.DeployParams memory deployParams) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.LazySyncing, contracts);
        assertFalse(address(lpWrapper) == address(0));
        assertEq(contracts.core.positionCount(), 1);

        ICore.ManagedPositionInfo memory position = contracts.core.managedPositionAt(0);
        assertEq(position.slippageD9, deployParams.slippageD9);
        assertEq(position.property, uint24(tickSpacing));
        assertEq(position.owner, address(lpWrapper));
        assertEq(position.pool, address(pool));

        IAmmModule.AmmPosition memory ammPosition =
            contracts.core.ammModule().getAmmPosition(position.ammPositionIds[0]);
        assertEq(ammPosition.token0, address(token0));
        assertEq(ammPosition.token1, address(token1));
        assertEq(ammPosition.property, uint24(tickSpacing));
        assertEq(ammPosition.tickUpper - ammPosition.tickLower, deployParams.strategyParams.width);
        assertTrue(ammPosition.liquidity > 0);

        IPulseStrategyModule.StrategyParams memory strategyParams =
            abi.decode(position.strategyParams, (IPulseStrategyModule.StrategyParams));
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
            abi.decode(position.callbackParams, (IVeloAmmModule.CallbackParams));
        assertEq(callbackParams.gauge, address(pool.gauge()));

        IVeloOracle.SecurityParams memory securityParams =
            abi.decode(position.securityParams, (IVeloOracle.SecurityParams));
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
            priceOracle: address(0), // The address of the custom price oracle used for market data
            maxLiquidityRatioDeviationX96: Q96 / 2 // The maximum allowed deviation of the liquidity ratio for lower position.
        });

        deployParams.securityParams = IVeloOracle.SecurityParams({
            lookback: 100,
            maxAge: 5 days,
            maxAllowedDelta: 10,
            extraData: ""
        });

        deployParams.pool = address(pool);
        deployParams.maxAmount0 = 100 ether;
        deployParams.maxAmount1 = 1 ether;
        deployParams.initialTotalSupply = 1000 wei;
        deployParams.totalSupplyLimit = 1000 ether;

        deal(pool.token0(), address(this), 100 ether);
        deal(pool.token1(), address(this), 1 ether);
        deal(pool.token0(), address(contracts.deployFactory), 1 ether);
        deal(pool.token1(), address(contracts.deployFactory), 1 ether);

        vm.startPrank(params.factoryProposer);
        bytes32 proposalId = contracts.deployFactory.proposeDeployParams(deployParams);

        IERC20(pool.token0()).approve(address(contracts.deployFactory), 100 ether);
        IERC20(pool.token1()).approve(address(contracts.deployFactory), 1 ether);

        vm.startPrank(params.factoryManager);
        contracts.deployFactory.acceptDeployParams(proposalId);

        contracts.deployFactory.deployStrategy(proposalId);

        ICore.ManagedPositionInfo memory position = contracts.core.managedPositionAt(0);
        assertEq(position.ammPositionIds.length, 2);
        (uint160 sqrtPriceX96, int24 tick,,,,) = pool.slot0();

        IAmmModule.AmmPosition[] memory positions = new IAmmModule.AmmPosition[](2);
        positions[0] = contracts.ammModule.getAmmPosition(position.ammPositionIds[0]);
        positions[1] = contracts.ammModule.getAmmPosition(position.ammPositionIds[1]);

        (bool isRebalanceRequired,) = contracts.strategyModule.calculateTargetTamper(
            sqrtPriceX96, tick, positions, deployParams.strategyParams
        );

        assertEq(isRebalanceRequired, false);
    }

    function testManyLpWrappers() public {
        DeployScript.CoreDeployment memory contracts = deployContracts();
        IVeloDeployFactory factory = contracts.deployFactory;
        IVeloDeployFactory.DeployParams memory deployParams =
            getValidDeployParams(pool, IPulseStrategyModule.StrategyType.LazySyncing);

        assertTrue(factory.poolToWrappers(address(pool)).length == 0);

        address[] memory lpWrappers = new address[](5);
        for (uint256 index = 0; index < lpWrappers.length; index++) {
            vm.prank(params.factoryProposer);
            bytes32 proposalId = factory.proposeDeployParams(deployParams);

            vm.startPrank(params.factoryManager);
            factory.acceptDeployParams(proposalId);

            deal(pool.token0(), address(contracts.deployFactory), deployParams.maxAmount0);
            deal(pool.token1(), address(contracts.deployFactory), deployParams.maxAmount1);
            IERC20(pool.token0()).approve(address(factory), deployParams.maxAmount0);
            IERC20(pool.token1()).approve(address(factory), deployParams.maxAmount1);
            lpWrappers[index] = address(factory.deployStrategy(proposalId));
            vm.stopPrank();

            assertTrue(factory.poolToWrappers(address(pool)).length == index + 1);
            assertTrue(factory.isEntity(lpWrappers[index]));
            assertTrue(factory.isEntity(lpWrappers[index], address(pool)));

            /// @dev a bit change params to have new entity
            deployParams.slippageD9 += 1;
        }
    }

    function testDeployLpStaker() public {
        DeployScript.CoreDeployment memory contracts = deployContracts();
        IVeloDeployFactory factory = contracts.deployFactory;
        IVeloDeployFactory.LpStakerParams memory lpStakerParams =
            IVeloDeployFactory.LpStakerParams({timeLock: 1 days, minStakeAmount: 1 wei});

        address wrongLpWrapper = address(1234);
        vm.prank(params.factoryManager);
        vm.expectRevert(
            abi.encodeWithSelector(IVeloDeployFactory.LpWrapperNotExists.selector, wrongLpWrapper)
        );
        factory.approveLpStaker(wrongLpWrapper, lpStakerParams);
        vm.expectRevert(
            abi.encodeWithSelector(IVeloDeployFactory.LpWrapperNotExists.selector, wrongLpWrapper)
        );
        factory.deployStaker(wrongLpWrapper);

        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.LazySyncing, contracts);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                contracts.deployFactory.MANAGER_ROLE()
            )
        );
        factory.approveLpStaker(address(lpWrapper), lpStakerParams);

        vm.prank(params.factoryManager);
        factory.approveLpStaker(address(lpWrapper), lpStakerParams);

        vm.expectRevert(IVeloDeployFactory.LpStakerAlreadyApproved.selector);
        vm.prank(params.factoryManager);
        factory.approveLpStaker(address(lpWrapper), lpStakerParams);

        ILpStaker lpStaker = factory.deployStaker(address(lpWrapper));
        assertTrue(address(lpStaker) != address(0));
        assertTrue(lpStaker.lpWrapper() == lpWrapper);
        assertTrue(lpStaker.timeLock() == 1 days);

        vm.prank(params.factoryManager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IVeloDeployFactory.LpWrapperAlreadyHasStaker.selector,
                address(lpWrapper),
                address(lpStaker)
            )
        );
        factory.approveLpStaker(address(lpWrapper), lpStakerParams);

        vm.expectRevert(
            abi.encodeWithSelector(
                IVeloDeployFactory.LpWrapperAlreadyHasStaker.selector,
                address(lpWrapper),
                address(lpStaker)
            )
        );
        factory.deployStaker(address(lpWrapper));
        vm.stopPrank();
    }
}
