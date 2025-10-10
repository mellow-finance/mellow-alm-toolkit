// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../unit/Fixture.sol";

import "../../scripts/deploy/Constants.sol";
import "src/utils/Rebalancer.sol";

contract RebalancerTest is Fixture {
    using SafeERC20 for IERC20;

    CoreDeploymentParams private coreParams;
    CoreDeployment private contracts;
    Rebalancer private rebalancer;
    TestRebalancingBot private bot;

    function setUp() external {
        coreParams = Constants.getDeploymentParams();
        coreParams.lpWrapperManager = vm.createWallet("lpWrapperManager").addr;

        vm.startPrank(coreParams.deployer);
        contracts = deployCore(coreParams);
        rebalancer = new Rebalancer(address(contracts.deployFactory));
        vm.stopPrank();

        vm.startPrank(coreParams.mellowAdmin);
        ICore(contracts.core).grantRole(ICore(contracts.core).OPERATOR_ROLE(), address(rebalancer));
        vm.stopPrank();

        bot = new TestRebalancingBot(
            address(contracts.ammModule),
            address(contracts.depositWithdrawModule),
            address(rebalancer)
        );
    }

    function testSwapRebalanceRevertZeroCallback() external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));

        uint160 sqrtPriceX96 = IAmmModule(contracts.ammModule).getSqrtPriceX96(address(pool));
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.Tamper, contracts);

        address depositor = vm.createWallet("depositor").addr;
        depositToLpWrapper(lpWrapper, depositor, 1e18);
        Rebalancer.RebalanceData memory rebalanceData = rebalancer.positionData(address(lpWrapper));
        assertFalse(rebalanceData.isRebalanceRequired);
        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setSecurityParams(
            IVeloOracle.SecurityParams({
                lookback: 1,
                maxAge: 1,
                maxAllowedDelta: 1000,
                extraData: ""
            })
        );
        vm.stopPrank();

        IAmmModule.AmmPosition memory ammPosition =
            IAmmModule(contracts.ammModule).getAmmPosition(rebalanceData.info.ammPositionIds[0]);
        int24 width = ammPosition.tickUpper - ammPosition.tickLower;

        movePrice(pool, TickMath.getSqrtRatioAtTick(tick - width / 20) - 1);
        rebalanceData = rebalancer.positionData(address(lpWrapper));
        assertTrue(rebalanceData.isRebalanceRequired);

        vm.expectRevert(IRebalancer.InvalidCallback.selector);
        rebalancer.rebalance(
            ICore.RebalanceParams({id: rebalanceData.target.id, callback: address(0), data: ""})
        );
    }

    function testRevertNoNeedRebalance() external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.LazySyncing, contracts);

        address depositor = vm.createWallet("depositor").addr;
        depositToLpWrapper(lpWrapper, depositor, 1e18);
        Rebalancer.RebalanceData memory rebalanceData = rebalancer.positionData(address(lpWrapper));
        assertFalse(rebalanceData.isRebalanceRequired);

        vm.expectRevert(IRebalancer.NoNeedRebalance.selector);
        rebalancer.rebalance(
            ICore.RebalanceParams({id: rebalanceData.target.id, callback: address(0), data: ""})
        );
    }

    function testRevertOnlyMoveLiquidity() external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));

        uint160 sqrtPriceX96 = IAmmModule(contracts.ammModule).getSqrtPriceX96(address(pool));
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.Tamper, contracts);

        address depositor = vm.createWallet("depositor").addr;
        depositToLpWrapper(lpWrapper, depositor, 1e18);
        Rebalancer.RebalanceData memory rebalanceData = rebalancer.positionData(address(lpWrapper));
        assertFalse(rebalanceData.isRebalanceRequired);

        /// @dev revert because target.lowerTicks > 1
        vm.expectRevert(IRebalancer.OnlyMoveLiquidity.selector);
        rebalancer.call("", rebalanceData.target, rebalanceData.info);

        IAmmModule.AmmPosition memory ammPosition =
            IAmmModule(contracts.ammModule).getAmmPosition(rebalanceData.info.ammPositionIds[0]);
        int24 width = ammPosition.tickUpper - ammPosition.tickLower;

        movePrice(pool, TickMath.getSqrtRatioAtTick(tick - width / 10));

        ICore.TargetPositionInfo memory target = ICore.TargetPositionInfo({
            id: rebalanceData.target.id,
            lowerTicks: new int24[](1),
            upperTicks: new int24[](1),
            liquidityRatiosX96: new uint256[](1),
            minLiquidities: new uint256[](1)
        });

        /// @dev revert because swap is required
        vm.expectRevert(IRebalancer.OnlyMoveLiquidity.selector);
        rebalancer.call("", target, rebalanceData.info);
    }

    function testRevertHighSlippage() external {
        int24 ts = 200;
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, ts));
        uint160 sqrtPriceX96 = IAmmModule(contracts.ammModule).getSqrtPriceX96(address(pool));
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        movePrice(pool, TickMath.getSqrtRatioAtTick(tick));
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.Tamper, contracts);

        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setSecurityParams(
            IVeloOracle.SecurityParams({
                lookback: 1,
                maxAge: 1,
                maxAllowedDelta: 1000,
                extraData: ""
            })
        );
        lpWrapper.setSlippageD9(1e3 + pool.fee() * 1000);
        vm.stopPrank();

        Rebalancer.RebalanceData memory rebalanceData;

        {
            address depositor = vm.createWallet("depositor").addr;
            depositToLpWrapper(lpWrapper, depositor, 10 ether);
            rebalanceData = rebalancer.positionData(address(lpWrapper));
            assertFalse(rebalanceData.isRebalanceRequired);
        }

        IAmmModule.AmmPosition memory ammPosition =
            IAmmModule(contracts.ammModule).getAmmPosition(rebalanceData.info.ammPositionIds[0]);
        int24 width = ammPosition.tickUpper - ammPosition.tickLower;
        uint24 movePart = 10;

        movePrice(pool, TickMath.getSqrtRatioAtTick(tick - width / int24(movePart)) - 1);
        rebalanceData = rebalancer.positionData(address(lpWrapper));

        /// @dev increaseLiquidityD9 = (1 - moveCapital*slippage) / (1 - slippage) rounded up
        uint256 increaseLiquidityD9 =
            bot.getMaxIncreaseLiquidityD9(rebalanceData.target, rebalanceData.info);
        /**
         * Core reduces liquidity of a new position to the slippage tolerance,
         *         so we need to increase the target liquidity a bit to be able to mint it
         *         in the callback
         * @param movePart - the part of the position to move, so real slippage will be slippageD9/movePart
         * @param increaseLiquidityD9 - slippageD9 - slippageD9/movePart
         */
        vm.expectRevert(IRebalancer.HighSlippage.selector);
        rebalancer.rebalance(
            ICore.RebalanceParams({
                id: rebalanceData.target.id,
                callback: address(bot),
                data: abi.encode(increaseLiquidityD9 - 1, false, false)
            })
        );
    }

    function testNoSwapRebalance() external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.LazySyncing, contracts);

        address depositor = vm.createWallet("depositor").addr;
        depositToLpWrapper(lpWrapper, depositor, 1e18);
        Rebalancer.RebalanceData memory rebalanceData = rebalancer.positionData(address(lpWrapper));
        assertFalse(rebalanceData.isRebalanceRequired);

        IAmmModule.AmmPosition memory ammPosition =
            IAmmModule(contracts.ammModule).getAmmPosition(rebalanceData.info.ammPositionIds[0]);

        movePrice(pool, TickMath.getSqrtRatioAtTick(ammPosition.tickLower - pool.tickSpacing() - 1));
        rebalanceData = rebalancer.positionData(address(lpWrapper));
        assertTrue(rebalanceData.isRebalanceRequired);

        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setSecurityParams(
            IVeloOracle.SecurityParams({
                lookback: 1,
                maxAge: 1,
                maxAllowedDelta: 1000,
                extraData: ""
            })
        );
        vm.stopPrank();

        uint256 snapshotId = vm.snapshot();

        {
            rebalanceData = rebalancer.positionData(address(lpWrapper));
            (uint256 amount0Before, uint256 amount1Before) =
                IAmmModule(contracts.ammModule).tvl(rebalanceData.info.ammPositionIds[0]);

            assertTrue(IERC20(lpWrapper.token0()).balanceOf(address(rebalancer)) == 0);
            assertTrue(IERC20(lpWrapper.token1()).balanceOf(address(rebalancer)) == 0);

            rebalancer.rebalance(
                ICore.RebalanceParams({id: rebalanceData.target.id, callback: address(0), data: ""})
            );

            rebalanceData = rebalancer.positionData(address(lpWrapper));
            (uint256 amount0After, uint256 amount1After) =
                IAmmModule(contracts.ammModule).tvl(rebalanceData.info.ammPositionIds[0]);

            assertTrue(IERC20(lpWrapper.token0()).balanceOf(address(rebalancer)) == 0);
            assertTrue(IERC20(lpWrapper.token1()).balanceOf(address(rebalancer)) == 0);
            assertApproxEqAbs(amount0Before, amount0After, 1);
            assertApproxEqAbs(amount1Before, amount1After, 1);
        }
        vm.revertTo(snapshotId);
        {
            rebalanceData = rebalancer.positionData(address(lpWrapper));
            (uint256 amount0Before, uint256 amount1Before) =
                IAmmModule(contracts.ammModule).tvl(rebalanceData.info.ammPositionIds[0]);

            assertTrue(IERC20(lpWrapper.token0()).balanceOf(address(rebalancer)) == 0);
            assertTrue(IERC20(lpWrapper.token1()).balanceOf(address(rebalancer)) == 0);

            vm.startPrank(coreParams.coreOperator);
            ICore(contracts.core).rebalance(
                ICore.RebalanceParams({
                    id: rebalanceData.target.id,
                    callback: address(rebalancer),
                    data: ""
                })
            );
            vm.stopPrank();

            rebalanceData = rebalancer.positionData(address(lpWrapper));
            (uint256 amount0After, uint256 amount1After) =
                IAmmModule(contracts.ammModule).tvl(rebalanceData.info.ammPositionIds[0]);

            assertTrue(IERC20(lpWrapper.token0()).balanceOf(address(rebalancer)) == 0);
            assertTrue(IERC20(lpWrapper.token1()).balanceOf(address(rebalancer)) == 0);
            assertApproxEqAbs(amount0Before, amount0After, 1);
            assertApproxEqAbs(amount1Before, amount1After, 1);
        }
        vm.revertTo(snapshotId);
        movePrice(pool, TickMath.getSqrtRatioAtTick(ammPosition.tickUpper + pool.tickSpacing() + 1));
        {
            rebalanceData = rebalancer.positionData(address(lpWrapper));
            (uint256 amount0Before, uint256 amount1Before) =
                IAmmModule(contracts.ammModule).tvl(rebalanceData.info.ammPositionIds[0]);

            assertTrue(IERC20(lpWrapper.token0()).balanceOf(address(rebalancer)) == 0);
            assertTrue(IERC20(lpWrapper.token1()).balanceOf(address(rebalancer)) == 0);

            rebalancer.rebalance(
                ICore.RebalanceParams({id: rebalanceData.target.id, callback: address(0), data: ""})
            );

            rebalanceData = rebalancer.positionData(address(lpWrapper));
            (uint256 amount0After, uint256 amount1After) =
                IAmmModule(contracts.ammModule).tvl(rebalanceData.info.ammPositionIds[0]);

            assertTrue(IERC20(lpWrapper.token0()).balanceOf(address(rebalancer)) == 0);
            assertTrue(IERC20(lpWrapper.token1()).balanceOf(address(rebalancer)) == 0);
            assertApproxEqAbs(amount0Before, amount0After, 1);
            assertApproxEqAbs(amount1Before, amount1After, 1);
        }
    }

    function testSwapRebalance() external {
        int24 ts = 200;
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, ts));
        uint160 sqrtPriceX96 = IAmmModule(contracts.ammModule).getSqrtPriceX96(address(pool));
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        movePrice(pool, TickMath.getSqrtRatioAtTick(tick));
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.Tamper, contracts);

        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setSecurityParams(
            IVeloOracle.SecurityParams({
                lookback: 1,
                maxAge: 1,
                maxAllowedDelta: 1000,
                extraData: ""
            })
        );
        lpWrapper.setSlippageD9(1e3 + pool.fee() * 1000);
        vm.stopPrank();

        Rebalancer.RebalanceData memory rebalanceData;

        {
            address depositor = vm.createWallet("depositor").addr;
            depositToLpWrapper(lpWrapper, depositor, 10 ether);
            rebalanceData = rebalancer.positionData(address(lpWrapper));
            assertFalse(rebalanceData.isRebalanceRequired);
        }

        ICore.ManagedPositionInfo memory info;
        IAmmModule.AmmPosition memory ammPosition =
            IAmmModule(contracts.ammModule).getAmmPosition(rebalanceData.info.ammPositionIds[0]);
        int24 width = ammPosition.tickUpper - ammPosition.tickLower;

        uint256 snapshotId = vm.snapshot();

        for (uint24 movePart = 2; movePart < 27; movePart++) {
            vm.revertTo(snapshotId);
            movePrice(pool, TickMath.getSqrtRatioAtTick(tick - width / int24(movePart)) - 1);
            rebalanceData = rebalancer.positionData(address(lpWrapper));
            /// @dev increaseLiquidityD9 = (1 - moveCapital*slippage) / (1 - slippage) rounded up
            uint256 increaseLiquidityD9 =
                bot.getMaxIncreaseLiquidityD9(rebalanceData.target, rebalanceData.info);

            rebalanceData.target =
                bot.estimateMinLiquidities(rebalanceData.target, rebalanceData.info);
            /**
             * Core reduces liquidity of a new position to the slippage tolerance,
             * so we need to increase the target liquidity regarding the actual affected capital
             * @param increaseLiquidityD9 - multiplier to increase target.minLiquidities = (1 - moveCapital*slippage) / (1 - slippage)
             */
            rebalancer.rebalance(
                ICore.RebalanceParams({
                    id: rebalanceData.target.id,
                    callback: address(bot),
                    data: abi.encode(increaseLiquidityD9, false, false)
                })
            );

            /// @dev check that all positions have at least target.minLiquidities * increaseLiquidityD9 / D9 liquidity
            (, info) = rebalancer.managedPositionInfo(address(lpWrapper));
            for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
                IAmmModule.AmmPosition memory position =
                    IAmmModule(contracts.ammModule).getAmmPosition(info.ammPositionIds[i]);
                assertGe(
                    position.liquidity,
                    rebalanceData.target.minLiquidities[i] * (increaseLiquidityD9 - 1) / D9
                );
            }

            vm.revertTo(snapshotId);
            movePrice(pool, TickMath.getSqrtRatioAtTick(tick + width / int24(movePart)) + 1);
            rebalanceData = rebalancer.positionData(address(lpWrapper));
            rebalanceData.target =
                bot.estimateMinLiquidities(rebalanceData.target, rebalanceData.info);

            rebalancer.rebalance(
                ICore.RebalanceParams({
                    id: rebalanceData.target.id,
                    callback: address(bot),
                    data: abi.encode(increaseLiquidityD9, false, false)
                })
            );

            (, info) = rebalancer.managedPositionInfo(address(lpWrapper));
            for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
                IAmmModule.AmmPosition memory position =
                    IAmmModule(contracts.ammModule).getAmmPosition(info.ammPositionIds[i]);
                assertGe(
                    position.liquidity,
                    rebalanceData.target.minLiquidities[i] * (increaseLiquidityD9 - 1) / D9
                );
            }
        }
    }

    function testSwapOnPoolRebalance() external {
        int24 ts = 200;
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, ts));
        uint160 sqrtPriceX96 = IAmmModule(contracts.ammModule).getSqrtPriceX96(address(pool));
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            73000,
            74000,
            1e10 ether,
            pool,
            address(this)
        );

        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.Tamper, contracts);

        movePrice(pool, TickMath.getSqrtRatioAtTick(tick + 100) + 1);
        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setSecurityParams(
            IVeloOracle.SecurityParams({
                lookback: 1,
                maxAge: 1,
                maxAllowedDelta: 1000,
                extraData: ""
            })
        );
        lpWrapper.setSlippageD9(1e5 + pool.fee() * 1000);
        vm.stopPrank();

        Rebalancer.RebalanceData memory rebalanceData = rebalancer.positionData(address(lpWrapper));

        ICore.ManagedPositionInfo memory info;
        IAmmModule.AmmPosition memory ammPosition =
            IAmmModule(contracts.ammModule).getAmmPosition(rebalanceData.info.ammPositionIds[0]);
        int24 width = ammPosition.tickUpper - ammPosition.tickLower;

        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setStrategyParams(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                tickNeighborhood: 0,
                tickSpacing: pool.tickSpacing(),
                width: width * 4,
                maxLiquidityRatioDeviationX96: 0
            })
        );
        vm.stopPrank();

        rebalanceData = rebalancer.positionData(address(lpWrapper));
        /// @dev increaseLiquidityD9 = (1 - moveCapital*slippage) / (1 - slippage) rounded up
        uint256 increaseLiquidityD9 =
            bot.getMaxIncreaseLiquidityD9(rebalanceData.target, rebalanceData.info);

        uint256 snapshotId = vm.snapshot();
        rebalanceData.target = bot.estimateMinLiquidities(rebalanceData.target, rebalanceData.info);
        rebalancer.rebalance(
            ICore.RebalanceParams({
                id: rebalanceData.target.id,
                callback: address(bot),
                data: abi.encode(increaseLiquidityD9 + 100, true, false)
            })
        );

        /// @dev check that all positions have at least target.minLiquidities * increaseLiquidityD9 / D9 liquidity
        (, info) = rebalancer.managedPositionInfo(address(lpWrapper));
        for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
            IAmmModule.AmmPosition memory position =
                IAmmModule(contracts.ammModule).getAmmPosition(info.ammPositionIds[i]);
            assertGe(
                position.liquidity,
                rebalanceData.target.minLiquidities[i] * (increaseLiquidityD9 - 1) / D9
            );
        }
        vm.revertTo(snapshotId);

        /// @dev provide flag for pool manipulation
        vm.expectRevert(IRebalancer.PoolManipulated.selector);
        rebalancer.rebalance(
            ICore.RebalanceParams({
                id: rebalanceData.target.id,
                callback: address(bot),
                data: abi.encode(increaseLiquidityD9 + 100, true, true)
            })
        );
    }

    function testChangeStrategyLazyToLazy(int8 tickDelta) external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.LazySyncing, contracts);

        address depositor = vm.createWallet("depositor").addr;
        depositToLpWrapper(lpWrapper, depositor, 1 ether);

        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setSecurityParams(
            IVeloOracle.SecurityParams({
                lookback: 1,
                maxAge: 1,
                maxAllowedDelta: 10000,
                extraData: ""
            })
        );
        vm.stopPrank();

        (, ICore.ManagedPositionInfo memory info) =
            rebalancer.managedPositionInfo(address(lpWrapper));
        IAmmModule.AmmPosition memory ammPosition =
            IAmmModule(contracts.ammModule).getAmmPosition(info.ammPositionIds[0]);
        int24 width = ammPosition.tickUpper - ammPosition.tickLower;

        (, int24 tickSpot) = IAmmModule(contracts.ammModule).getSqrtPriceX96AndTick(info.pool);
        /// @dev move price at the center of the position
        movePrice(pool, TickMath.getSqrtRatioAtTick(tickSpot + tickDelta) + 1);

        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setStrategyParams(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                tickNeighborhood: 0,
                tickSpacing: pool.tickSpacing(),
                width: width * 4,
                maxLiquidityRatioDeviationX96: 0
            })
        );
        vm.stopPrank();

        Rebalancer.RebalanceData memory rebalanceData = rebalancer.positionData(address(lpWrapper));
        assertTrue(rebalanceData.isRebalanceRequired);

        uint256 increaseLiquidityD9 =
            bot.getMaxIncreaseLiquidityD9(rebalanceData.target, rebalanceData.info);

        rebalanceData.target = bot.estimateMinLiquidities(rebalanceData.target, rebalanceData.info);
        rebalancer.rebalance(
            ICore.RebalanceParams({
                id: rebalanceData.target.id,
                callback: address(bot),
                /// @dev 100 D9 is added to increaseLiquidityD9 because of liquidity range extension
                data: abi.encode(increaseLiquidityD9 + 100, false, false)
            })
        );
        (, info) = rebalancer.managedPositionInfo(address(lpWrapper));
        for (uint256 j = 0; j < info.ammPositionIds.length; j++) {
            IAmmModule.AmmPosition memory position =
                IAmmModule(contracts.ammModule).getAmmPosition(info.ammPositionIds[j]);
            assertGe(
                position.liquidity,
                rebalanceData.target.minLiquidities[j] * (increaseLiquidityD9 - 1) / D9
            );
        }
    }

    function testChangeStrategyLazyToTamper(int8 tickDelta) external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.LazySyncing, contracts);

        address depositor = vm.createWallet("depositor").addr;
        depositToLpWrapper(lpWrapper, depositor, 1 ether);

        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setSecurityParams(
            IVeloOracle.SecurityParams({
                lookback: 1,
                maxAge: 1,
                maxAllowedDelta: 10000,
                extraData: ""
            })
        );
        vm.stopPrank();

        (, ICore.ManagedPositionInfo memory info) =
            rebalancer.managedPositionInfo(address(lpWrapper));
        IAmmModule.AmmPosition memory ammPosition =
            IAmmModule(contracts.ammModule).getAmmPosition(info.ammPositionIds[0]);
        int24 width = ammPosition.tickUpper - ammPosition.tickLower;

        (, int24 tickSpot) = IAmmModule(contracts.ammModule).getSqrtPriceX96AndTick(info.pool);
        /// @dev move price at the center of the position
        movePrice(pool, TickMath.getSqrtRatioAtTick(tickSpot + tickDelta) + 1);

        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setStrategyParams(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.Tamper,
                tickNeighborhood: 0,
                tickSpacing: pool.tickSpacing(),
                width: width * 4,
                maxLiquidityRatioDeviationX96: Q96 / 20
            })
        );
        vm.stopPrank();

        Rebalancer.RebalanceData memory rebalanceData = rebalancer.positionData(address(lpWrapper));
        assertTrue(rebalanceData.isRebalanceRequired);

        uint256 increaseLiquidityD9 =
            bot.getMaxIncreaseLiquidityD9(rebalanceData.target, rebalanceData.info);

        rebalanceData.target = bot.estimateMinLiquidities(rebalanceData.target, rebalanceData.info);
        rebalancer.rebalance(
            ICore.RebalanceParams({
                id: rebalanceData.target.id,
                callback: address(bot),
                data: abi.encode(increaseLiquidityD9, false, false)
            })
        );
        (, info) = rebalancer.managedPositionInfo(address(lpWrapper));
        for (uint256 j = 0; j < info.ammPositionIds.length; j++) {
            IAmmModule.AmmPosition memory position =
                IAmmModule(contracts.ammModule).getAmmPosition(info.ammPositionIds[j]);
            assertGe(
                position.liquidity,
                rebalanceData.target.minLiquidities[j] * (increaseLiquidityD9 - 1) / D9
            );
        }
    }

    function testChangeStrategyTamperToLazy(int8 tickDelta) external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.Tamper, contracts);

        address depositor = vm.createWallet("depositor").addr;
        depositToLpWrapper(lpWrapper, depositor, 1 ether);

        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setSecurityParams(
            IVeloOracle.SecurityParams({
                lookback: 1,
                maxAge: 1,
                maxAllowedDelta: 10000,
                extraData: ""
            })
        );
        vm.stopPrank();

        (, ICore.ManagedPositionInfo memory info) =
            rebalancer.managedPositionInfo(address(lpWrapper));
        IAmmModule.AmmPosition memory ammPosition =
            IAmmModule(contracts.ammModule).getAmmPosition(info.ammPositionIds[0]);
        int24 width = ammPosition.tickUpper - ammPosition.tickLower;

        (, int24 tickSpot) = IAmmModule(contracts.ammModule).getSqrtPriceX96AndTick(info.pool);
        /// @dev move price at the center of the position
        movePrice(pool, TickMath.getSqrtRatioAtTick(tickSpot + tickDelta) + 1);

        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setStrategyParams(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                tickNeighborhood: 0,
                tickSpacing: pool.tickSpacing(),
                width: width * 4,
                maxLiquidityRatioDeviationX96: 0
            })
        );
        vm.stopPrank();

        Rebalancer.RebalanceData memory rebalanceData = rebalancer.positionData(address(lpWrapper));
        assertTrue(rebalanceData.isRebalanceRequired);

        uint256 increaseLiquidityD9 =
            bot.getMaxIncreaseLiquidityD9(rebalanceData.target, rebalanceData.info);

        rebalanceData.target = bot.estimateMinLiquidities(rebalanceData.target, rebalanceData.info);
        rebalancer.rebalance(
            ICore.RebalanceParams({
                id: rebalanceData.target.id,
                callback: address(bot),
                /// @dev 100 D9 is added to increaseLiquidityD9 because of liquidity range extension
                data: abi.encode(increaseLiquidityD9 + 100, false, false)
            })
        );
        (, info) = rebalancer.managedPositionInfo(address(lpWrapper));
        for (uint256 j = 0; j < info.ammPositionIds.length; j++) {
            IAmmModule.AmmPosition memory position =
                IAmmModule(contracts.ammModule).getAmmPosition(info.ammPositionIds[j]);
            assertGe(
                position.liquidity,
                rebalanceData.target.minLiquidities[j] * (increaseLiquidityD9 - 1) / D9
            );
        }
    }

    function testChangeStrategyTamperToTamper(int8 tickDelta) external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.Tamper, contracts);

        address depositor = vm.createWallet("depositor").addr;
        depositToLpWrapper(lpWrapper, depositor, 1 ether);

        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setSecurityParams(
            IVeloOracle.SecurityParams({
                lookback: 1,
                maxAge: 1,
                maxAllowedDelta: 10000,
                extraData: ""
            })
        );
        vm.stopPrank();

        (, ICore.ManagedPositionInfo memory info) =
            rebalancer.managedPositionInfo(address(lpWrapper));
        IAmmModule.AmmPosition memory ammPosition =
            IAmmModule(contracts.ammModule).getAmmPosition(info.ammPositionIds[0]);
        int24 width = ammPosition.tickUpper - ammPosition.tickLower;

        (, int24 tickSpot) = IAmmModule(contracts.ammModule).getSqrtPriceX96AndTick(info.pool);
        /// @dev move price at the center of the position
        movePrice(pool, TickMath.getSqrtRatioAtTick(tickSpot + tickDelta) + 1);

        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setStrategyParams(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.Tamper,
                tickNeighborhood: 0,
                tickSpacing: pool.tickSpacing(),
                width: width * 4,
                maxLiquidityRatioDeviationX96: Q96 / 20
            })
        );
        vm.stopPrank();

        Rebalancer.RebalanceData memory rebalanceData = rebalancer.positionData(address(lpWrapper));
        assertTrue(rebalanceData.isRebalanceRequired);

        uint256 increaseLiquidityD9 =
            bot.getMaxIncreaseLiquidityD9(rebalanceData.target, rebalanceData.info);

        rebalanceData.target = bot.estimateMinLiquidities(rebalanceData.target, rebalanceData.info);
        rebalancer.rebalance(
            ICore.RebalanceParams({
                id: rebalanceData.target.id,
                callback: address(bot),
                data: abi.encode(increaseLiquidityD9 + 100, false, false)
            })
        );
        (, info) = rebalancer.managedPositionInfo(address(lpWrapper));
        for (uint256 j = 0; j < info.ammPositionIds.length; j++) {
            IAmmModule.AmmPosition memory position =
                IAmmModule(contracts.ammModule).getAmmPosition(info.ammPositionIds[j]);
            assertGe(
                position.liquidity,
                rebalanceData.target.minLiquidities[j] * (increaseLiquidityD9 - 1) / D9
            );
        }
    }

    function testFuzzNoSwapRebalance(int8[100] memory deltas) external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));

        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.LazySyncing, contracts);

        /// @dev intentionally 'disable' slippage check to simplify the testing
        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setSecurityParams(
            IVeloOracle.SecurityParams({
                lookback: 1,
                maxAge: 1,
                maxAllowedDelta: 10000,
                extraData: ""
            })
        );
        vm.stopPrank();

        address depositor = vm.createWallet("depositor").addr;
        depositToLpWrapper(lpWrapper, depositor, 1e18);
        Rebalancer.RebalanceData memory rebalanceData = rebalancer.positionData(address(lpWrapper));
        assertFalse(rebalanceData.isRebalanceRequired);

        (, int24 tick) = IAmmModule(contracts.ammModule).getSqrtPriceX96AndTick(address(pool));

        for (uint256 i = 0; i < deltas.length; i++) {
            if (deltas[i] == 0) {
                continue;
            }
            movePrice(pool, TickMath.getSqrtRatioAtTick(tick + deltas[i]));
            rebalanceData = rebalancer.positionData(address(lpWrapper));
            (, tick) = IAmmModule(contracts.ammModule).getSqrtPriceX96AndTick(address(pool));

            if (rebalanceData.isRebalanceRequired) {
                (uint256 amount0Before, uint256 amount1Before) =
                    IAmmModule(contracts.ammModule).tvl(rebalanceData.info.ammPositionIds[0]);

                assertTrue(IERC20(lpWrapper.token0()).balanceOf(address(rebalancer)) == 0);
                assertTrue(IERC20(lpWrapper.token1()).balanceOf(address(rebalancer)) == 0);

                rebalancer.rebalance(
                    ICore.RebalanceParams({
                        id: rebalanceData.target.id,
                        callback: address(0),
                        data: ""
                    })
                );

                rebalanceData = rebalancer.positionData(address(lpWrapper));
                (uint256 amount0After, uint256 amount1After) =
                    IAmmModule(contracts.ammModule).tvl(rebalanceData.info.ammPositionIds[0]);

                assertTrue(IERC20(lpWrapper.token0()).balanceOf(address(rebalancer)) == 0);
                assertTrue(IERC20(lpWrapper.token1()).balanceOf(address(rebalancer)) == 0);
                assertApproxEqAbs(amount0Before, amount0After, 1);
                assertApproxEqAbs(amount1Before, amount1After, 1);
            } else {
                vm.expectRevert(IRebalancer.NoNeedRebalance.selector);
                rebalancer.rebalance(
                    ICore.RebalanceParams({
                        id: rebalanceData.target.id,
                        callback: address(0),
                        data: ""
                    })
                );
            }
        }
    }

    function testFuzzSwapRebalance(int8[100] memory deltas) external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));

        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.Tamper, contracts);

        /// @dev intentionally 'disable' slippage check to simplify the testing
        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setSecurityParams(
            IVeloOracle.SecurityParams({
                lookback: 1,
                maxAge: 1,
                maxAllowedDelta: 10000,
                extraData: ""
            })
        );
        vm.stopPrank();

        address depositor = vm.createWallet("depositor").addr;
        depositToLpWrapper(lpWrapper, depositor, 1e18);
        Rebalancer.RebalanceData memory rebalanceData = rebalancer.positionData(address(lpWrapper));
        assertFalse(rebalanceData.isRebalanceRequired);

        (, int24 tick) = IAmmModule(contracts.ammModule).getSqrtPriceX96AndTick(address(pool));
        ICore.ManagedPositionInfo memory info;

        for (uint256 i = 0; i < deltas.length; i++) {
            if (deltas[i] == 0) {
                continue;
            }
            movePrice(pool, TickMath.getSqrtRatioAtTick(tick + deltas[i]));
            rebalanceData = rebalancer.positionData(address(lpWrapper));
            (, tick) = IAmmModule(contracts.ammModule).getSqrtPriceX96AndTick(address(pool));

            if (rebalanceData.isRebalanceRequired) {
                assertTrue(IERC20(lpWrapper.token0()).balanceOf(address(rebalancer)) == 0);
                assertTrue(IERC20(lpWrapper.token1()).balanceOf(address(rebalancer)) == 0);

                uint256 increaseLiquidityD9 =
                    bot.getMaxIncreaseLiquidityD9(rebalanceData.target, rebalanceData.info);

                rebalanceData.target =
                    bot.estimateMinLiquidities(rebalanceData.target, rebalanceData.info);
                rebalancer.rebalance(
                    ICore.RebalanceParams({
                        id: rebalanceData.target.id,
                        callback: address(bot),
                        data: abi.encode(increaseLiquidityD9, false, false)
                    })
                );
                (, info) = rebalancer.managedPositionInfo(address(lpWrapper));
                for (uint256 j = 0; j < info.ammPositionIds.length; j++) {
                    IAmmModule.AmmPosition memory position =
                        IAmmModule(contracts.ammModule).getAmmPosition(info.ammPositionIds[j]);
                    assertGe(
                        position.liquidity,
                        rebalanceData.target.minLiquidities[j] * (increaseLiquidityD9 - 1) / D9
                    );
                }
            } else {
                vm.expectRevert(IRebalancer.NoNeedRebalance.selector);
                rebalancer.rebalance(
                    ICore.RebalanceParams({
                        id: rebalanceData.target.id,
                        callback: address(0),
                        data: ""
                    })
                );
            }
        }
    }

    function depositToLpWrapper(ILpWrapper lpWrapper, address depositor, uint256 lpAmount)
        internal
    {
        (uint256 amount0, uint256 amount1) = lpWrapper.previewMint(lpAmount);
        IERC20 token0 = IERC20(lpWrapper.token0());
        IERC20 token1 = IERC20(lpWrapper.token1());

        deal(address(token0), depositor, amount0);
        deal(address(token1), depositor, amount1);

        vm.startPrank(depositor);

        token0.safeIncreaseAllowance(address(lpWrapper), amount0);
        token1.safeIncreaseAllowance(address(lpWrapper), amount1);

        lpWrapper.mint(
            ILpWrapper.MintParams({
                lpAmount: lpAmount,
                amount0Max: amount0,
                amount1Max: amount1,
                recipient: depositor,
                deadline: block.timestamp + 1
            })
        );
        vm.stopPrank();
    }
}

contract TestRebalancingBot is IRebalanceCallback, Test {
    using SafeERC20 for IERC20;

    uint256 private constant D9 = 1e9;
    IRebalancer public rebalancer;
    IVeloAmmModule public ammModule;
    address public depositWithdrawModule;
    bool private onPool;
    uint256 private increaseLiquidityD9;
    bool private manipulatePool;

    constructor(address ammModule_, address depositWithdrawModule_, address rebalancer_) {
        ammModule = IVeloAmmModule(ammModule_);
        rebalancer = IRebalancer(rebalancer_);
        depositWithdrawModule = depositWithdrawModule_;
    }

    fallback() external {
        Address.functionDelegateCall(
            address(ammModule),
            abi.encodeWithSelector(
                IAmmModule.poolCallback.selector, msg.sender, msg.sig, msg.data[4:]
            )
        );
    }

    function call(
        bytes memory data,
        ICore.TargetPositionInfo memory target,
        ICore.ManagedPositionInfo memory info
    ) external returns (uint256[] memory tokenIds) {
        (increaseLiquidityD9, onPool, manipulatePool) = abi.decode(data, (uint256, bool, bool));

        uint256 poolBalance0 = IERC20(ammModule.getToken0(info.pool)).balanceOf(address(info.pool));
        uint256 poolBalance1 = IERC20(ammModule.getToken1(info.pool)).balanceOf(address(info.pool));

        address this_ = address(this);
        for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
            IAmmModule.AmmPosition memory position =
                ammModule.getAmmPosition(info.ammPositionIds[i]);
            Address.functionDelegateCall(
                depositWithdrawModule,
                abi.encodeWithSelector(
                    IAmmDepositWithdrawModule.withdraw.selector,
                    info.ammPositionIds[i],
                    position.liquidity,
                    this_
                )
            );
            Address.functionDelegateCall(
                depositWithdrawModule,
                abi.encodeWithSelector(
                    IAmmDepositWithdrawModule.burn.selector, info.ammPositionIds[i]
                )
            );
        }
        if (onPool) {
            (bool zeroForOne, int256 amountIn) = _quote(target, info.pool);
            _swap(zeroForOne, amountIn, info.pool);
        }

        tokenIds = _mintTarget(info.pool, target);

        if (!onPool) {
            /// @dev save the pool balance to avoid affecting
            deal(ammModule.getToken0(info.pool), info.pool, poolBalance0);
            deal(ammModule.getToken1(info.pool), info.pool, poolBalance1);
        }
        increaseLiquidityD9 = 0;
        manipulatePool = false;
    }

    function _quote(ICore.TargetPositionInfo memory target, address pool)
        internal
        view
        returns (bool zeroForOne, int256 amountIn)
    {
        ICore.ManagedPositionInfo memory info;
        info.pool = pool;
        (, int256 amount0Delta, int256 amount1Delta) = estimateMovedCapitalD9(target, info);
        uint160 sqrtPriceX96 = ammModule.getSqrtPriceX96(info.pool);

        uint256 amount0Capital = PositionMath.calculateCapital(
            uint256(amount0Delta > 0 ? amount0Delta : int256(0)), 0, sqrtPriceX96
        );
        uint256 amount1Capital = PositionMath.calculateCapital(
            uint256(amount1Delta > 0 ? amount1Delta : int256(0)), 0, sqrtPriceX96
        );
        zeroForOne = amount0Capital > amount1Capital;
        amountIn = zeroForOne ? amount0Delta : amount1Delta;
    }

    function _swap(bool zeroForOne, int256 amountIn, address pool) internal {
        IERC20 tokenIn = IERC20(zeroForOne ? ammModule.getToken0(pool) : ammModule.getToken1(pool));
        tokenIn.safeIncreaseAllowance(pool, uint256(amountIn));

        ICLPool(pool).swap(
            address(this),
            zeroForOne,
            amountIn,
            zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            ""
        );

        /// @dev manipulate the pool price: swap backwards
        if (manipulatePool) {
            zeroForOne = !zeroForOne;
            amountIn = 1000 wei;
            tokenIn = IERC20(zeroForOne ? ammModule.getToken0(pool) : ammModule.getToken1(pool));
            uint256 balance = tokenIn.balanceOf(address(this));
            deal(address(tokenIn), address(this), uint256(amountIn));
            ICLPool(pool).swap(
                address(this),
                zeroForOne,
                amountIn,
                zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
                ""
            );
            deal(address(tokenIn), address(this), balance);
        }
    }

    function _mintTarget(address pool, ICore.TargetPositionInfo memory target)
        internal
        returns (uint256[] memory tokenIds)
    {
        tokenIds = new uint256[](target.lowerTicks.length);

        for (uint256 index = 0; index < target.lowerTicks.length; index++) {
            (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
                ammModule.getSqrtPriceX96(pool),
                TickMath.getSqrtRatioAtTick(target.lowerTicks[index]),
                TickMath.getSqrtRatioAtTick(target.upperTicks[index]),
                uint128(target.minLiquidities[index] * increaseLiquidityD9) / 1e9
            );

            tokenIds[index] =
                _mint(pool, amount0, amount1, target.lowerTicks[index], target.upperTicks[index]);
        }
    }

    function _mint(address pool, uint256 amount0, uint256 amount1, int24 tickLower, int24 tickUpper)
        internal
        returns (uint256 tokenId)
    {
        if (!onPool) {
            deal(ammModule.getToken0(pool), address(this), amount0 + 1);
            deal(ammModule.getToken1(pool), address(this), amount1 + 1);
        }
        bytes memory result = Address.functionDelegateCall(
            depositWithdrawModule,
            abi.encodeWithSelector(
                IAmmDepositWithdrawModule.mint.selector,
                pool,
                tickLower,
                tickUpper,
                IERC20(ammModule.getToken0(pool)).balanceOf(address(this)),
                IERC20(ammModule.getToken1(pool)).balanceOf(address(this)),
                address(this)
            )
        );

        (tokenId,,,) = abi.decode(result, (uint256, uint128, uint256, uint256));
        Address.functionDelegateCall(
            address(ammModule),
            abi.encodeWithSelector(IAmmModule.approveTokenId.selector, msg.sender, tokenId)
        );
        if (!onPool) {
            deal(ammModule.getToken0(pool), address(this), 0);
            deal(ammModule.getToken1(pool), address(this), 0);
        }
    }

    /// @dev increaseLiquidityD9 = (1 - moveCapital*slippage) / (1 - slippage) rounded up
    function getMaxIncreaseLiquidityD9(
        ICore.TargetPositionInfo memory target,
        ICore.ManagedPositionInfo memory info
    ) public view returns (uint256) {
        target = estimateMinLiquidities(target, info);
        (uint256 movedCapitalD9,,) = estimateMovedCapitalD9(target, info);
        return (D9 * D9 - movedCapitalD9 * info.slippageD9) / (D9 - info.slippageD9) + 1;
    }

    /// @dev estimate target.minLiquidities based Core logic, lines 249-261 Core.sol
    function estimateMinLiquidities(
        ICore.TargetPositionInfo memory target,
        ICore.ManagedPositionInfo memory input
    ) public view returns (ICore.TargetPositionInfo memory) {
        uint160 sqrtPriceX96 = ammModule.getSqrtPriceX96(input.pool);

        uint256 capitalInput;
        for (uint256 index = 0; index < input.ammPositionIds.length; index++) {
            (uint256 amount0, uint256 amount1) = ammModule.tvl(input.ammPositionIds[index]);
            capitalInput += PositionMath.calculateCapital(amount0, amount1, sqrtPriceX96);
        }
        uint256 targetCapitalX96;
        for (uint256 index = 0; index < target.lowerTicks.length; index++) {
            (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(target.lowerTicks[index]),
                TickMath.getSqrtRatioAtTick(target.upperTicks[index]),
                onPool
                    ? uint128(target.liquidityRatiosX96[index] * increaseLiquidityD9) / 1e9
                    : uint128(target.liquidityRatiosX96[index])
            );
            targetCapitalX96 += PositionMath.calculateCapital(amount0, amount1, sqrtPriceX96);
        }

        target.minLiquidities = new uint256[](target.lowerTicks.length);
        for (uint256 i = 0; i < target.lowerTicks.length; i++) {
            target.minLiquidities[i] =
                Math.mulDiv(target.liquidityRatiosX96[i], capitalInput, targetCapitalX96);
            target.minLiquidities[i] =
                Math.mulDiv(target.minLiquidities[i], D9 - input.slippageD9, D9);
        }

        return target;
    }

    /// @dev estimate the part of capital that will be moved during the rebalance in D9 format
    function estimateMovedCapitalD9(
        ICore.TargetPositionInfo memory target,
        ICore.ManagedPositionInfo memory input
    ) public view returns (uint256 movedCapital, int256 amount0Delta, int256 amount1Delta) {
        require(target.minLiquidities.length == target.lowerTicks.length, "minLiquidities not set");

        if (input.ammPositionIds.length > 0) {
            for (uint256 i = 0; i < input.ammPositionIds.length; i++) {
                (uint256 amount0, uint256 amount1) = ammModule.tvl(input.ammPositionIds[i]);
                amount0Delta += int256(amount0);
                amount1Delta += int256(amount1);
            }
        } else {
            amount0Delta = int256(IERC20(ammModule.getToken0(input.pool)).balanceOf(address(this)));
            amount1Delta = int256(IERC20(ammModule.getToken1(input.pool)).balanceOf(address(this)));
        }

        uint160 sqrtPriceX96 = ammModule.getSqrtPriceX96(input.pool);
        uint256 capitalInput = PositionMath.calculateCapital(
            uint256(amount0Delta), uint256(amount1Delta), sqrtPriceX96
        );

        for (uint256 index = 0; index < target.lowerTicks.length; index++) {
            (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(target.lowerTicks[index]),
                TickMath.getSqrtRatioAtTick(target.upperTicks[index]),
                onPool
                    ? uint128(target.minLiquidities[index] * (increaseLiquidityD9)) / 1e9
                    : uint128(target.minLiquidities[index])
            );
            amount0Delta -= int256(amount0);
            amount1Delta -= int256(amount1);
        }
        amount0Delta = amount0Delta < 0 ? -amount0Delta : amount0Delta;
        amount1Delta = amount1Delta < 0 ? -amount1Delta : amount1Delta;
        movedCapital = PositionMath.calculateCapital(
            uint256(amount0Delta), uint256(amount1Delta), sqrtPriceX96
        ) / 2;
        movedCapital = Math.mulDiv(movedCapital, D9, capitalInput);
    }
}
