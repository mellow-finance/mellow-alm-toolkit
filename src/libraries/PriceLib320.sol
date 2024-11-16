// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/math/Math.sol";

library PriceLib320 {
    uint256 private constant Q95 = 1 << 95;
    uint256 private constant Q192 = 1 << 192;

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
        amount1 = amount0 * top64Bits * top64Bits + Math.mulDiv(amount0, topBottom, Q95)
            + Math.mulDiv(amount0, bottomSqr, Q192);

        unchecked {
            if (
                (type(uint192).max ^ uint192(amount0 * topBottom << 97))
                    >= uint192(amount0 & 0xffffffffffffffffffffffff000000000000000000000000)
                        * uint96(bottomSqr) + uint96(amount0) * bottomSqr
            ) {
                return amount1;
            }
        }
        // NOTE: Possible overflow for the case where amount1 is large than type(uint256).max
        return amount1 + 1;
    }
}
