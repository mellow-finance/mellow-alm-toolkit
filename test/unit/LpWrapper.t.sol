// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    int24 constant MAX_ALLOWED_DELTA = 100;
    uint32 constant MAX_AGE = 1 hours;
    uint128 INITIAL_LIQUIDITY = 1 ether;

    ILpWrapper public lpWrapper;

    ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));

    DeployScript.CoreDeployment contracts;
    IVeloDeployFactory.DeployParams deployParams;

    function setUp() external {
        contracts = deployContracts();
        (lpWrapper, deployParams) = deployLpWrapper(pool, contracts);
    }

    function _mint(ICLPool pool_, int24 width, address owner) private returns (uint256 tokenId) {
        (, int24 tick,,,,) = pool_.slot0();
        int24 tickSpacing = pool_.tickSpacing();
        int24 tickLower = tickSpacing * (tick / tickSpacing);
        int24 tickUpper = tickLower + width;

        tokenId = mint(
            pool_.token0(), pool_.token1(), tickSpacing, tickLower, tickUpper, 1 ether, pool_, owner
        );
    }

    function _depositCore(ICLPool pool_, address owner, address farm)
        private
        returns (uint256 id, uint256 tokenId)
    {
        ICore core = contracts.core;
        tokenId = _mint(pool_, 1000, owner);

        vm.startPrank(owner);
        positionManager.approve(address(core), tokenId);

        ICore.DepositParams memory depositParams;
        depositParams.ammPositionIds = new uint256[](1);
        depositParams.ammPositionIds[0] = tokenId;
        depositParams.owner = owner;
        depositParams.callbackParams =
            abi.encode(IVeloAmmModule.CallbackParams({gauge: address(pool_.gauge()), farm: farm}));
        depositParams.strategyParams = abi.encode(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.Original,
                width: 1000,
                tickSpacing: pool_.tickSpacing(),
                tickNeighborhood: 100,
                maxLiquidityRatioDeviationX96: 0
            })
        );
        depositParams.slippageD9 = 1 * 1e5;
        depositParams.securityParams = abi.encode(
            IVeloOracle.SecurityParams({
                lookback: 1,
                maxAllowedDelta: MAX_ALLOWED_DELTA,
                maxAge: MAX_AGE
            })
        );

        id = core.deposit(depositParams);

        vm.stopPrank();
    }

    function testConstructor() external {
        ICore core = contracts.core;

        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        lpWrapper = new LpWrapper(address(0));

        lpWrapper = new LpWrapper(address(core));
        uint256 positionId;

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        lpWrapper.initialize(
            0, 1000 wei, 1000 ether, params.mellowAdmin, params.lpWrapperManager, "Name", "Symbol"
        );

        vm.expectRevert();
        lpWrapper.initialize(
            123, 1000 wei, 1000 ether, params.mellowAdmin, params.lpWrapperManager, "Name", "Symbol"
        );

        (positionId,) = _depositCore(pool, address(123), address(lpWrapper));
        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        lpWrapper.initialize(
            positionId,
            1000 wei,
            1000 ether,
            params.mellowAdmin,
            params.lpWrapperManager,
            "Name",
            "Symbol"
        );

        (positionId,) = _depositCore(pool, address(lpWrapper), address(new VeloFarmMock()));
        vm.expectRevert(abi.encodeWithSignature("InvalidState()"));
        lpWrapper.initialize(
            positionId,
            1000 wei,
            1000 ether,
            params.mellowAdmin,
            params.lpWrapperManager,
            "Name",
            "Symbol"
        );

        (positionId,) = _depositCore(pool, address(lpWrapper), address(lpWrapper));

        vm.prank(params.mellowAdmin);
        lpWrapper.initialize(
            positionId,
            1000 wei,
            1000 ether,
            params.mellowAdmin,
            params.lpWrapperManager,
            "Name",
            "Symbol"
        );
        ERC20Upgradeable(address(lpWrapper)).name();
        assertEq(ERC20Upgradeable(address(lpWrapper)).name(), "Name");
        assertEq(ERC20Upgradeable(address(lpWrapper)).symbol(), "Symbol");

        assertEq(lpWrapper.totalSupply(), 1000 wei);
        assertEq(lpWrapper.totalSupplyLimit(), 1000 ether);
        assertEq(lpWrapper.balanceOf(address(lpWrapper)), 1000 wei);

        vm.startPrank(params.mellowAdmin);
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        lpWrapper.initialize(
            positionId,
            1000 wei,
            1000 ether,
            params.mellowAdmin,
            params.lpWrapperManager,
            "Name",
            "Symbol"
        );
        vm.stopPrank();
    }

    function _validateCallbackParams(
        IVeloAmmModule.CallbackParams memory desired,
        IVeloAmmModule.CallbackParams memory actual
    ) internal {
        assertEq(desired.farm, actual.farm);
        assertEq(desired.gauge, actual.gauge);
    }

    function _validateStrategyParams(
        IPulseStrategyModule.StrategyParams memory desired,
        IPulseStrategyModule.StrategyParams memory actual
    ) internal {
        assertEq(uint256(desired.strategyType), uint256(actual.strategyType));
        assertEq(desired.tickNeighborhood, actual.tickNeighborhood);
        assertEq(desired.tickSpacing, actual.tickSpacing);
        assertEq(desired.width, actual.width);
        assertEq(desired.maxLiquidityRatioDeviationX96, actual.maxLiquidityRatioDeviationX96);
    }

    function _validateSecurityParams(
        IVeloOracle.SecurityParams memory desired,
        IVeloOracle.SecurityParams memory actual
    ) internal {
        assertEq(desired.lookback, actual.lookback);
        assertEq(desired.maxAge, actual.maxAge);
        assertEq(desired.maxAllowedDelta, actual.maxAllowedDelta);
    }

    function testSetParams() external {
        contracts = deployContracts();
        (lpWrapper, deployParams) = deployLpWrapper(pool, contracts);

        ICore core = contracts.core;
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(0);

        IVeloAmmModule.CallbackParams memory callbackParams =
            abi.decode(info.callbackParams, (IVeloAmmModule.CallbackParams));
        IPulseStrategyModule.StrategyParams memory strategyParams =
            abi.decode(info.strategyParams, (IPulseStrategyModule.StrategyParams));
        IVeloOracle.SecurityParams memory securityParams =
            abi.decode(info.securityParams, (IVeloOracle.SecurityParams));

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        lpWrapper.setPositionParams(1e5, callbackParams, strategyParams, securityParams);

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        lpWrapper.setPositionParams(
            1e5, abi.encode(callbackParams), abi.encode(strategyParams), abi.encode(securityParams)
        );

        {
            callbackParams.farm = address(123456);
            strategyParams.strategyType = IPulseStrategyModule.StrategyType.LazyDescending;
            securityParams.maxAge = 123 hours;

            vm.startPrank(params.lpWrapperAdmin);
            lpWrapper.setSlippageD9(3e5);

            lpWrapper.setCallbackParams(callbackParams);
            lpWrapper.setStrategyParams(strategyParams);
            lpWrapper.setSecurityParams(securityParams);
            lpWrapper.setTotalSupplyLimit(123456789e5);

            info = core.managedPositionAt(0);

            assertEq(3e5, info.slippageD9);
            assertEq(lpWrapper.totalSupplyLimit(), 123456789e5);
            _validateCallbackParams(
                callbackParams, abi.decode(info.callbackParams, (IVeloAmmModule.CallbackParams))
            );
            _validateStrategyParams(
                strategyParams,
                abi.decode(info.strategyParams, (IPulseStrategyModule.StrategyParams))
            );
            _validateSecurityParams(
                securityParams, abi.decode(info.securityParams, (IVeloOracle.SecurityParams))
            );

            vm.stopPrank();
        }
    }

    function testViewFunctions() external {
        contracts = deployContracts();
        (lpWrapper, deployParams) = deployLpWrapper(pool, contracts);

        (IVeloAmmModule.ProtocolParams memory paramsLpWrapper, uint256 d9) =
            lpWrapper.protocolParams();
        IVeloAmmModule.ProtocolParams memory paramsCore =
            abi.decode(contracts.core.protocolParams(), (IVeloAmmModule.ProtocolParams));
        assertEq(d9, 1e9);
        assertEq(paramsCore.treasury, paramsLpWrapper.treasury);
        assertEq(paramsCore.feeD9, paramsLpWrapper.feeD9);

        ICore.ManagedPositionInfo memory coreInfo =
            contracts.core.managedPositionAt(lpWrapper.positionId());
        PositionLibrary.Position[] memory positionInfo = lpWrapper.getInfo();
        assertEq(positionInfo.length, coreInfo.ammPositionIds.length);

        for (uint256 i = 0; i < positionInfo.length; i++) {
            uint256 tokenId = coreInfo.ammPositionIds[i];
            IVeloAmmModule.AmmPosition memory position = contracts.ammModule.getAmmPosition(tokenId);

            assertEq(positionInfo[i].tokenId, tokenId);
            assertEq(positionInfo[i].token0, position.token0);
            assertEq(positionInfo[i].token1, position.token1);
            assertEq(positionInfo[i].tickLower, position.tickLower);
            assertEq(positionInfo[i].tickUpper, position.tickUpper);
            assertEq(uint24(positionInfo[i].tickSpacing), position.property);
            assertEq(positionInfo[i].liquidity, position.liquidity);
        }
    }

    function testDeposit() external {
        ICore core = contracts.core;
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(0);
        IVeloAmmModule ammModule = contracts.ammModule;
        uint256 tokenId = info.ammPositionIds[0];

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);

        deal(pool.token0(), Constants.OPTIMISM_DEPLOYER, 1010000 ether);
        deal(pool.token1(), Constants.OPTIMISM_DEPLOYER, 1010000 ether);

        IERC20(pool.token0()).approve(address(lpWrapper), 1010000 ether);
        IERC20(pool.token1()).approve(address(lpWrapper), 1010000 ether);

        vm.expectRevert(abi.encodeWithSignature("InsufficientLpAmount()"));
        lpWrapper.deposit(
            1 ether, 1 ether, 100 ether, Constants.OPTIMISM_DEPLOYER, type(uint256).max
        );

        vm.expectRevert(abi.encodeWithSignature("Deadline()"));
        lpWrapper.deposit(1 ether, 1 ether, 0, Constants.OPTIMISM_DEPLOYER, block.timestamp - 1);

        vm.expectRevert(abi.encodeWithSignature("InsufficientAmounts()"));
        lpWrapper.deposit(0, 0, 0, Constants.OPTIMISM_DEPLOYER, type(uint256).max);

        vm.expectRevert(abi.encodeWithSignature("TotalSupplyLimitReached()"));
        lpWrapper.deposit(
            100000 ether, 100000 ether, 0, Constants.OPTIMISM_DEPLOYER, type(uint256).max
        );

        uint256 totalSupplyBefore = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionBefore = ammModule.getAmmPosition(tokenId);

        (uint256 amount0, uint256 amount1, uint256 lpAmount) = lpWrapper.deposit(
            1 ether, 1 ether, 0.999 ether, Constants.OPTIMISM_DEPLOYER, type(uint256).max
        );

        assertTrue(amount0 >= 6.427e14);
        assertTrue(amount1 >= 0.99 ether);
        assertTrue(lpAmount >= 0.999 ether);
        assertEq(lpWrapper.balanceOf(Constants.OPTIMISM_DEPLOYER), lpAmount);

        uint256 totalSupplyAfter = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionAfter = ammModule.getAmmPosition(tokenId);

        {
            uint256 expectedLiquidityIncrease = FullMath.mulDiv(
                positionBefore.liquidity, totalSupplyAfter - totalSupplyBefore, totalSupplyBefore
            );

            assertApproxEqAbs(
                expectedLiquidityIncrease, positionAfter.liquidity - positionBefore.liquidity, 1 wei
            );

            assertEq(
                FullMath.mulDiv(
                    positionAfter.liquidity - positionBefore.liquidity,
                    totalSupplyBefore,
                    positionBefore.liquidity
                ),
                totalSupplyAfter - totalSupplyBefore
            );
        }

        vm.expectRevert(abi.encodeWithSignature("InsufficientLpAmount()"));
        lpWrapper.deposit(
            1 ether, 1 ether, 100 ether, Constants.OPTIMISM_DEPLOYER, type(uint256).max
        );

        vm.stopPrank();
    }

    function testWithdraw() external {
        ICore core = contracts.core;
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(0);
        IVeloAmmModule ammModule = contracts.ammModule;
        uint256 tokenId = info.ammPositionIds[0];

        deal(pool.token0(), Constants.OPTIMISM_DEPLOYER, 1 ether + 2);
        deal(pool.token1(), Constants.OPTIMISM_DEPLOYER, 1 ether + 2);

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);
        IERC20(pool.token0()).approve(address(lpWrapper), 1 ether);
        IERC20(pool.token1()).approve(address(lpWrapper), 1 ether);

        lpWrapper.deposit(
            1 ether, 1 ether, 0.1 ether, Constants.OPTIMISM_DEPLOYER, type(uint256).max
        );
        lpWrapper.withdraw(type(uint256).max, 0, 0, Constants.OPTIMISM_DEPLOYER, type(uint256).max);
        skip(1 seconds);
        assertEq(IVeloFarm(lpWrapper).calculateEarnedRewards(Constants.OPTIMISM_DEPLOYER), 0);
        IERC20(pool.token0()).approve(address(lpWrapper), 1 ether);
        IERC20(pool.token1()).approve(address(lpWrapper), 1 ether);
        lpWrapper.deposit(
            1 ether, 1 ether, 0.1 ether, Constants.OPTIMISM_DEPLOYER, type(uint256).max
        );

        uint256 totalSupplyBefore = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionBefore = ammModule.getAmmPosition(tokenId);

        uint256 depositorBalance = lpWrapper.balanceOf(Constants.OPTIMISM_DEPLOYER);

        uint256 balance = lpWrapper.balanceOf(Constants.OPTIMISM_DEPLOYER);

        vm.expectRevert(abi.encodeWithSignature("InsufficientAmounts()"));
        lpWrapper.withdraw(
            balance / 2,
            type(uint256).max,
            type(uint256).max,
            Constants.OPTIMISM_DEPLOYER,
            type(uint256).max
        );

        vm.expectRevert(abi.encodeWithSignature("Deadline()"));
        lpWrapper.withdraw(
            balance / 2,
            type(uint256).max,
            type(uint256).max,
            Constants.OPTIMISM_DEPLOYER,
            block.timestamp - 1
        );
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSignature("InsufficientLpAmount()"));
        lpWrapper.withdraw(
            balance / 2,
            type(uint256).max,
            type(uint256).max,
            Constants.OPTIMISM_DEPLOYER,
            type(uint256).max
        );

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);

        lpWrapper.withdraw(balance / 2, 0, 0, Constants.OPTIMISM_DEPLOYER, type(uint256).max);

        assertApproxEqAbs(
            depositorBalance - balance / 2, lpWrapper.balanceOf(Constants.OPTIMISM_DEPLOYER), 0 wei
        );

        uint256 totalSupplyAfter = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionAfter = ammModule.getAmmPosition(tokenId);

        {
            uint256 expectedLiquidityDecrease = FullMath.mulDiv(
                positionBefore.liquidity, totalSupplyBefore - totalSupplyAfter, totalSupplyBefore
            );
            assertApproxEqAbs(
                expectedLiquidityDecrease, positionBefore.liquidity - positionAfter.liquidity, 1 wei
            );
        }

        vm.stopPrank();
    }

    function testReward() external {
        contracts = deployContracts();
        (lpWrapper, deployParams) = deployLpWrapper(pool, contracts);

        deal(pool.token0(), Constants.OPTIMISM_DEPLOYER, 1 ether);
        deal(pool.token1(), Constants.OPTIMISM_DEPLOYER, 1 ether);

        address gauge = pool.gauge();
        address rewardToken = ICLGauge(gauge).rewardToken();

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);

        IERC20(pool.token0()).approve(address(lpWrapper), 1 ether);
        IERC20(pool.token1()).approve(address(lpWrapper), 1 ether);

        uint256 totalSupplyBefore = lpWrapper.totalSupply();

        lpWrapper.deposit(1 ether, 1 ether, 0, Constants.OPTIMISM_DEPLOYER, type(uint256).max);
        vm.stopPrank();
        uint256 totalSupplyAfter = lpWrapper.totalSupply();

        vm.expectRevert(abi.encodeWithSignature("InvalidDistributor()"));
        IVeloFarm(lpWrapper).distribute(1 ether);

        skip(1 hours);

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);
        uint256 eranedAmount = IVeloFarm(lpWrapper).getRewards(Constants.OPTIMISM_DEPLOYER);
        assertEq(eranedAmount, IERC20(rewardToken).balanceOf(Constants.OPTIMISM_DEPLOYER));

        assertApproxEqRel(
            FullMath.mulDiv(eranedAmount, Q96, totalSupplyAfter - totalSupplyBefore),
            FullMath.mulDiv(
                IERC20(rewardToken).balanceOf(address(lpWrapper)), Q96, totalSupplyBefore
            ),
            10 ** 3 // 1e-15
        );
    }

    function testEmptyRebalance() external {
        contracts = deployContracts();
        (lpWrapper, deployParams) = deployLpWrapper(pool, contracts);

        ICore.ManagedPositionInfo memory info = contracts.core.managedPositionAt(0);
        uint256 tokenIdBefore = info.ammPositionIds[0];

        lpWrapper.emptyRebalance();

        info = contracts.core.managedPositionAt(0);
        uint256 tokenIdAfter = info.ammPositionIds[0];

        assertEq(tokenIdBefore, tokenIdAfter);
    }
}
