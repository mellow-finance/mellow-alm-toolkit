// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    PulseStrategyModule public pulseStrategyModule = new PulseStrategyModule();

    function _max(int24 a, int24 b) private pure returns (int24) {
        if (a < b) return b;
        return a;
    }

    function _min(int24 a, int24 b) private pure returns (int24) {
        if (a > b) return b;
        return a;
    }

    function _abs(int24 a) private pure returns (int24) {
        if (a < 0) return -a;
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
            tickLower + params.tickNeighborhood <= spotTick &&
            tickUpper - params.tickNeighborhood >= spotTick &&
            tickUpper - tickLower == params.width
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

        int24 currentPenalty = _max(
            _abs(spotTick - target.lowerTicks[0]),
            _abs(spotTick - target.upperTicks[0])
        );

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
            params.width != tickUpper - tickLower ||
            params.strategyType == IPulseStrategyModule.StrategyType.Original
        ) {
            return
                _validateOriginal(
                    spotTick,
                    tickLower,
                    tickUpper,
                    params,
                    flag,
                    target
                );
        }

        if (
            params.strategyType ==
            IPulseStrategyModule.StrategyType.LazyAscending
        ) {
            if (tickUpper + params.tickSpacing > spotTick) {
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
            assertTrue(target.upperTicks[0] <= spotTick);
            assertTrue(spotTick - target.upperTicks[0] < params.tickSpacing);
            return;
        }

        if (
            params.strategyType ==
            IPulseStrategyModule.StrategyType.LazyDescending
        ) {
            if (tickLower - params.tickSpacing < spotTick) {
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
            assertTrue(target.lowerTicks[0] >= spotTick);
            assertTrue(target.lowerTicks[0] - spotTick < params.tickSpacing);
            return;
        }

        if (
            params.strategyType == IPulseStrategyModule.StrategyType.LazySyncing
        ) {
            if (
                tickLower - params.tickSpacing < spotTick &&
                tickUpper + params.tickSpacing > spotTick
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

            assertTrue(target.lowerTicks[0] - params.tickSpacing < spotTick);
            assertTrue(target.upperTicks[0] + params.tickSpacing > spotTick);

            assertTrue(
                _min(
                    _abs(spotTick - target.lowerTicks[0]),
                    _abs(spotTick - target.upperTicks[0])
                ) < params.tickSpacing
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
        IPulseStrategyModule.StrategyParams memory params = IPulseStrategyModule
            .StrategyParams({
                strategyType: strategyType,
                tickSpacing: tickSpacing,
                tickNeighborhood: tickNeighborhood,
                width: width
            });
        (
            bool isRebalanceRequired,
            ICore.TargetPositionInfo memory target
        ) = pulseStrategyModule.calculateTarget(
                spotTick,
                tickLower,
                tickUpper,
                params
            );

        _validate(
            spotTick,
            tickLower,
            tickUpper,
            params,
            isRebalanceRequired,
            target
        );
    }

    function testCalculateTargetOriginal() external {
        IPulseStrategyModule.StrategyType t = IPulseStrategyModule
            .StrategyType
            .Original;
        for (int24 spot = -200; spot <= 200; spot++) {
            _test(spot, -100, 200, t, 100, 50, 300);
        }
        _test(23, -100, 200, t, 100, 50, 200);
        _test(-49, -100, 0, t, 100, 25, 200);
        _test(-51, -100, 0, t, 100, 25, 200);
    }

    function testCalculateTargetLazyAscending() external {
        IPulseStrategyModule.StrategyType t = IPulseStrategyModule
            .StrategyType
            .LazyAscending;
        for (int24 spot = -200; spot <= 200; spot++) {
            _test(spot, -100, 200, t, 100, 0, 300);
        }
        _test(23, -100, 200, t, 100, 0, 200);
        _test(-49, -100, 0, t, 100, 0, 200);
        _test(-51, -100, 0, t, 100, 0, 200);
    }

    function testCalculateTargetLazyDescending() external {
        IPulseStrategyModule.StrategyType t = IPulseStrategyModule
            .StrategyType
            .LazyDescending;
        for (int24 spot = -200; spot <= 200; spot++) {
            _test(spot, -100, 200, t, 100, 0, 300);
        }
        _test(23, -100, 200, t, 100, 0, 200);
        _test(-49, -100, 0, t, 100, 0, 200);
        _test(-51, -100, 0, t, 100, 0, 200);
    }

    function testCalculateTargetLazySyncing() external {
        IPulseStrategyModule.StrategyType t = IPulseStrategyModule
            .StrategyType
            .LazySyncing;
        for (int24 spot = -200; spot <= 200; spot++) {
            _test(spot, -100, 200, t, 100, 0, 300);
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
                    width: 300
                })
            )
        );
        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Original,
                    tickSpacing: 1,
                    tickNeighborhood: 0,
                    width: 1
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
                    width: 0
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
                    width: 1
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
                    width: 1
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
                    width: 3
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
                    width: 1
                })
            )
        );

        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Original,
                    tickSpacing: 1,
                    tickNeighborhood: 1,
                    width: 2
                })
            )
        );

        pulseStrategyModule.validateStrategyParams(
            abi.encode(
                IPulseStrategyModule.StrategyParams({
                    strategyType: IPulseStrategyModule.StrategyType.Original,
                    tickSpacing: 50,
                    tickNeighborhood: 200,
                    width: 4200
                })
            )
        );
    }

    function testGetTargets() external {
        ICore.ManagedPositionInfo memory info;
        info.ammPositionIds = new uint256[](2);

        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        pulseStrategyModule.getTargets(
            info,
            IAmmModule(address(0)),
            IOracle(address(0))
        );

        ICLPool pool = ICLPool(
            factory.getPool(Constants.WETH, Constants.OP, 200)
        );
        pool.increaseObservationCardinalityNext(2);
        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool
        );

        info.ammPositionIds = new uint256[](1);
        info.ammPositionIds[0] = tokenId;
        info.pool = address(pool);
        info.strategyParams = abi.encode(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.Original,
                tickSpacing: pool.tickSpacing(),
                tickNeighborhood: 50,
                width: 300
            })
        );

        VeloAmmModule ammModule = new VeloAmmModule(
            INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER),
            Constants.SELECTOR_IS_POOL
        );

        VeloOracle oracle = new VeloOracle();

        (
            bool isRebalanceRequired,
            ICore.TargetPositionInfo memory target
        ) = pulseStrategyModule.getTargets(info, ammModule, oracle);

        assertTrue(isRebalanceRequired);
        assertEq(target.lowerTicks.length, 1);
        assertEq(target.upperTicks.length, 1);
        assertEq(target.liquidityRatiosX96.length, 1);
        assertEq(target.upperTicks[0] - target.lowerTicks[0], 300);
    }
}
