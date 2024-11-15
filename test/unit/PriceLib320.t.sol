// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../src/libraries/PriceLib320.sol";
import "./Fixture.sol";

contract Unit is Fixture {
    function testPriceLib320() external {
        {
            uint160 sqrtPriceX96 = 4295128739;
            uint256 amount0 = type(uint256).max;
            uint256 expectedAmount1 = 340307949066213071763124218027663425535;
            uint256 amount1 = PriceLib320.convertBySqrtPriceX96(amount0, sqrtPriceX96);
            assertEq(amount1, expectedAmount1, "min sqrt price");
            assertNotEq(
                Math.mulDiv(amount0, Math.mulDiv(sqrtPriceX96, sqrtPriceX96, Q96), Q96),
                expectedAmount1,
                "min sqrt price precision loss"
            );
        }
        {
            uint160 sqrtPriceX96 = 1461446703485210103287273052203988822378723970342;
            uint256 amount0 = type(uint128).max;
            uint256 expectedAmount1 =
                115783384785599357996676985412062652720342362943929506828539444553934033845704;
            uint256 amount1 = PriceLib320.convertBySqrtPriceX96(amount0, sqrtPriceX96);
            assertEq(amount1, expectedAmount1, "max sqrt price");
            assertNotEq(
                Math.mulDiv(amount0, Math.mulDiv(sqrtPriceX96, sqrtPriceX96, Q96), Q96),
                expectedAmount1,
                "max sqrt price precision loss"
            );
        }
    }
}
