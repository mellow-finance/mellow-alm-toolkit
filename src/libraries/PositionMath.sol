// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title PositionMath
 */
library PositionMath {
    uint256 public constant Q64 = 2 ** 64;
    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant Q128 = 2 ** 128;
    uint256 public constant Q192 = 2 ** 192;

    function calculateCapital(uint256 amount0, uint256 amount1, uint256 sqrtPriceX96)
        internal
        pure
        returns (uint256)
    {
        if (sqrtPriceX96 < Q128) {
            return Math.mulDiv(amount0, sqrtPriceX96 * sqrtPriceX96, Q192) + amount1;
        } else {
            uint256 priceX128 = Math.mulDiv(sqrtPriceX96, sqrtPriceX96, Q64);
            return Math.mulDiv(amount0, priceX128, Q128) + amount1;
        }
    }
}
