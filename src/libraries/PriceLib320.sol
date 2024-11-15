// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/math/Math.sol";

library PriceLib320 {
    function convertBySqrtPriceX96(uint256 amount0, uint160 sqrtPriceX96)
        internal
        pure
        returns (uint256 amount1)
    {
        uint64 hi = uint64(sqrtPriceX96 >> 96);
        uint96 lo = uint96(sqrtPriceX96);

        if (hi == 0) {
            unchecked {
                return Math.mulDiv(amount0, lo ** 2, 1 << 192);
            }
        }

        uint128 hi_sq = uint128(hi) ** 2;
        uint192 lo_sq = uint192(lo) ** 2;
        uint160 hi_lo = uint160(hi) * lo;

        // overflow only in case if (amount0 * sqrtPriceX96 ** 2 >> 192) > type(uint256).max
        amount1 = amount0 * hi_sq;
        amount1 += Math.mulDiv(amount0, hi_lo, 1 << 96);
        amount1 += Math.mulDiv(amount0, lo_sq, 1 << 192);

        unchecked {
            uint96 remainder0 = uint96(amount0) * uint96(hi_lo);
            uint96 amount0_mid = uint96(uint192(amount0) >> 96);
            uint96 amount0_lo = uint96(amount0);
            uint96 lo_sq_lo = uint96(lo_sq);
            uint96 lo_sq_mid = uint96(lo_sq >> 96);
            uint96 remainder1 = (amount0_mid * lo_sq_lo + amount0_lo * lo_sq_mid);
            uint96 remainder2 = uint96(uint192(amount0_lo) * lo_sq_lo);
            uint192 remainder = uint192(remainder0) * 2 + uint192(remainder1) + uint192(remainder2);
            amount1 += remainder >> 96;
        }
    }
}
