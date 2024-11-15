// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/math/Math.sol";

library PriceLib320 {
    uint256 private constant Q192 = 1 << 192;

    function convertBySqrtPriceX96(uint256 amount0, uint160 sqrtPriceX96)
        internal
        pure
        returns (uint256 amount1)
    {
        // Fast path: If amount0 is small enough to fit within 96 bits,
        // use a simpler computation that avoids unnecessary overhead.
        if (amount0 <= type(uint96).max) {
            unchecked {
                // Perform the calculation: (amount0 * sqrtPriceX96^2) / (2^192)
                return Math.mulDiv(amount0 * sqrtPriceX96, sqrtPriceX96, Q192);
            }
        }

        uint64 top64Bits = uint64(sqrtPriceX96 >> 96);
        uint96 bottom96Bits = uint96(sqrtPriceX96);
        uint192 bottomSqr = uint192(bottom96Bits) ** 2;

        // If the top 64 bits are zero, the value of sqrtPriceX96 is small.
        // Use a simplified calculation that avoids multiplying by the top bits.
        if (top64Bits == 0) {
            unchecked {
                return Math.mulDiv(amount0, bottomSqr, Q192);
            }
        }

        uint160 topBottom = uint160(top64Bits) * bottom96Bits;

        // NOTE: Possible overflow for the case where amount1 is large than type(uint256).max
        amount1 = amount0 * uint256(top64Bits) ** 2;
        amount1 += Math.mulDiv(amount0, topBottom, 1 << 95);
        amount1 += Math.mulDiv(amount0, bottomSqr, Q192);

        // Compute the remainder, which represents additional precision from the least significant terms.
        uint256 remainder;
        unchecked {
            // Calculate remainder based on cross terms involving the top and bottom parts of amount0 and sqrtPriceX96
            remainder = uint256(uint96(amount0 * topBottom << 1)) << 96;

            uint192 amount0Bottom96Bits = uint96(amount0);
            uint192 amount0Mid96Bits = uint192(amount0) - amount0Bottom96Bits;

            remainder += amount0Mid96Bits * uint96(bottomSqr) + amount0Bottom96Bits * bottomSqr;
        }

        amount1 += remainder >> 192;
    }
}
