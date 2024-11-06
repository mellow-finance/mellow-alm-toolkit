// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract EmptyBot is IRebalanceCallback {
    function call(bytes memory, ICore.TargetPositionInfo[] memory)
        external
        returns (uint256[][] memory)
    {}
}

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
        vm.startPrank(Constants.OPTIMISM_DEPLOYER);

        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    treasury: Constants.OPTIMISM_MELLOW_TREASURY,
                    feeD9: Constants.OPTIMISM_FEE_D9
                })
            )
        );

        positionManager.approve(address(core), tokenId);
        ICore.DepositParams memory depositParams;
        depositParams.ammPositionIds = new uint256[](1);
        depositParams.ammPositionIds[0] = tokenId;
        depositParams.owner = Constants.OPTIMISM_DEPLOYER;
        depositParams.callbackParams = new bytes(123);
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
        core.deposit(depositParams);

        assertEq(positionManager.ownerOf(tokenId), address(pool.gauge()));

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

    /*
    function _checkState(uint256 positionId, ICore.RebalanceParams memory rebalanceParams)
        private
    {
        ICore core = contracts.core;
        IAmmModule ammModule = contracts.ammModule;
        ICore.ManagedPositionInfo memory infoBefore = core.managedPositionAt(positionId);
        uint256 capitalBefore = 0;
        uint256 capitalAfter = 0;
        (uint160 sqrtPriceX96, int24 tick,,,,) = pool.slot0();
        uint256 priceX96 = Math.mulDiv(sqrtPriceX96, sqrtPriceX96, Q96);

        {
            (uint256 amount0, uint256 amount1) = ammModule.tvl(
                infoBefore.ammPositionIds[0],
                sqrtPriceX96,
                infoBefore.callbackParams,
                core.protocolParams()
            );
            capitalBefore = Math.mulDiv(amount0, priceX96, Q96) + amount1;
        }

        core.rebalance(rebalanceParams);

        ICore.ManagedPositionInfo memory infoAfter = core.managedPositionAt(positionId);
        IAmmModule.AmmPosition memory positionAfter =
            ammModule.getAmmPosition(infoAfter.ammPositionIds[0]);

        {
            (uint256 amount0, uint256 amount1) = ammModule.tvl(
                infoAfter.ammPositionIds[0],
                sqrtPriceX96,
                infoAfter.callbackParams,
                core.protocolParams()
            );
            capitalAfter = Math.mulDiv(amount0, priceX96, Q96) + amount1;
        }

        IPulseStrategyModule.StrategyParams memory strategyParams =
            abi.decode(infoBefore.strategyParams, (IPulseStrategyModule.StrategyParams));

        assertTrue(Math.mulDiv(capitalBefore, D9 - infoBefore.slippageD9, D9) <= capitalAfter);

        assertEq(positionAfter.tickUpper - positionAfter.tickLower, strategyParams.width);
        assertEq(positionAfter.tickUpper % strategyParams.tickSpacing, 0);
        assertEq(positionAfter.tickLower % strategyParams.tickSpacing, 0);
        assertTrue(positionAfter.tickLower <= tick && tick <= positionAfter.tickUpper);
    }

    function testRebalance() external {
        ICore core = contracts.core;

        pool.increaseObservationCardinalityNext(2);
        mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 100,
            1000000,
            pool
        );

        uint256 tokenId = mint(
            pool.token0(), pool.token1(), pool.tickSpacing(), pool.tickSpacing() * 2, 10000, pool
        );

        ICore.RebalanceParams memory rebalanceParams;

        uint256 positionId = _depositToken(tokenId);
        vm.startPrank(Constants.DEPLOYER);
        movePrice(73400, pool);
        vm.stopPrank();

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);
        core.setOperatorFlag(true);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        core.rebalance(rebalanceParams);

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);
        core.setOperatorFlag(false);
        vm.stopPrank();

        rebalanceParams.callback = address(new EmptyBot());

        // nothig happens
        core.rebalance(rebalanceParams);

        rebalanceParams.ids = new uint256[](1);
        rebalanceParams.ids[0] = positionId;

        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.rebalance(rebalanceParams);

        rebalanceParams.callback = address(new PulseVeloBot(quoterV2, swapRouter, positionManager));

        vm.expectRevert();
        core.rebalance(rebalanceParams);
    }
    */
}
