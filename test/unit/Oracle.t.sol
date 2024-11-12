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
        IVeloOracle.SecurityParams memory params =
            IVeloOracle.SecurityParams({lookback: 0, maxAllowedDelta: 0, maxAge: 7 days});
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        oracle.validateSecurityParams(abi.encode(params));
        params.lookback = 1;
        oracle.validateSecurityParams(abi.encode(params));
        params.maxAllowedDelta = -1;
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        oracle.validateSecurityParams(abi.encode(params));
        oracle.validateSecurityParams(new bytes(0));
        vm.expectRevert();
        oracle.validateSecurityParams("random string");
    }

    function testEnsureNoMEV() external {
        oracle = new VeloOracle();

        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
        assertEq(pool.tickSpacing(), 200);
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 0, maxAllowedDelta: 0, maxAge: 7 days})
            )
        );
        oracle.ensureNoMEV(address(pool), new bytes(0));
        oracle.ensureNoMEV(address(0), new bytes(0));
        vm.expectRevert();
        oracle.ensureNoMEV(
            address(0),
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 0, maxAllowedDelta: 0, maxAge: 7 days})
            )
        );
        vm.expectRevert(abi.encodeWithSignature("NotEnoughObservations()"));
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 1000, maxAllowedDelta: 0, maxAge: 7 days})
            )
        );
        pool.increaseObservationCardinalityNext(2);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughObservations()"));
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 1000, maxAllowedDelta: 0, maxAge: 7 days})
            )
        );
        mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            1000000,
            pool,
            address(this)
        );
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 1, maxAllowedDelta: 0, maxAge: 7 days})
            )
        );
        vm.expectRevert(abi.encodeWithSignature("PriceManipulationDetected()"));
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 1, maxAllowedDelta: -1, maxAge: 7 days})
            )
        );
        vm.expectRevert(abi.encodeWithSignature("NotEnoughObservations()"));
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 1001, maxAllowedDelta: 0, maxAge: 7 days})
            )
        );
        vm.startPrank(Constants.OPTIMISM_DEPLOYER);
        (
            ,
            int24 spotTick,
            , /* uint16 observationCardinality */
            , /* uint16 observationCardinalityNext */
            ,
        ) = pool.slot0();
        movePrice(pool, TickMath.getSqrtRatioAtTick(spotTick + 100));
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSignature("PriceManipulationDetected()"));
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 1, maxAllowedDelta: 0, maxAge: 7 days})
            )
        );
        movePrice(pool, TickMath.getSqrtRatioAtTick(spotTick));
        /*         for (uint16 i = observationCardinality; i < observationCardinality+1000; i++) {
            pool.increaseObservationCardinalityNext(i);
        }
        (, ,, observationCardinality, observationCardinalityNext,) = pool.slot0();
        console2.log(observationCardinality, observationCardinalityNext); */
    }

    function testGetOraclePrice() external {
        oracle = new VeloOracle();
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));

        oracle.getOraclePrice(address(pool));

        pool.increaseObservationCardinalityNext(2);
        mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            1000000,
            pool,
            address(this)
        );

        (, int24 spotTick,,,,) = pool.slot0();

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);
        movePrice(pool, TickMath.getSqrtRatioAtTick(spotTick));
        vm.stopPrank();
        {
            (, int24 tick) = oracle.getOraclePrice(address(pool));
            assertEq(tick, spotTick);
        }
        vm.startPrank(Constants.OPTIMISM_DEPLOYER);
        movePrice(pool, TickMath.getSqrtRatioAtTick(spotTick + 100));
        vm.stopPrank();
        {
            (uint160 sqrtPriceX96, int24 tick) = oracle.getOraclePrice(address(pool));
            assertEq(tick, spotTick + 100);
            uint160 lowerValue = TickMath.getSqrtRatioAtTick(spotTick + 99);
            uint160 upperValue = TickMath.getSqrtRatioAtTick(spotTick + 101);
            assertTrue(lowerValue < sqrtPriceX96 && sqrtPriceX96 < upperValue);
        }
    }
}
