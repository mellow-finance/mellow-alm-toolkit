// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    function print(uint160 sqrtPriceX96, int24 width) public {
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        (int24 targetLower, uint256 lowerLiquidityRatioX96) =
            TamperStrategyLibrary.calculateInitialPosition(sqrtPriceX96, tick, width);
        int24 half = width / 2;

        uint256 dumRatioX96 =
            Q96 - Math.mulDiv(Q96, uint24(tick - targetLower - half), uint24(half));

        string memory log = string.concat(
            "opt:",
            vm.toString(targetLower),
            " lowerLiquidityRatioX96: ",
            vm.toString(lowerLiquidityRatioX96 * 1 gwei / 2 ** 96),
            " dumRatioX96: ",
            vm.toString(dumRatioX96 * 1 gwei / 2 ** 96),
            " tick: ",
            vm.toString(tick),
            " width: ",
            vm.toString(width)
        );
        console2.log(log);
    }

    function testTickMath() external {
        print(TickMath.getSqrtRatioAtTick(0) + 100, 4);
    }
}
