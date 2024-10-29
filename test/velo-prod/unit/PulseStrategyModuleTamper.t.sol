// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

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

    address token0 = Constants.WETH;
    address token1 = Constants.OP;

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

        (bool isRebalanceRequired, ICore.TargetPositionInfo memory target) = pulseStrategyModule
            .calculateTargetTamper(
            tc.sqrtPriceX96,
            spotTick,
            IAmmModule.AmmPosition({
                token0: token0,
                token1: token1,
                property: uint24(tc.tickSpacing),
                tickLower: tc.tickLower[0],
                tickUpper: tc.tickUpper[0],
                liquidity: tc.liquidity[0]
            }),
            IAmmModule.AmmPosition({
                token0: token0,
                token1: token1,
                property: uint24(tc.tickSpacing),
                tickLower: tc.tickLower[1],
                tickUpper: tc.tickUpper[1],
                liquidity: tc.liquidity[1]
            }),
            params
        );

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
                    Math.Rounding.Up
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
