// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    VeloOracle public oracle;

    function testConstructor() external {
        oracle = new VeloOracle();
        assertTrue(address(oracle) != address(0));
    }

    function testValidateSecurityParams() external {
        oracle = new VeloOracle();
        IOracle.SecurityParams memory params = IOracle.SecurityParams({
            lookback: 0,
            maxAllowedDelta: 0,
            maxAge: 7 days
        });

        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        oracle.validateSecurityParams(params);
        params.lookback = 1;
        oracle.validateSecurityParams(params);
        params.maxAllowedDelta = -1;

        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        oracle.validateSecurityParams(params);
        // vm.expectRevert();
        // oracle.validateSecurityParams("random string");
    }

    function testEnsureNoMEV() external {
        oracle = new VeloOracle();
        ICLPool pool = ICLPool(
            factory.getPool(Constants.WETH, Constants.OP, 200)
        );
        assertEq(pool.tickSpacing(), 200);
        oracle.ensureNoMEV(
            address(pool),
            IOracle.SecurityParams({
                lookback: 0,
                maxAllowedDelta: 0,
                maxAge: 7 days
            })
        );
        oracle.ensureNoMEV(
            address(pool),
            IOracle.SecurityParams({lookback: 0, maxAllowedDelta: 0, maxAge: 0})
        );
        vm.expectRevert();
        oracle.ensureNoMEV(
            address(0),
            IOracle.SecurityParams({
                lookback: 0,
                maxAllowedDelta: 0,
                maxAge: 7 days
            })
        );
        vm.expectRevert(abi.encodeWithSignature("NotEnoughObservations()"));
        oracle.ensureNoMEV(
            address(pool),
            IOracle.SecurityParams({
                lookback: 1,
                maxAllowedDelta: 0,
                maxAge: 7 days
            })
        );
        pool.increaseObservationCardinalityNext(2);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughObservations()"));
        oracle.ensureNoMEV(
            address(pool),
            IOracle.SecurityParams({
                lookback: 1,
                maxAllowedDelta: 0,
                maxAge: 7 days
            })
        );
        mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            1000000,
            pool
        );
        oracle.ensureNoMEV(
            address(pool),
            IOracle.SecurityParams({
                lookback: 1,
                maxAllowedDelta: 0,
                maxAge: 7 days
            })
        );
        vm.expectRevert(abi.encodeWithSignature("PriceManipulationDetected()"));
        oracle.ensureNoMEV(
            address(pool),
            IOracle.SecurityParams({
                lookback: 1,
                maxAllowedDelta: -1,
                maxAge: 7 days
            })
        );
        vm.expectRevert(abi.encodeWithSignature("NotEnoughObservations()"));
        oracle.ensureNoMEV(
            address(pool),
            IOracle.SecurityParams({
                lookback: 2,
                maxAllowedDelta: 0,
                maxAge: 7 days
            })
        );
        vm.startPrank(Constants.DEPLOYER);
        (, int24 spotTick, , , , ) = pool.slot0();
        movePrice(spotTick + 100, pool);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSignature("PriceManipulationDetected()"));
        oracle.ensureNoMEV(
            address(pool),
            IOracle.SecurityParams({
                lookback: 1,
                maxAllowedDelta: 0,
                maxAge: 7 days
            })
        );
    }

    function testGetOraclePrice() external {
        oracle = new VeloOracle();
        ICLPool pool = ICLPool(
            factory.getPool(Constants.WETH, Constants.OP, 200)
        );

        oracle.getOraclePrice(address(pool));

        pool.increaseObservationCardinalityNext(2);
        mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            1000000,
            pool
        );

        (, int24 spotTick, , , , ) = pool.slot0();

        vm.startPrank(Constants.DEPLOYER);
        movePrice(spotTick, pool);
        vm.stopPrank();
        {
            (, int24 tick) = oracle.getOraclePrice(address(pool));
            assertEq(tick, spotTick);
        }
        vm.startPrank(Constants.DEPLOYER);
        movePrice(spotTick + 100, pool);
        vm.stopPrank();
        {
            (uint160 sqrtPriceX96, int24 tick) = oracle.getOraclePrice(
                address(pool)
            );
            assertEq(tick, spotTick + 100);
            uint160 lowerValue = TickMath.getSqrtRatioAtTick(spotTick + 99);
            uint160 upperValue = TickMath.getSqrtRatioAtTick(spotTick + 101);
            assertTrue(lowerValue < sqrtPriceX96 && sqrtPriceX96 < upperValue);
        }
    }
}
