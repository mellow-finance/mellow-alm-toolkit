// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
    DeployScript.CoreDeployment contracts;
    ILpWrapper lpWrapper;
    IVeloDeployFactory.DeployParams deployParams;

    function setUp() external {
        contracts = deployContracts();
        (lpWrapper, deployParams) = deployLpWrapper(pool, contracts);
    }

    function testContructor() external {
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        Core core = new Core(
            contracts.ammModule,
            contracts.depositWithdrawModule,
            contracts.strategyModule,
            contracts.oracle,
            address(0),
            Constants.OPTIMISM_WETH
        );

        core = new Core(
            contracts.ammModule,
            contracts.depositWithdrawModule,
            contracts.strategyModule,
            contracts.oracle,
            Constants.OPTIMISM_DEPLOYER,
            Constants.OPTIMISM_WETH
        );

        assertTrue(address(contracts.core) != address(0));
    }

    function testCollectRewards() public {
        ICore core = contracts.core;

        uint256 positionId = 0;
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        core.collectRewards(positionId);

        vm.prank(info.owner);
        core.collectRewards(positionId);
    }

    function testDirectDeposit() public {
        ICore core = contracts.core;
        uint256 positionId = 0;
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);
        uint256 tokenId = info.ammPositionIds[0];

        deal(pool.token0(), info.owner, 10 ether);
        deal(pool.token1(), info.owner, 10 ether);

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        core.directDeposit(positionId, tokenId, 1 ether, 1 ether);

        vm.startPrank(info.owner);

        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        core.directDeposit(positionId, tokenId + 1, 1 ether, 1 ether);

        IERC20(pool.token0()).approve(address(core), 1 ether);
        IERC20(pool.token1()).approve(address(core), 1 ether);

        core.directDeposit(positionId, tokenId, 1 ether, 1 ether);
    }

    function testDirectDepositWithdrawRevert() public {
        VeloDepositWithdrawModuleMock module = new VeloDepositWithdrawModuleMock(positionManager);
        uint256 specificValueRevert = module.specificValueRevert();

        ICore coreBroken = new Core(
            contracts.ammModule,
            IVeloDepositWithdrawModule(address(module)),
            contracts.strategyModule,
            contracts.oracle,
            Constants.OPTIMISM_DEPLOYER,
            Constants.OPTIMISM_WETH
        );

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            1 ether,
            pool,
            Constants.OPTIMISM_DEPLOYER
        );

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);

        positionManager.approve(address(coreBroken), tokenId);

        coreBroken.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    treasury: Constants.OPTIMISM_MELLOW_TREASURY,
                    feeD9: Constants.OPTIMISM_FEE_D9
                })
            )
        );

        ICore.DepositParams memory depositParams;
        depositParams.slippageD9 = 1 * 1e5;
        depositParams.ammPositionIds = new uint256[](1);
        depositParams.owner = Constants.OPTIMISM_DEPLOYER;
        depositParams.callbackParams = abi.encode(
            IVeloAmmModule.CallbackParams({
                gauge: address(pool.gauge()),
                farm: address(new VeloFarmMock())
            })
        );

        depositParams.securityParams = abi.encode(
            IVeloOracle.SecurityParams({lookback: 100, maxAllowedDelta: 100, maxAge: 7 days})
        );
        depositParams.strategyParams = abi.encode(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.Original,
                width: 1000,
                tickSpacing: 200,
                tickNeighborhood: 100,
                maxLiquidityRatioDeviationX96: 0
            })
        );

        depositParams.ammPositionIds[0] = tokenId;
        coreBroken.deposit(depositParams);

        uint256 positionId = 0;
        ICore.ManagedPositionInfo memory info = coreBroken.managedPositionAt(positionId);
        uint256 tokenIdActual = info.ammPositionIds[0];
        assertEq(tokenIdActual, tokenId);

        deal(pool.token0(), Constants.OPTIMISM_DEPLOYER, 1 ether);
        deal(pool.token1(), Constants.OPTIMISM_DEPLOYER, 1 ether);
        IERC20(pool.token0()).approve(address(coreBroken), 1 ether);
        IERC20(pool.token1()).approve(address(coreBroken), 1 ether);

        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        coreBroken.directDeposit(positionId, tokenId, specificValueRevert, 1 ether);

        coreBroken.directDeposit(positionId, tokenId, 1 ether, 1 ether);

        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        coreBroken.directWithdraw(
            positionId, tokenId, specificValueRevert, Constants.OPTIMISM_DEPLOYER
        );

        coreBroken.directWithdraw(positionId, tokenId, 1 ether / 2, Constants.OPTIMISM_DEPLOYER);
    }

    function testDirectWithdraw() public {
        ICore core = contracts.core;
        uint256 positionId = 0;
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);
        uint256 tokenId = info.ammPositionIds[0];
        IVeloAmmModule.AmmPosition memory position = contracts.ammModule.getAmmPosition(tokenId);

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        core.directWithdraw(positionId, tokenId, position.liquidity, address(this));

        vm.startPrank(info.owner);

        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        core.directWithdraw(positionId, tokenId + 1, position.liquidity, address(this));

        vm.expectRevert(abi.encodeWithSignature("FailedCall()"));
        core.directWithdraw(positionId, tokenId, position.liquidity + 1, address(this));

        vm.expectRevert(bytes("NP"));
        core.directWithdraw(positionId, tokenId, position.liquidity, info.owner);

        core.directWithdraw(positionId, tokenId, position.liquidity / 2, info.owner);
    }

    function testRebalance() public {
        ICore core = contracts.core;
        ICore.RebalanceParams memory rebalanceParams;
        rebalanceParams.id = 0;
        rebalanceParams.callback = address(new RebalancingBot(positionManager));
        rebalanceParams.data = new bytes(0); // count of position, if empty - ignore

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        core.rebalance(rebalanceParams);

        vm.startPrank(params.mellowAdmin);
        vm.expectRevert(abi.encodeWithSignature("NoRebalanceNeeded()"));
        core.rebalance(rebalanceParams);
        vm.stopPrank();

        uint160 sqrtPriceX96;
        int24 tick;

        (sqrtPriceX96, tick,,,,) = pool.slot0();
        movePrice(pool, TickMath.getSqrtRatioAtTick(tick + 1000));

        vm.startPrank(params.mellowAdmin);
        vm.expectRevert(abi.encodeWithSignature("PriceManipulationDetected()"));
        core.rebalance(rebalanceParams);
        vm.stopPrank();

        //-------------------------------------------------------------------------------

        IVeloDeployFactory.DeployParams memory deployParams_;
        deployParams_.slippageD9 = 1e6;
        deployParams_.strategyParams = IPulseStrategyModule.StrategyParams({
            strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
            tickNeighborhood: 0, // Neighborhood of ticks to consider for rebalancing
            tickSpacing: pool.tickSpacing(), // tickSpacing of the corresponding amm pool
            width: pool.tickSpacing(), // Width of the interval
            maxLiquidityRatioDeviationX96: 0 // The maximum allowed deviation of the liquidity ratio for lower position.
        });

        deployParams_.securityParams =
            IVeloOracle.SecurityParams({lookback: 1, maxAge: 1 seconds, maxAllowedDelta: 1000});

        deployParams_.pool = pool;
        deployParams_.maxAmount0 = 100 ether;
        deployParams_.maxAmount1 = 1 ether;
        deployParams_.initialTotalSupply = 1000 wei;
        deployParams_.totalSupplyLimit = 1000 ether;

        deal(pool.token0(), params.factoryOperator, 100 ether);
        deal(pool.token1(), params.factoryOperator, 1 ether);
        deal(pool.token0(), address(contracts.deployFactory), 1 ether);
        deal(pool.token1(), address(contracts.deployFactory), 1 ether);

        vm.startPrank(params.factoryOperator);
        IERC20(pool.token0()).approve(address(contracts.deployFactory), 100 ether);
        IERC20(pool.token1()).approve(address(contracts.deployFactory), 1 ether);
        contracts.deployFactory.createStrategy(deployParams_);

        (sqrtPriceX96, tick,,,,) = pool.slot0();
        movePrice(pool, TickMath.getSqrtRatioAtTick(tick + 1000));

        rebalanceParams.id = 1;
        vm.startPrank(params.mellowAdmin);

        rebalanceParams.data = abi.encode(10);
        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.rebalance(rebalanceParams);

        rebalanceParams.data = new bytes(0x40);
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        core.rebalance(rebalanceParams);

        rebalanceParams.data = new bytes(0);
        core.rebalance(rebalanceParams);
        vm.stopPrank();
    }

    function testDeposit() external {
        Core core = new Core(
            contracts.ammModule,
            contracts.depositWithdrawModule,
            contracts.strategyModule,
            contracts.oracle,
            Constants.OPTIMISM_DEPLOYER,
            Constants.OPTIMISM_WETH
        );

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool,
            Constants.OPTIMISM_DEPLOYER
        );

        uint256 tokenId1 = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool,
            Constants.OPTIMISM_DEPLOYER
        );

        uint256 tokenId2 = mint(
            Constants.OPTIMISM_WETH,
            Constants.OPTIMISM_WSTETH,
            1,
            2,
            10000,
            pool,
            Constants.OPTIMISM_DEPLOYER
        );

        uint256 tokenIdEmpty = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool,
            Constants.OPTIMISM_DEPLOYER
        );

        IAmmModule.AmmPosition memory position = contracts.ammModule.getAmmPosition(tokenIdEmpty);
        vm.startPrank(positionManager.ownerOf(tokenIdEmpty));
        positionManager.approve(address(contracts.depositWithdrawModule), tokenIdEmpty);
        contracts.depositWithdrawModule.withdraw(
            tokenIdEmpty, position.liquidity, Constants.OPTIMISM_DEPLOYER
        );
        vm.stopPrank();
        position = contracts.ammModule.getAmmPosition(tokenIdEmpty);
        assertEq(position.liquidity, 0);

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);

        positionManager.approve(address(core), tokenId);
        positionManager.approve(address(core), tokenId1);
        positionManager.approve(address(core), tokenId2);
        positionManager.approve(address(core), tokenIdEmpty);

        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    treasury: Constants.OPTIMISM_MELLOW_TREASURY,
                    feeD9: Constants.OPTIMISM_FEE_D9
                })
            )
        );

        ICore.DepositParams memory depositParams;
        depositParams.ammPositionIds = new uint256[](1);
        depositParams.owner = Constants.OPTIMISM_DEPLOYER;
        depositParams.callbackParams = new bytes(123);

        depositParams.ammPositionIds[0] = tokenId;
        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.deposit(depositParams);

        depositParams.callbackParams = abi.encode(
            IVeloAmmModule.CallbackParams({gauge: address(pool.gauge()), farm: address(1)})
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.deposit(depositParams);

        depositParams.strategyParams = abi.encode(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.Original,
                width: 1000,
                tickSpacing: 200,
                tickNeighborhood: 100,
                maxLiquidityRatioDeviationX96: 0
            })
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        core.deposit(depositParams);

        depositParams.slippageD9 = 1 * 1e5;
        depositParams.securityParams = new bytes(123);

        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.deposit(depositParams);

        depositParams.securityParams = abi.encode(
            IVeloOracle.SecurityParams({lookback: 100, maxAllowedDelta: 100, maxAge: 7 days})
        );

        assertEq(positionManager.ownerOf(tokenId), Constants.OPTIMISM_DEPLOYER);

        depositParams.owner = address(0);
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        core.deposit(depositParams);

        depositParams.owner = Constants.OPTIMISM_DEPLOYER;

        depositParams.ammPositionIds[0] = 0;
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        core.deposit(depositParams);

        depositParams.ammPositionIds[0] = tokenIdEmpty;
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        core.deposit(depositParams);

        depositParams.ammPositionIds[0] = tokenId2;
        vm.expectRevert(bytes("PM"));
        core.deposit(depositParams);

        depositParams.ammPositionIds[0] = tokenId;
        core.deposit(depositParams);

        assertEq(positionManager.ownerOf(tokenId), address(pool.gauge()));

        depositParams.ammPositionIds = new uint256[](2);
        depositParams.ammPositionIds[0] = tokenId1;
        depositParams.ammPositionIds[1] = tokenId2;

        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        core.deposit(depositParams);

        vm.stopPrank();
    }

    function _depositToken(ICore core, uint256 tokenId) private returns (uint256 id) {
        address owner = positionManager.ownerOf(tokenId);

        vm.startPrank(owner);

        positionManager.approve(address(core), tokenId);

        ICore.DepositParams memory depositParams;
        depositParams.ammPositionIds = new uint256[](1);
        depositParams.ammPositionIds[0] = tokenId;
        depositParams.owner = owner;
        depositParams.callbackParams = abi.encode(
            IVeloAmmModule.CallbackParams({gauge: address(pool.gauge()), farm: address(lpWrapper)})
        );
        depositParams.strategyParams = abi.encode(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.Original,
                width: 1000,
                tickSpacing: 200,
                tickNeighborhood: 100,
                maxLiquidityRatioDeviationX96: 0
            })
        );
        depositParams.slippageD9 = 1 * 1e5;
        depositParams.securityParams = abi.encode(
            IVeloOracle.SecurityParams({lookback: 1, maxAllowedDelta: 100000, maxAge: 7 days})
        );

        id = core.deposit(depositParams);

        vm.stopPrank();
    }

    function testWithdraw() external {
        ICore core = contracts.core;

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool,
            Constants.OPTIMISM_DEPLOYER
        );
        uint256 positionId = _depositToken(contracts.core, tokenId);

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        core.withdraw(positionId, Constants.OPTIMISM_DEPLOYER);

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);

        assertEq(positionManager.ownerOf(tokenId), address(pool.gauge()));
        core.withdraw(positionId, Constants.OPTIMISM_DEPLOYER);
        assertEq(positionManager.ownerOf(tokenId), Constants.OPTIMISM_DEPLOYER);

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        core.withdraw(positionId, Constants.OPTIMISM_DEPLOYER);

        vm.stopPrank();
    }

    function testSetPositionParams() external {
        ICore core = contracts.core;

        uint256 positionId = _depositToken(
            core,
            mint(
                pool.token0(),
                pool.token1(),
                pool.tickSpacing(),
                pool.tickSpacing() * 2,
                10000,
                pool,
                Constants.OPTIMISM_DEPLOYER
            )
        );

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        core.setPositionParams(positionId, 0, new bytes(0), new bytes(0), new bytes(0));

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);
        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.setPositionParams(positionId, 1, new bytes(123), new bytes(0), new bytes(0));
        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.setPositionParams(positionId, 1, new bytes(0), new bytes(123), new bytes(0));

        bytes memory defaultStrategyParams = abi.encode(
            IPulseStrategyModule.StrategyParams({
                width: 200,
                tickSpacing: 100,
                tickNeighborhood: 100,
                strategyType: IPulseStrategyModule.StrategyType.Original,
                maxLiquidityRatioDeviationX96: 0
            })
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.setPositionParams(positionId, 1, new bytes(0), defaultStrategyParams, new bytes(123));

        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.setPositionParams(positionId, 0, new bytes(0), defaultStrategyParams, new bytes(0));

        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.setPositionParams(
            positionId, uint32(D9 / 20 + 1), new bytes(0), defaultStrategyParams, new bytes(0)
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.setPositionParams(
            positionId, uint32(D9 / 20), new bytes(0), defaultStrategyParams, new bytes(0)
        );

        bytes memory defaultCallbackParams = abi.encode(
            IVeloAmmModule.CallbackParams({farm: address(lpWrapper), gauge: address(pool.gauge())})
        );
        bytes memory defaultSecurityParams = abi.encode(
            IVeloOracle.SecurityParams({lookback: 100, maxAllowedDelta: 100, maxAge: 7 days})
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        core.setPositionParams(
            positionId,
            uint32(D9 / 4 + 1),
            defaultCallbackParams,
            defaultStrategyParams,
            defaultSecurityParams
        );

        core.setPositionParams(
            positionId,
            uint32(D9 / 4),
            defaultCallbackParams,
            defaultStrategyParams,
            defaultSecurityParams
        );
    }

    function testSetProtocolParams() external {
        ICore core = contracts.core;

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        core.setProtocolParams(new bytes(123));

        vm.startPrank(params.mellowAdmin);
        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.setProtocolParams(new bytes(123));

        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    treasury: address(0),
                    feeD9: Constants.OPTIMISM_FEE_D9
                })
            )
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidFee()"));
        core.setProtocolParams(
            abi.encode(IVeloAmmModule.ProtocolParams({treasury: address(1), feeD9: 3e8 + 1}))
        );

        bytes memory protocolParams = abi.encode(
            IVeloAmmModule.ProtocolParams({
                treasury: Constants.OPTIMISM_MELLOW_TREASURY,
                feeD9: Constants.OPTIMISM_FEE_D9
            })
        );

        core.setProtocolParams(protocolParams);

        assertEq(core.protocolParams(), protocolParams);
        vm.stopPrank();
    }

    function testPosition() external {
        ICore core = contracts.core;

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool,
            Constants.OPTIMISM_DEPLOYER
        );
        uint256 positionId = _depositToken(core, tokenId);

        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);

        assertEq(info.ammPositionIds.length, 1);
        assertEq(info.ammPositionIds[0], tokenId);

        assertEq(info.owner, Constants.OPTIMISM_DEPLOYER);
        assertEq(info.slippageD9, 1e5);
        assertTrue(info.strategyParams.length != 0);
        assertTrue(info.callbackParams.length != 0);
        assertTrue(info.securityParams.length != 0);

        assertEq(address(pool), info.pool);
        assertEq(uint24(pool.tickSpacing()), info.property);
    }

    function testPositionCount() external {
        ICore core = contracts.core;

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool,
            Constants.OPTIMISM_DEPLOYER
        );
        uint256[] memory ammPositionIds = new uint256[](1);
        ammPositionIds[0] = tokenId;
        ICore.DepositParams memory depositParams = ICore.DepositParams({
            ammPositionIds: ammPositionIds,
            owner: Constants.OPTIMISM_DEPLOYER,
            slippageD9: 1 * 1e5,
            callbackParams: abi.encode(
                IVeloAmmModule.CallbackParams({gauge: address(pool.gauge()), farm: address(lpWrapper)})
            ),
            strategyParams: abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Original,
                    width: 1000,
                    tickSpacing: 200,
                    tickNeighborhood: 100,
                    maxLiquidityRatioDeviationX96: 0
                })
            ),
            securityParams: abi.encode(
                IVeloOracle.SecurityParams({lookback: 100, maxAllowedDelta: 100, maxAge: 7 days})
            )
        });

        vm.prank(params.mellowAdmin);
        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    treasury: Constants.OPTIMISM_MELLOW_TREASURY,
                    feeD9: Constants.OPTIMISM_FEE_D9
                })
            )
        );

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);

        positionManager.approve(address(core), tokenId);
        uint256 positionId = core.deposit(depositParams);
        core.withdraw(positionId, Constants.OPTIMISM_DEPLOYER);

        assertEq(core.positionCount(), 2);

        positionManager.approve(address(core), tokenId);
        positionId = core.deposit(depositParams);
        core.withdraw(positionId, Constants.OPTIMISM_DEPLOYER);

        assertEq(core.positionCount(), 3);

        positionManager.approve(address(core), tokenId);
        positionId = core.deposit(depositParams);
        core.withdraw(positionId, Constants.OPTIMISM_DEPLOYER);

        assertEq(core.positionCount(), 4);

        positionManager.approve(address(core), tokenId);
        positionId = core.deposit(depositParams);
        core.withdraw(positionId, Constants.OPTIMISM_DEPLOYER);

        assertEq(core.positionCount(), 5);
    }

    function testGetUserIds() external {
        ICore core = contracts.core;

        uint256 positionId = _depositToken(
            core,
            mint(
                pool.token0(),
                pool.token1(),
                pool.tickSpacing(),
                pool.tickSpacing() * 2,
                10000,
                pool,
                Constants.OPTIMISM_DEPLOYER
            )
        );

        uint256[] memory ids = core.getUserIds(Constants.OPTIMISM_DEPLOYER);
        assertEq(ids.length, 1);
        assertEq(ids[0], positionId);

        ids = core.getUserIds(address(123546));
        assertEq(ids.length, 0);
    }

    function testEmptyRebalance() external {
        ICore core = contracts.core;

        uint256 positionId = _depositToken(
            core,
            mint(
                pool.token0(),
                pool.token1(),
                pool.tickSpacing(),
                pool.tickSpacing() * 2,
                10000,
                pool,
                Constants.OPTIMISM_DEPLOYER
            )
        );

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        core.emptyRebalance(positionId);

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);
        core.emptyRebalance(positionId);
    }
}
