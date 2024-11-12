// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract PulseStrategyModuleTestV1 is Fixture {
    using SafeERC20 for IERC20;

    PulseStrategyModule public pulseStrategyModule = new PulseStrategyModule();

    function _max(int24 a, int24 b) private pure returns (int24) {
        if (a < b) {
            return b;
        }
        return a;
    }

    function _min(int24 a, int24 b) private pure returns (int24) {
        if (a > b) {
            return b;
        }
        return a;
    }

    function _abs(int24 a) private pure returns (int24) {
        if (a < 0) {
            return -a;
        }
        return a;
    }

    function _validateOriginal(
        int24 spotTick,
        int24 tickLower,
        int24 tickUpper,
        IPulseStrategyModule.StrategyParams memory params,
        bool flag,
        ICore.TargetPositionInfo memory target
    ) private {
        if (
            tickLower + params.tickNeighborhood <= spotTick
                && tickUpper - params.tickNeighborhood >= spotTick
                && tickUpper - tickLower == params.width
        ) {
            assertFalse(flag);
            return;
        }
        assertTrue(flag);
        assertEq(target.lowerTicks.length, 1);
        assertEq(target.upperTicks.length, 1);
        assertEq(target.liquidityRatiosX96.length, 1);
        assertEq(target.upperTicks[0] - target.lowerTicks[0], params.width);
        assertEq(target.liquidityRatiosX96[0], Q96);
        assertTrue(target.upperTicks[0] % params.tickSpacing == 0);
        assertTrue(target.lowerTicks[0] % params.tickSpacing == 0);

        int24 currentPenalty =
            _max(_abs(spotTick - target.lowerTicks[0]), _abs(spotTick - target.upperTicks[0]));

        int24 lowerPenalty = _max(
            _abs(spotTick - target.lowerTicks[0] + params.tickSpacing),
            _abs(spotTick - target.upperTicks[0] + params.tickSpacing)
        );

        int24 upperPenalty = _max(
            _abs(spotTick - target.lowerTicks[0] - params.tickSpacing),
            _abs(spotTick - target.upperTicks[0] - params.tickSpacing)
        );

        assertTrue(currentPenalty <= lowerPenalty);
        assertTrue(currentPenalty <= upperPenalty);
    }

    function _validate(
        int24 spotTick,
        int24 tickLower,
        int24 tickUpper,
        IPulseStrategyModule.StrategyParams memory params,
        bool flag,
        ICore.TargetPositionInfo memory target
    ) private {
        if (
            (params.width != tickUpper - tickLower && tickUpper == tickLower)
                || params.strategyType == IPulseStrategyModule.StrategyType.Original
        ) {
            return _validateOriginal(spotTick, tickLower, tickUpper, params, flag, target);
        }

        if (!flag) {
            if (
                (target.lowerTicks.length == 0 && target.upperTicks.length == 0)
                    || (
                        spotTick > tickLower - params.tickSpacing
                            && spotTick < tickUpper + params.tickSpacing - 1
                    ) || (spotTick >= target.lowerTicks[0] && spotTick < target.upperTicks[0])
            ) {
                return;
            }
        }

        if (params.strategyType == IPulseStrategyModule.StrategyType.LazyAscending) {
            assertTrue(flag);
            assertEq(target.lowerTicks.length, 1);
            assertEq(target.upperTicks.length, 1);
            assertEq(target.liquidityRatiosX96.length, 1);
            assertEq(target.upperTicks[0] - target.lowerTicks[0], params.width);
            assertEq(target.liquidityRatiosX96[0], Q96);
            assertTrue(target.upperTicks[0] % params.tickSpacing == 0);
            assertTrue(target.lowerTicks[0] % params.tickSpacing == 0);
            assertTrue(
                target.upperTicks[0] <= spotTick
                    || (spotTick >= target.lowerTicks[0] && spotTick < target.upperTicks[0])
            );
            assertTrue(spotTick - target.upperTicks[0] < params.tickSpacing);
            return;
        }

        if (params.strategyType == IPulseStrategyModule.StrategyType.LazyDescending) {
            assertTrue(flag);
            assertEq(target.lowerTicks.length, 1);
            assertEq(target.upperTicks.length, 1);
            assertEq(target.liquidityRatiosX96.length, 1);
            assertEq(target.upperTicks[0] - target.lowerTicks[0], params.width);
            assertEq(target.liquidityRatiosX96[0], Q96);
            assertTrue(target.upperTicks[0] % params.tickSpacing == 0);
            assertTrue(target.lowerTicks[0] % params.tickSpacing == 0);
            assertTrue(
                target.lowerTicks[0] >= spotTick
                    || (spotTick >= target.lowerTicks[0] && spotTick < target.upperTicks[0])
            );
            assertTrue(target.lowerTicks[0] - spotTick < params.tickSpacing);
            return;
        }

        if (params.strategyType == IPulseStrategyModule.StrategyType.LazySyncing) {
            assertTrue(flag);
            assertEq(target.lowerTicks.length, 1);
            assertEq(target.upperTicks.length, 1);
            assertEq(target.liquidityRatiosX96.length, 1);
            assertEq(target.upperTicks[0] - target.lowerTicks[0], params.width);
            assertEq(target.liquidityRatiosX96[0], Q96);
            assertTrue(target.upperTicks[0] % params.tickSpacing == 0);
            assertTrue(target.lowerTicks[0] % params.tickSpacing == 0);

            assertTrue(target.lowerTicks[0] - params.tickSpacing < spotTick);
            assertTrue(target.upperTicks[0] + params.tickSpacing > spotTick);

            assertTrue(
                _min(_abs(spotTick - target.lowerTicks[0]), _abs(spotTick - target.upperTicks[0]))
                    < params.tickSpacing
            );
            return;
        }

        assertTrue(false);
    }

    function _test(
        int24 spotTick,
        int24 tickLower,
        int24 tickUpper,
        IPulseStrategyModule.StrategyType strategyType,
        int24 tickSpacing,
        int24 tickNeighborhood,
        int24 width
    ) private {
        IPulseStrategyModule.StrategyParams memory params = IPulseStrategyModule.StrategyParams({
            strategyType: strategyType,
            tickSpacing: tickSpacing,
            tickNeighborhood: tickNeighborhood,
            width: width,
            maxLiquidityRatioDeviationX96: 0
        });
        IAmmModule.AmmPosition[] memory positions = new IAmmModule.AmmPosition[](1);
        positions[0].tickLower = tickLower;
        positions[0].tickUpper = tickUpper;
        (bool isRebalanceRequired, ICore.TargetPositionInfo memory target) = pulseStrategyModule
            .calculateTargetPulse(TickMath.getSqrtRatioAtTick(spotTick), spotTick, positions, params);

        _validate(spotTick, tickLower, tickUpper, params, isRebalanceRequired, target);
    }

    function testCalculateTargetOriginal() external {
        IPulseStrategyModule.StrategyType t = IPulseStrategyModule.StrategyType.Original;
        for (int24 spot = -200; spot <= 200; spot++) {
            _test(spot, -100, 200, t, 100, 50, 300);
        }
        _test(23, -100, 200, t, 100, 50, 200);
        _test(-49, -100, 0, t, 100, 25, 200);
        _test(-51, -100, 0, t, 100, 25, 200);
    }

    function testCalculateTargetLazyAscending() external {
        IPulseStrategyModule.StrategyType t = IPulseStrategyModule.StrategyType.LazyAscending;
        for (int24 spot = -200; spot <= 200; spot++) {
            _test(spot, -100, 200, t, 100, 0, 300);
        }
        _test(23, -100, 200, t, 100, 0, 200);
        _test(-49, -100, 0, t, 100, 0, 200);
        _test(-51, -100, 0, t, 100, 0, 200);
    }

    function testCalculateTargetLazyDescending() external {
        IPulseStrategyModule.StrategyType t = IPulseStrategyModule.StrategyType.LazyDescending;
        for (int24 spot = -200; spot <= 200; spot++) {
            _test(spot, -100, 200, t, 100, 0, 300);
        }
        _test(23, -100, 200, t, 100, 0, 200);
        _test(-49, -100, 0, t, 100, 0, 200);
        _test(-51, -100, 0, t, 100, 0, 200);
    }

    function testCalculateTargetLazySyncing() external {
        IPulseStrategyModule.StrategyType t = IPulseStrategyModule.StrategyType.LazySyncing;
        for (int24 spot = -200; spot <= 200; spot++) {
            _test(spot, -100, 200, t, 100, 10, 300);
        }

        _test(191, -100, 200, t, 100, 0, 300);
        _test(23, -100, 200, t, 100, 0, 200);
        _test(-49, -100, 0, t, 100, 0, 200);
        _test(-51, -100, 0, t, 100, 0, 200);
        _test(23, -100, 200, t, 100, 0, 300);
        _test(-49, -100, 0, t, 100, 0, 100);
        _test(-51, -100, 0, t, 100, 0, 100);
        _test(-350, -100, 200, t, 100, 0, 300);
        _test(-450, -100, 0, t, 100, 0, 100);
        _test(-200, -100, 0, t, 100, 0, 100);
        _test(350, -100, 200, t, 100, 0, 300);
        _test(450, -100, 0, t, 100, 0, 100);
        _test(200, -100, 0, t, 100, 0, 100);
    }

    function testValidateStrategyParams() external {
        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Original,
                    tickSpacing: 100,
                    tickNeighborhood: 50,
                    width: 300,
                    maxLiquidityRatioDeviationX96: 0
                })
            )
        );
        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Original,
                    tickSpacing: 1,
                    tickNeighborhood: 0,
                    width: 1,
                    maxLiquidityRatioDeviationX96: 0
                })
            )
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Original,
                    tickSpacing: 1,
                    tickNeighborhood: 1,
                    width: 0,
                    maxLiquidityRatioDeviationX96: 0
                })
            )
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Original,
                    tickSpacing: 0,
                    tickNeighborhood: 1,
                    width: 1,
                    maxLiquidityRatioDeviationX96: 0
                })
            )
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                    tickSpacing: 1,
                    tickNeighborhood: 1,
                    width: 1,
                    maxLiquidityRatioDeviationX96: 0
                })
            )
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Original,
                    tickSpacing: 2,
                    tickNeighborhood: 1,
                    width: 3,
                    maxLiquidityRatioDeviationX96: 0
                })
            )
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Original,
                    tickSpacing: 1,
                    tickNeighborhood: 1,
                    width: 1,
                    maxLiquidityRatioDeviationX96: 0
                })
            )
        );

        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Original,
                    tickSpacing: 1,
                    tickNeighborhood: 1,
                    width: 2,
                    maxLiquidityRatioDeviationX96: 0
                })
            )
        );

        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Original,
                    tickSpacing: 50,
                    tickNeighborhood: 200,
                    width: 4200,
                    maxLiquidityRatioDeviationX96: 0
                })
            )
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Original,
                    tickSpacing: 50,
                    tickNeighborhood: 200,
                    width: 4200,
                    maxLiquidityRatioDeviationX96: 1
                })
            )
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Tamper,
                    tickSpacing: 1,
                    tickNeighborhood: 0,
                    width: 3,
                    maxLiquidityRatioDeviationX96: Q96 / 2
                })
            )
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Tamper,
                    tickSpacing: 10,
                    tickNeighborhood: 0,
                    width: 30,
                    maxLiquidityRatioDeviationX96: Q96 / 2
                })
            )
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Tamper,
                    tickSpacing: 200,
                    tickNeighborhood: 0,
                    width: 4000,
                    maxLiquidityRatioDeviationX96: 0
                })
            )
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Tamper,
                    tickSpacing: 200,
                    tickNeighborhood: 0,
                    width: 4000,
                    maxLiquidityRatioDeviationX96: Q96
                })
            )
        );
    }

    function testCalculateTamperPosition() external view {
        int24 tick = 1000;
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
        pulseStrategyModule.calculateTamperPosition(sqrtPriceX96, tick, 20);
        pulseStrategyModule.calculateTamperPosition(sqrtPriceX96, tick + 100, 20);
    }

    function testGetTargets() external {
        ICore.ManagedPositionInfo memory info;

        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
        info.pool = address(pool);
        VeloOracle oracle = new VeloOracle();
        {
            info.strategyParams = abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Original,
                    tickSpacing: pool.tickSpacing(),
                    tickNeighborhood: 50,
                    width: 300,
                    maxLiquidityRatioDeviationX96: 0
                })
            );

            // vm.expectRevert();
            pulseStrategyModule.getTargets(info, IAmmModule(address(0)), oracle);

            pool.increaseObservationCardinalityNext(2);
            uint256 tokenId = mint(
                pool.token0(),
                pool.token1(),
                pool.tickSpacing(),
                pool.tickSpacing() * 2,
                10000,
                pool,
                address(this)
            );

            info.ammPositionIds = new uint256[](1);
            info.ammPositionIds[0] = tokenId;

            VeloAmmModule ammModule = new VeloAmmModule(
                INonfungiblePositionManager(Constants.OPTIMISM_POSITION_MANAGER),
                Constants.OPTIMISM_IS_POOL_SELECTOR
            );

            (bool isRebalanceRequired, ICore.TargetPositionInfo memory target) =
                pulseStrategyModule.getTargets(info, ammModule, oracle);

            assertTrue(isRebalanceRequired);
            assertEq(target.lowerTicks.length, 1);
            assertEq(target.upperTicks.length, 1);
            assertEq(target.liquidityRatiosX96.length, 1);
            assertEq(target.upperTicks[0] - target.lowerTicks[0], 300);
        }

        {
            info.ammPositionIds = new uint256[](1);
            info.strategyParams = abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Tamper,
                    tickSpacing: pool.tickSpacing(),
                    tickNeighborhood: 50,
                    width: 300,
                    maxLiquidityRatioDeviationX96: 0
                })
            );

            vm.expectRevert();
            pulseStrategyModule.getTargets(info, IAmmModule(address(0)), oracle);

            info.ammPositionIds = new uint256[](3);
            info.strategyParams = abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Tamper,
                    tickSpacing: pool.tickSpacing(),
                    tickNeighborhood: 50,
                    width: 300,
                    maxLiquidityRatioDeviationX96: 0
                })
            );

            vm.expectRevert();
            pulseStrategyModule.getTargets(info, IAmmModule(address(0)), oracle);

            IVeloAmmModule ammModule = IVeloAmmModule(
                new VeloAmmModule(
                    INonfungiblePositionManager(Constants.OPTIMISM_POSITION_MANAGER),
                    Constants.OPTIMISM_IS_POOL_SELECTOR
                )
            );

            vm.expectRevert();
            pulseStrategyModule.getTargets(info, ammModule, oracle);

            info.ammPositionIds = new uint256[](2);
            info.strategyParams = abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Tamper,
                    tickSpacing: pool.tickSpacing(),
                    tickNeighborhood: 0,
                    width: 400,
                    maxLiquidityRatioDeviationX96: Q96 - 1
                })
            );

            info.ammPositionIds[0] = mint(
                pool.token0(),
                pool.token1(),
                pool.tickSpacing(),
                400,
                800,
                1000,
                pool,
                address(this)
            );
            info.ammPositionIds[1] = mint(
                pool.token0(),
                pool.token1(),
                pool.tickSpacing(),
                600,
                1000,
                1000,
                pool,
                address(this)
            );
            pulseStrategyModule.getTargets(info, ammModule, oracle);

            info.ammPositionIds[0] = mint(
                pool.token0(),
                pool.token1(),
                pool.tickSpacing(),
                73600,
                74000,
                1000,
                pool,
                address(this)
            );
            info.ammPositionIds[1] = mint(
                pool.token0(),
                pool.token1(),
                pool.tickSpacing(),
                73800,
                74200,
                1000,
                pool,
                address(this)
            );
            pulseStrategyModule.getTargets(info, ammModule, oracle);

            info.ammPositionIds = new uint256[](3);
            info.ammPositionIds[0] = mint(
                pool.token0(),
                pool.token1(),
                pool.tickSpacing(),
                73600,
                74000,
                1000,
                pool,
                address(this)
            );
            info.ammPositionIds[1] = mint(
                pool.token0(),
                pool.token1(),
                pool.tickSpacing(),
                73600,
                74000,
                1000,
                pool,
                address(this)
            );
            info.ammPositionIds[2] = mint(
                pool.token0(),
                pool.token1(),
                pool.tickSpacing(),
                73600,
                74000,
                1000,
                pool,
                address(this)
            );
            pulseStrategyModule.getTargets(info, ammModule, oracle);
        }
    }
}

contract PulseStrategyModuleTestV2 is Fixture {
    using SafeERC20 for IERC20;
    using Math for uint256;

    struct TestCase {
        uint160 sqrtPriceX96;
        int24 tickLower;
        int24 tickUpper;
        IPulseStrategyModule.StrategyType strategyType;
        int24 tickSpacing;
        int24 tickNeighborhood;
        int24 tickLowerExpected;
        int24 tickUpperExpected;
    }

    PulseStrategyModule public pulseStrategyModule = new PulseStrategyModule();

    uint160 sqrtPriceX96Frac_near_0 = 79228162514264733714550801400; // 1.0001^(1e-10/2) * Q96
    uint160 sqrtPriceX96Frac_0_0001 = 79228162910385345434860427129; // 1.0001^(0.0001/2) * Q96
    uint160 sqrtPriceX96Frac_0_4999 = 79230142747924215822526283666; // 1.0001^(0.4999/2) * Q96
    uint160 sqrtPriceX96Frac_0_5001 = 79230143540186034832312214731; // 1.0001^(0.5001/2) * Q96
    uint160 sqrtPriceX96Frac_0_9999 = 79232123427218987702309994166; // 1.0001^(0.9999/2) * Q96
    uint160 sqrtPriceX96Frac_near_1 = 79232123823359402977474593289; // 1.0001^((1 - 1e-10)/2) * Q96

    function _test(TestCase memory tc) private {
        int24 width = tc.tickUpper - tc.tickLower;
        int24 spotTick = TickMath.getTickAtSqrtRatio(tc.sqrtPriceX96);
        IPulseStrategyModule.StrategyParams memory params = IPulseStrategyModule.StrategyParams({
            strategyType: tc.strategyType,
            tickSpacing: tc.tickSpacing,
            tickNeighborhood: tc.tickNeighborhood,
            width: width,
            maxLiquidityRatioDeviationX96: 0
        });
        IAmmModule.AmmPosition[] memory positions = new IAmmModule.AmmPosition[](1);
        positions[0].tickLower = tc.tickLower;
        positions[0].tickUpper = tc.tickUpper;
        (, ICore.TargetPositionInfo memory target) =
            pulseStrategyModule.calculateTargetPulse(tc.sqrtPriceX96, spotTick, positions, params);

        if (tc.tickLowerExpected != tc.tickUpperExpected) {
            assertEq(target.lowerTicks.length, 1);
            assertEq(target.upperTicks.length, 1);
            assertEq(target.liquidityRatiosX96.length, 1);
            assertEq(target.upperTicks[0] - target.lowerTicks[0], params.width);
            assertEq(target.liquidityRatiosX96[0], Q96);
            assertTrue(target.upperTicks[0] % params.tickSpacing == 0);
            assertTrue(target.lowerTicks[0] % params.tickSpacing == 0);

            assertEq(tc.tickLowerExpected, target.lowerTicks[0]);
            assertEq(tc.tickUpperExpected, target.upperTicks[0]);
        } else {
            assertEq(target.lowerTicks.length, 0);
            assertEq(target.upperTicks.length, 0);
            assertEq(target.liquidityRatiosX96.length, 0);
        }
    }
    /* Example
            width = 2
            tickSpacing = 1
            spotTick = 1.9999 
            tick = 1
            sqrtPrice = getSqrtRatioAtTick(1.9999)

            prev result:
            [0, 2]

            new result:
            [1, 3]
        */

    function testCalculateTargetOriginalTSCoverage() external view {
        IPulseStrategyModule.StrategyParams memory params;

        params.strategyType = IPulseStrategyModule.StrategyType.Original;
        params.tickNeighborhood = 0;
        params.tickSpacing = 1;
        params.width = 200;
        params.maxLiquidityRatioDeviationX96 = Q96 - 1;
        // just to cover 76-77 lines at src/modules/strategies/PulseStrategyModule.sol
        // becasue it actually could not happen
        pulseStrategyModule.calculateCenteredPosition(TickMath.getSqrtRatioAtTick(300), 301, 200, 1);
    }

    function testCalculateTargetOriginalTS_1() external {
        IPulseStrategyModule.StrategyType t = IPulseStrategyModule.StrategyType.Original;

        int24 tickSpacing = 1;
        for (int24 i = 2; i <= 10; i++) {
            int24 width = i * tickSpacing;
            int24 shift = 0;
            if (width > tickSpacing && (width / tickSpacing) % 2 == 0) {
                shift = tickSpacing;
            }
            TestCase memory tc = TestCase({
                sqrtPriceX96: 0,
                tickLower: 200,
                tickUpper: 200 + width,
                strategyType: t,
                tickSpacing: tickSpacing,
                tickNeighborhood: 0,
                tickLowerExpected: 0,
                tickUpperExpected: 0
            });
            for (int24 spot = -100; spot <= 100; spot++) {
                int24 tickLowerExpected = spot - width / 2;
                int24 remainder = tickLowerExpected % tickSpacing;
                if (remainder < 0) {
                    remainder += tickSpacing;
                }
                tickLowerExpected -= remainder;
                int24 tickUpperExpected = tickLowerExpected + width;
                if (!(spot >= tickLowerExpected && spot < tickUpperExpected)) {
                    tickLowerExpected += tickSpacing;
                    tickUpperExpected += tickSpacing;
                }

                uint256 sqrtPriceX96_i = TickMath.getSqrtRatioAtTick(spot);

                uint256 sqrtPriceX96_i_near_1 = sqrtPriceX96_i.mulDiv(sqrtPriceX96Frac_near_1, Q96);
                tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_near_1);
                tc.tickLowerExpected = tickLowerExpected + shift;
                tc.tickUpperExpected = tickUpperExpected + shift;
                _test(tc);

                uint256 sqrtPriceX96_i_9999 = sqrtPriceX96_i.mulDiv(sqrtPriceX96Frac_0_9999, Q96);
                tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_9999);
                _test(tc);

                uint256 sqrtPriceX96_i_5001 = sqrtPriceX96_i.mulDiv(sqrtPriceX96Frac_0_5001, Q96);
                tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_5001);
                _test(tc);

                uint256 sqrtPriceX96_i_4999 = sqrtPriceX96_i.mulDiv(sqrtPriceX96Frac_0_4999, Q96);
                tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_4999);
                tc.tickLowerExpected = tickLowerExpected;
                tc.tickUpperExpected = tickUpperExpected;
                _test(tc);

                uint256 sqrtPriceX96_i_0001 = sqrtPriceX96_i.mulDiv(sqrtPriceX96Frac_0_0001, Q96);
                tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_0001);
                _test(tc);

                uint256 sqrtPriceX96_i_near_0 = sqrtPriceX96_i.mulDiv(sqrtPriceX96Frac_near_0, Q96);
                tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_near_0);
                _test(tc);
            }
        }
    }

    function testCalculateTargetOriginaTS_greather_1() external {
        IPulseStrategyModule.StrategyType t = IPulseStrategyModule.StrategyType.Original;

        int24[] memory tickSpacings = new int24[](4);
        tickSpacings[0] = 10;
        tickSpacings[1] = 50;
        tickSpacings[2] = 100;
        tickSpacings[3] = 200;

        for (uint256 j = 0; j < tickSpacings.length; j++) {
            int24 tickSpacing = tickSpacings[j];

            for (int24 i = 1; i <= 10; i++) {
                int24 width = i * tickSpacing;
                TestCase memory tc = TestCase({
                    sqrtPriceX96: 0,
                    tickLower: 200000,
                    tickUpper: 200000 + width,
                    strategyType: t,
                    tickSpacing: tickSpacing,
                    tickNeighborhood: 0,
                    tickLowerExpected: 0,
                    tickUpperExpected: 0
                });
                for (int24 spot = -2 * tickSpacing; spot <= 2 * tickSpacing; spot++) {
                    uint256 sqrtPriceX96_i = TickMath.getSqrtRatioAtTick(spot);

                    int24 tickLowerExpected = (spot / tickSpacing) * tickSpacing;
                    if (spot % tickSpacing != 0) {
                        tickLowerExpected -= (spot < 0 ? tickSpacing : int24(0));
                    }
                    tickLowerExpected -= ((width / tickSpacing) / 2) * tickSpacing;
                    if ((width / tickSpacing) % 2 == 0) {
                        spot = spot < 0 ? -spot : spot;
                        if (spot % tickSpacing >= tickSpacing / 2) {
                            tickLowerExpected += tickSpacing;
                        }
                    }
                    int24 tickUpperExpected = tickLowerExpected + width;

                    uint256 sqrtPriceX96_i_near_1 =
                        sqrtPriceX96_i.mulDiv(sqrtPriceX96Frac_near_1, Q96);
                    tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_near_1);
                    tc.tickLowerExpected = tickLowerExpected;
                    tc.tickUpperExpected = tickUpperExpected;
                    _test(tc);

                    uint256 sqrtPriceX96_i_9999 =
                        sqrtPriceX96_i.mulDiv(sqrtPriceX96Frac_0_9999, Q96);
                    tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_9999);
                    _test(tc);

                    uint256 sqrtPriceX96_i_5001 =
                        sqrtPriceX96_i.mulDiv(sqrtPriceX96Frac_0_5001, Q96);
                    tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_5001);
                    _test(tc);

                    uint256 sqrtPriceX96_i_4999 =
                        sqrtPriceX96_i.mulDiv(sqrtPriceX96Frac_0_4999, Q96);
                    tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_4999);
                    tc.tickLowerExpected = tickLowerExpected;
                    tc.tickUpperExpected = tickUpperExpected;
                    _test(tc);

                    uint256 sqrtPriceX96_i_0001 =
                        sqrtPriceX96_i.mulDiv(sqrtPriceX96Frac_0_0001, Q96);
                    tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_0001);
                    _test(tc);

                    uint256 sqrtPriceX96_i_near_0 =
                        sqrtPriceX96_i.mulDiv(sqrtPriceX96Frac_near_0, Q96);
                    tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_near_0);
                    _test(tc);
                }
            }
        }
    }

    function testCalculateTargetLazyDescendingFuzz(
        int24 spot,
        int24 tickLower,
        uint16 tickSpacing,
        uint16 width
    ) external {
        vm.assume(tickSpacing > 0 && tickSpacing < 300);
        vm.assume(width > 0);
        vm.assume(
            tickLower > TickMath.MIN_TICK && tickLower < TickMath.MAX_TICK - int24(uint24(width))
        );
        vm.assume(spot > TickMath.MIN_TICK && spot < TickMath.MAX_TICK);

        int24 tickSpacing24 = int24(uint24(tickSpacing));
        int24 width24 = int24(uint24(width));

        tickLower = (tickLower / tickSpacing24) * tickSpacing24;
        width24 = (width24 / tickSpacing24) * tickSpacing24;
        if (width24 == 0) {
            width24 = tickSpacing24;
        }

        _testCalculateTargetLazyDescending(
            sqrtPriceX96Frac_near_0, spot, tickLower, width24, tickSpacing24
        );
        _testCalculateTargetLazyDescending(
            sqrtPriceX96Frac_0_0001, spot, tickLower, width24, tickSpacing24
        );
        _testCalculateTargetLazyDescending(
            sqrtPriceX96Frac_0_4999, spot, tickLower, width24, tickSpacing24
        );
        _testCalculateTargetLazyDescending(
            sqrtPriceX96Frac_0_5001, spot, tickLower, width24, tickSpacing24
        );
        _testCalculateTargetLazyDescending(
            sqrtPriceX96Frac_0_9999, spot, tickLower, width24, tickSpacing24
        );
        _testCalculateTargetLazyDescending(
            sqrtPriceX96Frac_near_1, spot, tickLower, width24, tickSpacing24
        );
    }

    function testCalculateTargetLazyAscendingFuzz(
        int24 spot,
        int24 tickLower,
        uint16 tickSpacing,
        uint16 width
    ) external {
        vm.assume(tickSpacing > 0 && tickSpacing < 300);
        vm.assume(width > 0);
        vm.assume(
            tickLower > TickMath.MIN_TICK && tickLower < TickMath.MAX_TICK - int24(uint24(width))
        );
        vm.assume(spot > TickMath.MIN_TICK && spot < TickMath.MAX_TICK);

        int24 tickSpacing24 = int24(uint24(tickSpacing));
        int24 width24 = int24(uint24(width));

        tickLower = (tickLower / tickSpacing24) * tickSpacing24;
        width24 = (width24 / tickSpacing24) * tickSpacing24;
        if (width24 == 0) {
            width24 = tickSpacing24;
        }

        _testCalculateTargetLazyAscending(
            sqrtPriceX96Frac_near_0, spot, tickLower, width24, tickSpacing24
        );
        _testCalculateTargetLazyAscending(
            sqrtPriceX96Frac_0_0001, spot, tickLower, width24, tickSpacing24
        );
        _testCalculateTargetLazyAscending(
            sqrtPriceX96Frac_0_4999, spot, tickLower, width24, tickSpacing24
        );
        _testCalculateTargetLazyAscending(
            sqrtPriceX96Frac_0_5001, spot, tickLower, width24, tickSpacing24
        );
        _testCalculateTargetLazyAscending(
            sqrtPriceX96Frac_0_9999, spot, tickLower, width24, tickSpacing24
        );
        _testCalculateTargetLazyAscending(
            sqrtPriceX96Frac_near_1, spot, tickLower, width24, tickSpacing24
        );
    }

    function testCalculateTargetLazySyncingFuzz(
        int24 spot,
        int24 tickLower,
        uint16 tickSpacing,
        uint16 width
    ) external {
        vm.assume(tickSpacing > 0 && tickSpacing < 300);
        vm.assume(width > 0);
        vm.assume(
            tickLower > TickMath.MIN_TICK && tickLower < TickMath.MAX_TICK - int24(uint24(width))
        );
        vm.assume(spot > TickMath.MIN_TICK && spot < TickMath.MAX_TICK);

        int24 tickSpacing24 = int24(uint24(tickSpacing));
        int24 width24 = int24(uint24(width));

        tickLower = (tickLower / tickSpacing24) * tickSpacing24;
        width24 = (width24 / tickSpacing24) * tickSpacing24;
        if (width24 == 0) {
            width24 = tickSpacing24;
        }

        _testCalculateTargetLazySyncing(
            sqrtPriceX96Frac_near_0, spot, tickLower, width24, tickSpacing24
        );
        _testCalculateTargetLazySyncing(
            sqrtPriceX96Frac_0_0001, spot, tickLower, width24, tickSpacing24
        );
        _testCalculateTargetLazySyncing(
            sqrtPriceX96Frac_0_4999, spot, tickLower, width24, tickSpacing24
        );
        _testCalculateTargetLazySyncing(
            sqrtPriceX96Frac_0_5001, spot, tickLower, width24, tickSpacing24
        );
        _testCalculateTargetLazySyncing(
            sqrtPriceX96Frac_0_9999, spot, tickLower, width24, tickSpacing24
        );
        _testCalculateTargetLazySyncing(
            sqrtPriceX96Frac_near_1, spot, tickLower, width24, tickSpacing24
        );
    }

    function _testCalculateTargetLazyAscending(
        uint160 sqrtPriceX96Frac,
        int24 spot,
        int24 tickLower,
        int24 width,
        int24 tickSpacing
    ) internal {
        IPulseStrategyModule.StrategyType t = IPulseStrategyModule.StrategyType.LazyAscending;

        uint256 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(spot);
        sqrtPriceX96 = sqrtPriceX96.mulDiv(sqrtPriceX96Frac, Q96);
        int24 tickUpper = tickLower + width;

        TestCase memory tc = TestCase({
            sqrtPriceX96: uint160(sqrtPriceX96),
            tickLower: tickLower,
            tickUpper: tickUpper,
            strategyType: t,
            tickSpacing: tickSpacing,
            tickNeighborhood: 0,
            tickLowerExpected: 0,
            tickUpperExpected: 0
        });

        uint160 sqrtPriceX96Upper = TickMath.getSqrtRatioAtTick(tickUpper);

        if (sqrtPriceX96 <= sqrtPriceX96Upper) {
            tc.tickUpperExpected = 0;
            tc.tickLowerExpected = 0;
        }
        if (sqrtPriceX96 > sqrtPriceX96Upper) {
            if (TickMath.getSqrtRatioAtTick(spot) == sqrtPriceX96 && spot % tickSpacing == 0) {
                tc.tickUpperExpected = spot;
            } else {
                tc.tickUpperExpected = (spot / tickSpacing) * tickSpacing;
                if (spot < 0 && spot % tickSpacing != 0) {
                    tc.tickUpperExpected -= tickSpacing;
                }
            }
            tc.tickLowerExpected = tc.tickUpperExpected - width;
            if (tc.tickLowerExpected == tickLower) {
                tc.tickUpperExpected = 0;
                tc.tickLowerExpected = 0;
            }
        }
        _test(tc);
    }

    function _testCalculateTargetLazyDescending(
        uint160 sqrtPriceX96Frac,
        int24 spot,
        int24 tickLower,
        int24 width,
        int24 tickSpacing
    ) internal {
        IPulseStrategyModule.StrategyType t = IPulseStrategyModule.StrategyType.LazyDescending;

        uint256 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(spot);
        sqrtPriceX96 = sqrtPriceX96.mulDiv(sqrtPriceX96Frac, Q96);
        int24 tickUpper = tickLower + width;

        TestCase memory tc = TestCase({
            sqrtPriceX96: uint160(sqrtPriceX96),
            tickLower: tickLower,
            tickUpper: tickUpper,
            strategyType: t,
            tickSpacing: tickSpacing,
            tickNeighborhood: 0,
            tickLowerExpected: 0,
            tickUpperExpected: 0
        });

        uint160 sqrtPriceX96Lower = TickMath.getSqrtRatioAtTick(tickLower);

        if (sqrtPriceX96 >= sqrtPriceX96Lower) {
            tc.tickUpperExpected = 0;
            tc.tickLowerExpected = 0;
        }
        if (sqrtPriceX96 < sqrtPriceX96Lower) {
            if (TickMath.getSqrtRatioAtTick(spot) == sqrtPriceX96 && spot % tickSpacing == 0) {
                tc.tickLowerExpected = spot;
            } else {
                tc.tickLowerExpected = (spot / tickSpacing + 1) * tickSpacing;
                if (spot < 0 && spot % tickSpacing != 0) {
                    tc.tickLowerExpected -= tickSpacing;
                }
            }
            tc.tickUpperExpected = tc.tickLowerExpected + width;
            if (tc.tickUpperExpected == tickUpper) {
                tc.tickUpperExpected = 0;
                tc.tickLowerExpected = 0;
            }
        }
        _test(tc);
    }

    function _testCalculateTargetLazySyncing(
        uint160 sqrtPriceX96Frac,
        int24 spot,
        int24 tickLower,
        int24 width,
        int24 tickSpacing
    ) internal {
        IPulseStrategyModule.StrategyType t = IPulseStrategyModule.StrategyType.LazySyncing;

        uint256 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(spot);
        sqrtPriceX96 = sqrtPriceX96.mulDiv(sqrtPriceX96Frac, Q96);
        int24 tickUpper = tickLower + width;

        TestCase memory tc = TestCase({
            sqrtPriceX96: uint160(sqrtPriceX96),
            tickLower: tickLower,
            tickUpper: tickUpper,
            strategyType: t,
            tickSpacing: tickSpacing,
            tickNeighborhood: 0,
            tickLowerExpected: 0,
            tickUpperExpected: 0
        });

        uint160 sqrtPriceX96Lower = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceX96Upper = TickMath.getSqrtRatioAtTick(tickUpper);

        if (sqrtPriceX96 >= sqrtPriceX96Lower && sqrtPriceX96 <= sqrtPriceX96Upper) {
            tc.tickUpperExpected = 0;
            tc.tickLowerExpected = 0;
        }

        if (sqrtPriceX96 < sqrtPriceX96Lower) {
            if (TickMath.getSqrtRatioAtTick(spot) == sqrtPriceX96 && spot % tickSpacing == 0) {
                tc.tickLowerExpected = spot;
            } else {
                tc.tickLowerExpected = (spot / tickSpacing + 1) * tickSpacing;
                if (spot < 0 && spot % tickSpacing != 0) {
                    tc.tickLowerExpected -= tickSpacing;
                }
            }
            tc.tickUpperExpected = tc.tickLowerExpected + width;
            if (tc.tickUpperExpected == tickUpper) {
                tc.tickUpperExpected = 0;
                tc.tickLowerExpected = 0;
            }
        }
        if (sqrtPriceX96 > sqrtPriceX96Upper) {
            if (TickMath.getSqrtRatioAtTick(spot) == sqrtPriceX96 && spot % tickSpacing == 0) {
                tc.tickUpperExpected = spot;
            } else {
                tc.tickUpperExpected = (spot / tickSpacing) * tickSpacing;
                if (spot < 0 && spot % tickSpacing != 0) {
                    tc.tickUpperExpected -= tickSpacing;
                }
            }
            tc.tickLowerExpected = tc.tickUpperExpected - width;
            if (tc.tickLowerExpected == tickLower) {
                tc.tickUpperExpected = 0;
                tc.tickLowerExpected = 0;
            }
        }
        _test(tc);
    }
}

contract PulseStrategyModuleTamperTest is Fixture {
    using SafeERC20 for IERC20;
    using Math for uint256;

    struct TestCase {
        uint160 sqrtPriceX96;
        int24 tickSpacing;
        int24 tickNeighborhood;
        uint256 maxLiquidityRatioDeviationX96;
        int24[2] tickLower;
        int24[2] tickUpper;
        uint128[2] liquidity;
        uint256[2] liquidityRatiosX96;
        int24[2] tickLowerExpected;
        int24[2] tickUpperExpected;
    }

    PulseStrategyModule public pulseStrategyModule = new PulseStrategyModule();

    address token0 = Constants.OPTIMISM_WETH;
    address token1 = Constants.OPTIMISM_OP;

    uint160 sqrtPriceX96Frac_0_0001 = 79228162910385345434860427129; // 1.0001^(0.0001/2) * Q96

    int24[5] ts;

    constructor() {
        ts[0] = 1;
        ts[1] = 10;
        ts[2] = 50;
        ts[3] = 100;
        ts[4] = 200;
    }

    function _test(TestCase memory tc) private {
        int24 width = tc.tickUpper[0] - tc.tickLower[0];
        int24 spotTick = TickMath.getTickAtSqrtRatio(tc.sqrtPriceX96);
        IPulseStrategyModule.StrategyParams memory params = IPulseStrategyModule.StrategyParams({
            strategyType: IPulseStrategyModule.StrategyType.Tamper,
            tickSpacing: tc.tickSpacing,
            tickNeighborhood: tc.tickNeighborhood,
            width: width,
            maxLiquidityRatioDeviationX96: tc.maxLiquidityRatioDeviationX96
        });

        IAmmModule.AmmPosition[] memory positions = new IAmmModule.AmmPosition[](2);
        positions[0] = IAmmModule.AmmPosition({
            token0: token0,
            token1: token1,
            property: uint24(tc.tickSpacing),
            tickLower: tc.tickLower[0],
            tickUpper: tc.tickUpper[0],
            liquidity: tc.liquidity[0]
        });
        positions[1] = IAmmModule.AmmPosition({
            token0: token0,
            token1: token1,
            property: uint24(tc.tickSpacing),
            tickLower: tc.tickLower[1],
            tickUpper: tc.tickUpper[1],
            liquidity: tc.liquidity[1]
        });

        (bool isRebalanceRequired, ICore.TargetPositionInfo memory target) =
            pulseStrategyModule.calculateTargetTamper(tc.sqrtPriceX96, spotTick, positions, params);

        if (isRebalanceRequired) {
            assertEq(target.lowerTicks.length, 2);
            assertEq(target.upperTicks.length, 2);
            assertEq(target.liquidityRatiosX96.length, 2);
            assertEq(target.liquidityRatiosX96.length, 2);
            assertEq(target.liquidityRatiosX96[0] + target.liquidityRatiosX96[1], Q96);
            for (uint256 i = 0; i < 2; i++) {
                assertEq(target.liquidityRatiosX96[i], tc.liquidityRatiosX96[i]);
                assertTrue(target.upperTicks[i] % params.tickSpacing == 0);
                assertTrue(target.lowerTicks[i] % params.tickSpacing == 0);
                assertEq(target.upperTicks[i] - target.lowerTicks[i], params.width);
                assertEq(tc.tickLowerExpected[i], target.lowerTicks[i]);
                assertEq(tc.tickUpperExpected[i], target.upperTicks[i]);
            }
        } else {
            assertEq(target.lowerTicks.length, 0);
            assertEq(target.upperTicks.length, 0);
            assertEq(target.liquidityRatiosX96.length, 0);
        }
    }

    function ratio(uint160 sqrtPriceX96, int24 targetLower, int24 width)
        internal
        pure
        returns (uint256 lowerLiquidityRatioX96)
    {
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        uint160 sqrtRatioAtTick = TickMath.getSqrtRatioAtTick(tick);
        uint160 sqrtRatioAtNextTick = TickMath.getSqrtRatioAtTick(tick + 1);
        int256 preciseTickX96 = int256(tick) * int256(Q96)
            + int256(
                Math.mulDiv(
                    Q96,
                    sqrtPriceX96 - sqrtRatioAtTick,
                    sqrtRatioAtNextTick - sqrtRatioAtTick,
                    Math.Rounding.Floor
                )
            );
        uint256 deduction = Math.ceilDiv(
            uint256(preciseTickX96 - targetLower * int256(Q96)), uint24(width / 2)
        ) - Q96;
        lowerLiquidityRatioX96 = Q96 - Math.min(Q96, deduction);
    }

    /// @dev test cases when rebalancing does not need at all
    function testNoRebalancePosition() external {
        TestCase memory tc;

        tc.maxLiquidityRatioDeviationX96 = Q96;

        for (uint256 k = 0; k < ts.length; k++) {
            tc.tickSpacing = ts[k];
            for (int24 w = 1; w < 10; w++) {
                int24 width = tc.tickSpacing * w * 2;
                int24 tickLower = width / 2;
                tc.tickLower[0] = tickLower;
                tc.tickUpper[0] = tickLower + width;
                tc.tickLower[1] = tc.tickLower[0] + width / 2;
                tc.tickUpper[1] = tc.tickUpper[0] + width / 2;
                tc.tickNeighborhood = 0;
                tc.liquidity[0] = 10 ** 20;
                tc.liquidity[1] = 10 ** 20;
                tc.tickLowerExpected = tc.tickLower;
                tc.tickUpperExpected = tc.tickUpper;
                for (int24 tick = tc.tickLower[1] + 1; tick < tc.tickUpper[0]; tick++) {
                    tc.sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
                    _test(tc);
                }
            }
        }
    }

    /// @dev test cases when rebalancing does not need due to liquidity ratio satisfaction
    function testNoRebalanceRatio() external {
        TestCase memory tc;
        tc.maxLiquidityRatioDeviationX96 = Q96 / 100;
        uint128 liquidity0 = 10 ** 20;

        for (uint256 k = 0; k < ts.length; k++) {
            tc.tickSpacing = ts[k];
            for (int24 w = 1; w < 10; w++) {
                int24 width = tc.tickSpacing * 2;
                int24 tickLower = width / 2;
                tc.tickLower[0] = tickLower;
                tc.tickUpper[0] = tickLower + width;
                tc.tickLower[1] = tc.tickLower[0] + width / 2;
                tc.tickUpper[1] = tc.tickUpper[0] + width / 2;
                tc.sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tc.tickLower[1] + 1);

                for (int24 tick = tc.tickLower[1] + 1; tick < tc.tickUpper[0]; tick++) {
                    tc.sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
                    uint256 r = ratio(tc.sqrtPriceX96, tc.tickLower[0], width);
                    tc.liquidity[0] = uint128(uint256(liquidity0).mulDiv(r, Q96));
                    tc.liquidity[1] = uint128(uint256(liquidity0).mulDiv(Q96 - r, Q96));
                    _test(tc);
                }
            }
        }
    }

    /// @dev test cases when rebalancing needs for ranges
    function testRebalanceRanges() external {
        TestCase memory tc;
        tc.maxLiquidityRatioDeviationX96 = Q96 / 100;
        uint128 liquidity0 = 10 ** 20;

        for (uint256 k = 0; k < ts.length; k++) {
            tc.tickSpacing = ts[k];
            for (int24 w = 1; w < 2; w++) {
                int24 width = tc.tickSpacing * 2;
                int24 tickLower = width / 2;
                tc.tickLower[0] = tickLower;
                tc.tickUpper[0] = tickLower + width;
                tc.tickLower[1] = tc.tickLower[0] + width / 2;
                tc.tickUpper[1] = tc.tickUpper[0] + width / 2;
                tc.sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tc.tickLower[1] + 1);

                tc.tickLowerExpected = tc.tickLower;
                tc.tickUpperExpected = tc.tickUpper;

                for (int24 tick = tc.tickLower[1] + 1; tick < tc.tickUpper[0]; tick++) {
                    tc.sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
                    tc.liquidity[0] = liquidity0 / 2;
                    tc.liquidity[1] = liquidity0 / 2;
                    uint256 r = ratio(tc.sqrtPriceX96, tc.tickLower[0], width);
                    tc.liquidityRatiosX96[0] = r;
                    tc.liquidityRatiosX96[1] = Q96 - r;
                    _test(tc);
                }
            }
        }
    }

    /// @dev test cases when rebalancing needs just for liquidity relation, not for ranges
    function testRebalanceLiquidity() external {
        TestCase memory tc;
        tc.maxLiquidityRatioDeviationX96 = Q96 / 100;
        uint128 liquidity0 = 10 ** 20;

        for (uint256 k = 0; k < ts.length; k++) {
            tc.tickSpacing = ts[k];
            for (int24 w = 1; w < 2; w++) {
                int24 width = tc.tickSpacing * 2;
                int24 tickLower = width / 2;
                tc.tickLower[0] = tickLower;
                tc.tickUpper[0] = tickLower + width;
                tc.tickLower[1] = tc.tickLower[0] + width / 2;
                tc.tickUpper[1] = tc.tickUpper[0] + width / 2;
                tc.sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tc.tickLower[1] + 1);

                tc.tickLowerExpected = tc.tickLower;
                tc.tickUpperExpected = tc.tickUpper;

                for (int24 tick = tc.tickLower[1] + 1; tick < tc.tickUpper[0]; tick++) {
                    tc.sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
                    tc.liquidity[0] = liquidity0 / 2;
                    tc.liquidity[1] = liquidity0 / 2;
                    uint256 r = ratio(tc.sqrtPriceX96, tc.tickLower[0], width);
                    tc.liquidityRatiosX96[0] = r;
                    tc.liquidityRatiosX96[1] = Q96 - r;
                    _test(tc);
                }
            }
        }
    }

    /// @dev test cases when rebalancing needs just for liquidity relation, not for ranges
    function testRebalancePosition() external {
        TestCase memory tc;
        tc.maxLiquidityRatioDeviationX96 = Q96 / 100;
        uint128 liquidity0 = 10 ** 20;

        for (uint256 k = 0; k < ts.length; k++) {
            tc.tickSpacing = ts[k];
            int24 width = tc.tickSpacing * 2;
            int24 tickLower = width / 2;
            tc.tickLower[0] = tickLower;
            tc.tickUpper[0] = tickLower + width;
            tc.tickLower[1] = tc.tickLower[0] + width / 2;
            tc.tickUpper[1] = tc.tickUpper[0] + width / 2;
            tc.sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tc.tickLower[1] + 1);

            tc.liquidity[0] = liquidity0 / 2;
            tc.liquidity[1] = liquidity0 / 2;

            /// @notice loop (tickLower[0]; tickLower[1])
            for (int24 tick = tc.tickLower[0]; tick < tc.tickLower[1]; tick++) {
                tc.sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
                tc.sqrtPriceX96 =
                    uint160(uint256(tc.sqrtPriceX96).mulDiv(sqrtPriceX96Frac_0_0001, Q96));

                tc.tickLowerExpected[0] = tc.tickLower[0] - width / 2;
                tc.tickLowerExpected[1] = tc.tickLower[1] - width / 2;
                tc.tickUpperExpected[0] = tc.tickUpper[0] - width / 2;
                tc.tickUpperExpected[1] = tc.tickUpper[1] - width / 2;

                uint256 r = ratio(tc.sqrtPriceX96, tc.tickLowerExpected[0], width);
                tc.liquidityRatiosX96[0] = r;
                tc.liquidityRatiosX96[1] = Q96 - r;

                _test(tc);
            }

            /// @notice loop (tickUpper[0]; tickUpper[1])
            for (int24 tick = tc.tickUpper[0]; tick < tc.tickUpper[1]; tick++) {
                tc.sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
                tc.sqrtPriceX96 =
                    uint160(uint256(tc.sqrtPriceX96).mulDiv(sqrtPriceX96Frac_0_0001, Q96));

                tc.tickLowerExpected[0] = tc.tickLower[0] + width / 2;
                tc.tickLowerExpected[1] = tc.tickLower[1] + width / 2;
                tc.tickUpperExpected[0] = tc.tickUpper[0] + width / 2;
                tc.tickUpperExpected[1] = tc.tickUpper[1] + width / 2;

                uint256 r = ratio(tc.sqrtPriceX96, tc.tickLowerExpected[0], width);
                tc.liquidityRatiosX96[0] = r;
                tc.liquidityRatiosX96[1] = Q96 - r;

                _test(tc);
            }
        }
    }
}
