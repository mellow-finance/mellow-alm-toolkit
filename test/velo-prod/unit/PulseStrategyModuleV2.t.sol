// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract PulseStrategyModuleV2Test is Fixture {
    using SafeERC20 for IERC20;
    using FullMath for uint256;

    struct TestCase {
        uint160 sqrtPriceX96;
        int24 tickLower;
        int24 tickUpper;
        IStrategyModule.StrategyType strategyType;
        int24 tickSpacing;
        int24 tickNeighborhood;
        int24 tickLowerExpected;
        int24 tickUpperExpected;
    }

    PulseStrategyModuleV2 public pulseStrategyModule =
        new PulseStrategyModuleV2();

    uint160 sqrtPriceX96Frac_near_0 = 79228162514264733714550801400; // 1.0001^(1e-10/2) * Q96
    uint160 sqrtPriceX96Frac_0_0001 = 79228162910385345434860427129; // 1.0001^(0.0001/2) * Q96
    uint160 sqrtPriceX96Frac_0_4999 = 79230142747924215822526283666; // 1.0001^(0.4999/2) * Q96
    uint160 sqrtPriceX96Frac_0_5001 = 79230143540186034832312214731; // 1.0001^(0.5001/2) * Q96
    uint160 sqrtPriceX96Frac_0_9999 = 79232123427218987702309994166; // 1.0001^(0.9999/2) * Q96
    uint160 sqrtPriceX96Frac_near_1 = 79232123823359402977474593289; // 1.0001^((1 - 1e-10)/2) * Q96

    function _test(TestCase memory tc) private {
        int24 width = tc.tickUpper - tc.tickLower;
        int24 spotTick = TickMath.getTickAtSqrtRatio(tc.sqrtPriceX96);
        IStrategyModule.StrategyParams memory params = IStrategyModule
            .StrategyParams({
                strategyType: tc.strategyType,
                tickSpacing: tc.tickSpacing,
                tickNeighborhood: tc.tickNeighborhood,
                width: width,
                maxLiquidityRatioDeviationX96: 0
            });
        (, ICore.TargetPositionInfo memory target) = pulseStrategyModule
            .calculateTarget(
                tc.sqrtPriceX96,
                spotTick,
                tc.tickLower,
                tc.tickUpper,
                params
            );

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

    function testCalculateTargetOriginalTS_1() external {
        IStrategyModule.StrategyType t = IStrategyModule
            .StrategyType
            .Original;

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
                if (remainder < 0) remainder += tickSpacing;
                tickLowerExpected -= remainder;
                int24 tickUpperExpected = tickLowerExpected + width;
                if (!(spot >= tickLowerExpected && spot < tickUpperExpected)) {
                    tickLowerExpected += tickSpacing;
                    tickUpperExpected += tickSpacing;
                }

                uint256 sqrtPriceX96_i = TickMath.getSqrtRatioAtTick(spot);

                uint256 sqrtPriceX96_i_near_1 = sqrtPriceX96_i.mulDiv(
                    sqrtPriceX96Frac_near_1,
                    Q96
                );
                tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_near_1);
                tc.tickLowerExpected = tickLowerExpected + shift;
                tc.tickUpperExpected = tickUpperExpected + shift;
                _test(tc);

                uint256 sqrtPriceX96_i_9999 = sqrtPriceX96_i.mulDiv(
                    sqrtPriceX96Frac_0_9999,
                    Q96
                );
                tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_9999);
                _test(tc);

                uint256 sqrtPriceX96_i_5001 = sqrtPriceX96_i.mulDiv(
                    sqrtPriceX96Frac_0_5001,
                    Q96
                );
                tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_5001);
                _test(tc);

                uint256 sqrtPriceX96_i_4999 = sqrtPriceX96_i.mulDiv(
                    sqrtPriceX96Frac_0_4999,
                    Q96
                );
                tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_4999);
                tc.tickLowerExpected = tickLowerExpected;
                tc.tickUpperExpected = tickUpperExpected;
                _test(tc);

                uint256 sqrtPriceX96_i_0001 = sqrtPriceX96_i.mulDiv(
                    sqrtPriceX96Frac_0_0001,
                    Q96
                );
                tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_0001);
                _test(tc);

                uint256 sqrtPriceX96_i_near_0 = sqrtPriceX96_i.mulDiv(
                    sqrtPriceX96Frac_near_0,
                    Q96
                );
                tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_near_0);
                _test(tc);
            }
        }
    }

    function testCalculateTargetOriginaTS_greather_1() external {
        IStrategyModule.StrategyType t = IStrategyModule
            .StrategyType
            .Original;

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
                for (
                    int24 spot = -2 * tickSpacing;
                    spot <= 2 * tickSpacing;
                    spot++
                ) {
                    uint256 sqrtPriceX96_i = TickMath.getSqrtRatioAtTick(spot);

                    int24 tickLowerExpected = (spot / tickSpacing) *
                        tickSpacing;
                    if (spot % tickSpacing != 0)
                        tickLowerExpected -= (
                            spot < 0 ? tickSpacing : int24(0)
                        );
                    tickLowerExpected -=
                        ((width / tickSpacing) / 2) *
                        tickSpacing;
                    if ((width / tickSpacing) % 2 == 0) {
                        spot = spot < 0 ? -spot : spot;
                        if (spot % tickSpacing >= tickSpacing / 2)
                            tickLowerExpected += tickSpacing;
                    }
                    int24 tickUpperExpected = tickLowerExpected + width;

                    uint256 sqrtPriceX96_i_near_1 = sqrtPriceX96_i.mulDiv(
                        sqrtPriceX96Frac_near_1,
                        Q96
                    );
                    tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_near_1);
                    tc.tickLowerExpected = tickLowerExpected;
                    tc.tickUpperExpected = tickUpperExpected;
                    _test(tc);

                    uint256 sqrtPriceX96_i_9999 = sqrtPriceX96_i.mulDiv(
                        sqrtPriceX96Frac_0_9999,
                        Q96
                    );
                    tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_9999);
                    _test(tc);

                    uint256 sqrtPriceX96_i_5001 = sqrtPriceX96_i.mulDiv(
                        sqrtPriceX96Frac_0_5001,
                        Q96
                    );
                    tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_5001);
                    _test(tc);

                    uint256 sqrtPriceX96_i_4999 = sqrtPriceX96_i.mulDiv(
                        sqrtPriceX96Frac_0_4999,
                        Q96
                    );
                    tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_4999);
                    tc.tickLowerExpected = tickLowerExpected;
                    tc.tickUpperExpected = tickUpperExpected;
                    _test(tc);

                    uint256 sqrtPriceX96_i_0001 = sqrtPriceX96_i.mulDiv(
                        sqrtPriceX96Frac_0_0001,
                        Q96
                    );
                    tc.sqrtPriceX96 = uint160(sqrtPriceX96_i_0001);
                    _test(tc);

                    uint256 sqrtPriceX96_i_near_0 = sqrtPriceX96_i.mulDiv(
                        sqrtPriceX96Frac_near_0,
                        Q96
                    );
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
            tickLower > TickMath.MIN_TICK &&
                tickLower < TickMath.MAX_TICK - int24(uint24(width))
        );
        vm.assume(spot > TickMath.MIN_TICK && spot < TickMath.MAX_TICK);

        int24 tickSpacing24 = int24(uint24(tickSpacing));
        int24 width24 = int24(uint24(width));

        tickLower = (tickLower / tickSpacing24) * tickSpacing24;
        width24 = (width24 / tickSpacing24) * tickSpacing24;
        if (width24 == 0) width24 = tickSpacing24;

        _testCalculateTargetLazyDescending(
            sqrtPriceX96Frac_near_0,
            spot,
            tickLower,
            width24,
            tickSpacing24
        );
        _testCalculateTargetLazyDescending(
            sqrtPriceX96Frac_0_0001,
            spot,
            tickLower,
            width24,
            tickSpacing24
        );
        _testCalculateTargetLazyDescending(
            sqrtPriceX96Frac_0_4999,
            spot,
            tickLower,
            width24,
            tickSpacing24
        );
        _testCalculateTargetLazyDescending(
            sqrtPriceX96Frac_0_5001,
            spot,
            tickLower,
            width24,
            tickSpacing24
        );
        _testCalculateTargetLazyDescending(
            sqrtPriceX96Frac_0_9999,
            spot,
            tickLower,
            width24,
            tickSpacing24
        );
        _testCalculateTargetLazyDescending(
            sqrtPriceX96Frac_near_1,
            spot,
            tickLower,
            width24,
            tickSpacing24
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
            tickLower > TickMath.MIN_TICK &&
                tickLower < TickMath.MAX_TICK - int24(uint24(width))
        );
        vm.assume(spot > TickMath.MIN_TICK && spot < TickMath.MAX_TICK);

        int24 tickSpacing24 = int24(uint24(tickSpacing));
        int24 width24 = int24(uint24(width));

        tickLower = (tickLower / tickSpacing24) * tickSpacing24;
        width24 = (width24 / tickSpacing24) * tickSpacing24;
        if (width24 == 0) width24 = tickSpacing24;

        _testCalculateTargetLazyAscending(
            sqrtPriceX96Frac_near_0,
            spot,
            tickLower,
            width24,
            tickSpacing24
        );
        _testCalculateTargetLazyAscending(
            sqrtPriceX96Frac_0_0001,
            spot,
            tickLower,
            width24,
            tickSpacing24
        );
        _testCalculateTargetLazyAscending(
            sqrtPriceX96Frac_0_4999,
            spot,
            tickLower,
            width24,
            tickSpacing24
        );
        _testCalculateTargetLazyAscending(
            sqrtPriceX96Frac_0_5001,
            spot,
            tickLower,
            width24,
            tickSpacing24
        );
        _testCalculateTargetLazyAscending(
            sqrtPriceX96Frac_0_9999,
            spot,
            tickLower,
            width24,
            tickSpacing24
        );
        _testCalculateTargetLazyAscending(
            sqrtPriceX96Frac_near_1,
            spot,
            tickLower,
            width24,
            tickSpacing24
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
            tickLower > TickMath.MIN_TICK &&
                tickLower < TickMath.MAX_TICK - int24(uint24(width))
        );
        vm.assume(spot > TickMath.MIN_TICK && spot < TickMath.MAX_TICK);

        int24 tickSpacing24 = int24(uint24(tickSpacing));
        int24 width24 = int24(uint24(width));

        tickLower = (tickLower / tickSpacing24) * tickSpacing24;
        width24 = (width24 / tickSpacing24) * tickSpacing24;
        if (width24 == 0) width24 = tickSpacing24;

        _testCalculateTargetLazySyncing(
            sqrtPriceX96Frac_near_0,
            spot,
            tickLower,
            width24,
            tickSpacing24
        );
        _testCalculateTargetLazySyncing(
            sqrtPriceX96Frac_0_0001,
            spot,
            tickLower,
            width24,
            tickSpacing24
        );
        _testCalculateTargetLazySyncing(
            sqrtPriceX96Frac_0_4999,
            spot,
            tickLower,
            width24,
            tickSpacing24
        );
        _testCalculateTargetLazySyncing(
            sqrtPriceX96Frac_0_5001,
            spot,
            tickLower,
            width24,
            tickSpacing24
        );
        _testCalculateTargetLazySyncing(
            sqrtPriceX96Frac_0_9999,
            spot,
            tickLower,
            width24,
            tickSpacing24
        );
        _testCalculateTargetLazySyncing(
            sqrtPriceX96Frac_near_1,
            spot,
            tickLower,
            width24,
            tickSpacing24
        );
    }

    function _testCalculateTargetLazyAscending(
        uint160 sqrtPriceX96Frac,
        int24 spot,
        int24 tickLower,
        int24 width,
        int24 tickSpacing
    ) internal {
        IStrategyModule.StrategyType t = IStrategyModule
            .StrategyType
            .LazyAscending;

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
            if (
                TickMath.getSqrtRatioAtTick(spot) == sqrtPriceX96 &&
                spot % tickSpacing == 0
            ) {
                tc.tickUpperExpected = spot;
            } else {
                tc.tickUpperExpected = (spot / tickSpacing) * tickSpacing;
                if (spot < 0 && spot % tickSpacing != 0)
                    tc.tickUpperExpected -= tickSpacing;
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
        IStrategyModule.StrategyType t = IStrategyModule
            .StrategyType
            .LazyDescending;

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
            if (
                TickMath.getSqrtRatioAtTick(spot) == sqrtPriceX96 &&
                spot % tickSpacing == 0
            ) {
                tc.tickLowerExpected = spot;
            } else {
                tc.tickLowerExpected = (spot / tickSpacing + 1) * tickSpacing;
                if (spot < 0 && spot % tickSpacing != 0)
                    tc.tickLowerExpected -= tickSpacing;
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
        IStrategyModule.StrategyType t = IStrategyModule
            .StrategyType
            .LazySyncing;

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

        if (
            sqrtPriceX96 >= sqrtPriceX96Lower &&
            sqrtPriceX96 <= sqrtPriceX96Upper
        ) {
            tc.tickUpperExpected = 0;
            tc.tickLowerExpected = 0;
        }

        if (sqrtPriceX96 < sqrtPriceX96Lower) {
            if (
                TickMath.getSqrtRatioAtTick(spot) == sqrtPriceX96 &&
                spot % tickSpacing == 0
            ) {
                tc.tickLowerExpected = spot;
            } else {
                tc.tickLowerExpected = (spot / tickSpacing + 1) * tickSpacing;
                if (spot < 0 && spot % tickSpacing != 0)
                    tc.tickLowerExpected -= tickSpacing;
            }
            tc.tickUpperExpected = tc.tickLowerExpected + width;
            if (tc.tickUpperExpected == tickUpper) {
                tc.tickUpperExpected = 0;
                tc.tickLowerExpected = 0;
            }
        }
        if (sqrtPriceX96 > sqrtPriceX96Upper) {
            if (
                TickMath.getSqrtRatioAtTick(spot) == sqrtPriceX96 &&
                spot % tickSpacing == 0
            ) {
                tc.tickUpperExpected = spot;
            } else {
                tc.tickUpperExpected = (spot / tickSpacing) * tickSpacing;
                if (spot < 0 && spot % tickSpacing != 0)
                    tc.tickUpperExpected -= tickSpacing;
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
