// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../Fixture.sol";

contract Unit is Fixture {
    TerminalOracle public oracle;
    ITerminalPool internal immutable pool = ITerminalPool(poolAB);

    function testConstructor() external {
        oracle = new TerminalOracle();
        assertTrue(address(oracle) != address(0));
    }

    function testValidateSecurityParams() external {
        oracle = new TerminalOracle();

        IVeloOracle.SecurityParams memory params = IVeloOracle.SecurityParams({
            lookback: 0,
            maxAllowedDelta: 0,
            maxAge: 7 days,
            extraData: ""
        });

        vm.expectRevert(IVeloOracle.InvalidParams.selector);
        oracle.validateSecurityParams(abi.encode(params));
        params.lookback = 1;
        oracle.validateSecurityParams(abi.encode(params));
        params.maxAllowedDelta = -1;
        vm.expectRevert(IVeloOracle.InvalidParams.selector);
        oracle.validateSecurityParams(abi.encode(params));
        oracle.validateSecurityParams(new bytes(0));
        vm.expectRevert();
        oracle.validateSecurityParams("random string");
    }

    function testEnsureNoMEV() external {
        increaseObservationCardinality(pool, 100);
        oracle = new TerminalOracle();

        assertEq(pool.tickSpacing(), 200);
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({
                    lookback: 0,
                    maxAllowedDelta: 0,
                    maxAge: 7 days,
                    extraData: ""
                })
            )
        );
        oracle.ensureNoMEV(address(pool), new bytes(0));
        oracle.ensureNoMEV(address(0), new bytes(0));
        vm.expectRevert();
        oracle.ensureNoMEV(
            address(0),
            abi.encode(
                IVeloOracle.SecurityParams({
                    lookback: 0,
                    maxAllowedDelta: 0,
                    maxAge: 7 days,
                    extraData: ""
                })
            )
        );
        vm.expectRevert(abi.encodeWithSignature("NotEnoughObservations()"));
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({
                    lookback: 1000,
                    maxAllowedDelta: 0,
                    maxAge: 7 days,
                    extraData: ""
                })
            )
        );
        pool.increaseObservationCardinalityNext(2);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughObservations()"));
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({
                    lookback: 1000,
                    maxAllowedDelta: 0,
                    maxAge: 7 days,
                    extraData: ""
                })
            )
        );
        mint(pool.tickSpacing(), pool.tickSpacing() * 2, 1000000, pool, address(this), true);
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({
                    lookback: 1,
                    maxAllowedDelta: 100,
                    maxAge: 7 days,
                    extraData: ""
                })
            )
        );
        vm.expectRevert(abi.encodeWithSignature("PriceManipulationDetected()"));
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({
                    lookback: 1,
                    maxAllowedDelta: -1,
                    maxAge: 7 days,
                    extraData: ""
                })
            )
        );
        vm.expectRevert(abi.encodeWithSignature("NotEnoughObservations()"));
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({
                    lookback: 1001,
                    maxAllowedDelta: 0,
                    maxAge: 7 days,
                    extraData: ""
                })
            )
        );

        deal(tokenA, address(this), 1e10 ether);
        deal(tokenB, address(this), 1e10 ether);

        vm.startPrank(Constants.TERMINAL_DEPLOYER);
        (, int24 spotTick,,,,,,) = pool.slot0();
        movePrice(pool, TickMath.getSqrtRatioAtTick(spotTick + 100));
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSignature("PriceManipulationDetected()"));
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({
                    lookback: 1,
                    maxAllowedDelta: 0,
                    maxAge: 7 days,
                    extraData: ""
                })
            )
        );
        movePrice(pool, TickMath.getSqrtRatioAtTick(spotTick));
    }

    function testGetOraclePrice() external {
        oracle = new TerminalOracle();

        oracle.getOraclePrice(address(pool));

        pool.increaseObservationCardinalityNext(2);
        mint(pool.tickSpacing(), pool.tickSpacing() * 2, 1000000, pool, address(this), true);

        (, int24 spotTick,,,,,,) = pool.slot0();

        deal(tokenA, address(this), 1e10 ether);
        deal(tokenB, address(this), 1e10 ether);

        vm.startPrank(Constants.TERMINAL_DEPLOYER);
        movePrice(pool, TickMath.getSqrtRatioAtTick(spotTick));
        vm.stopPrank();
        {
            (, int24 tick) = oracle.getOraclePrice(address(pool));
            assertEq(tick, spotTick);
        }
        vm.startPrank(Constants.TERMINAL_DEPLOYER);
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
