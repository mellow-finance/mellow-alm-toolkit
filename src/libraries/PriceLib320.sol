// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/math/Math.sol";

library PriceLib320 {
    uint256 private constant Q95 = 1 << 95;
    uint256 private constant Q192 = 1 << 192;
    uint256 private constant Q190 = 1 << 190;

    function convertBySqrtPriceX96(uint256 amount0, uint160 sqrtPriceX96)
        internal
        pure
        returns (uint256 amount1)
    {
        unchecked {
            if (sqrtPriceX96 < type(uint128).max) {
                return Math.mulDiv(amount0, uint256(sqrtPriceX96) * sqrtPriceX96, Q192);
            }
            uint256 term = amount0 * sqrtPriceX96;
            if (term / sqrtPriceX96 == amount0) {
                return Math.mulDiv(term, sqrtPriceX96, Q192);
            }
        }

        uint64 top64Bits = uint64(sqrtPriceX96 >> 96);
        uint96 bottom96Bits = uint96(sqrtPriceX96);
        uint192 bottomSqr = uint192(bottom96Bits) * bottom96Bits;
        uint160 topBottom = uint160(top64Bits) * bottom96Bits;

        // NOTE: Possible overflow for the case where amount1 is large than type(uint256).max
        uint256 term1 = (uint256(topBottom) << 95) + (bottomSqr >> 2);
        uint8 term2 = uint8(bottomSqr & 3);
        amount1 = amount0 * top64Bits * top64Bits + Math.mulDiv(amount0, term1, Q190);

        if (term2 & 1 == 1) {
            amount1 += amount0 >> 192;
        }
        if (term2 & 2 == 2) {
            amount1 += amount0 >> 191;
        }

        unchecked {
            if (type(uint192).max ^ (uint192(amount0 * term1) << 2) >= uint192(amount0) * term2) {
                return amount1;
            }
        }
        return amount1 + 1;
    }
}
