// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    function testConstructor() external {
        oracle = new VeloOracle();
        assertTrue(address(oracle) != address(0));
    }

    function testValidateSecurityParams() external {
        oracle = new VeloOracle();
        IVeloOracle.SecurityParams memory params = IVeloOracle.SecurityParams({
            lookback: 0,
            maxAllowedDelta: 0
        });
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
        ICLPool pool = ICLPool(0xC358c95b146E9597339b376063A2cB657AFf84eb);
        assertEq(pool.tickSpacing(), 200);
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 0, maxAllowedDelta: 0})
            )
        );
        oracle.ensureNoMEV(address(pool), new bytes(0));
        oracle.ensureNoMEV(address(0), new bytes(0));
        vm.expectRevert();
        oracle.ensureNoMEV(
            address(0),
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 0, maxAllowedDelta: 0})
            )
        );
        vm.expectRevert(abi.encodeWithSignature("NotEnoughObservations()"));
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 1, maxAllowedDelta: 0})
            )
        );
        pool.increaseObservationCardinalityNext(2);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughObservations()"));
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 1, maxAllowedDelta: 0})
            )
        );
        mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool
        );
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 1, maxAllowedDelta: 0})
            )
        );
        vm.expectRevert(abi.encodeWithSignature("PriceManipulationDetected()"));
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 1, maxAllowedDelta: -1})
            )
        );
        vm.expectRevert(abi.encodeWithSignature("NotEnoughObservations()"));
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 2, maxAllowedDelta: 0})
            )
        );
        vm.startPrank(Constants.DEPLOYER);
        movePrice(100, pool);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSignature("PriceManipulationDetected()"));
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 1, maxAllowedDelta: 0})
            )
        );
    }

    function testGetOraclePrice() external {
        oracle = new VeloOracle();
        ICLPool pool = ICLPool(0xC358c95b146E9597339b376063A2cB657AFf84eb);

        vm.expectRevert(abi.encodeWithSignature("NotEnoughObservations()"));
        oracle.getOraclePrice(address(pool));

        pool.increaseObservationCardinalityNext(2);
        mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool
        );
        {
            (uint160 sqrtPriceX96, int24 tick) = oracle.getOraclePrice(
                address(pool)
            );
            assertEq(tick, 0);
            assertEq(sqrtPriceX96, TickMath.getSqrtRatioAtTick(0));
        }
        vm.startPrank(Constants.DEPLOYER);
        movePrice(100, pool);
        vm.stopPrank();
        {
            (uint160 sqrtPriceX96, int24 tick) = oracle.getOraclePrice(
                address(pool)
            );
            assertEq(tick, 0);
            assertEq(sqrtPriceX96, TickMath.getSqrtRatioAtTick(0));
        }
        skip(1);
        {
            (uint160 sqrtPriceX96, int24 tick) = oracle.getOraclePrice(
                address(pool)
            );
            assertEq(tick, 100);
            uint160 lowerValue = TickMath.getSqrtRatioAtTick(99);
            uint160 upperValue = TickMath.getSqrtRatioAtTick(101);
            assertTrue(lowerValue < sqrtPriceX96 && sqrtPriceX96 < upperValue);
        }
    }
}
