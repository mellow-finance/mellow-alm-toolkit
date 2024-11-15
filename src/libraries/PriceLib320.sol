// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/math/Math.sol";

library PriceLib320 {
    function convertBySqrtPriceX96(uint256 amount0, uint160 sqrtPriceX96)
        internal
        pure
        returns (uint256 amount1)
    {
        // Shortcut for common case where amount0 is small
        if (amount0 <= type(uint96).max) {
            return Math.mulDiv(amount0 * sqrtPriceX96, sqrtPriceX96, 1 << 192);
        }

        // Split sqrtPriceX96 into high and low components
        uint64 top64Bits = uint64(sqrtPriceX96 >> 96);
        uint96 bottom96Bits = uint96(sqrtPriceX96);

        // If top 64 bits are zero, use a simplified computation
        if (top64Bits == 0) {
            unchecked {
                return Math.mulDiv(amount0, bottom96Bits ** 2, 1 << 192);
            }
        }

        // Calculate intermediate values
        uint192 bottomSqr = uint192(bottom96Bits) ** 2;
        uint160 topBottom = uint160(top64Bits) * bottom96Bits;

        // Calculate amount1, avoiding overflow
        amount1 = amount0 * uint256(top64Bits) ** 2; // Main term
        amount1 += Math.mulDiv(amount0, topBottom, 1 << 95); // Cross term
        amount1 += Math.mulDiv(amount0, bottomSqr, 1 << 192); // Bottom term

        uint192 remainder;
        unchecked {
            // Compute the remainder from cross terms
            remainder = uint96(amount0) * uint96(topBottom) << 1;

            uint96 amount0Lowest96Bits = uint96(amount0);
            uint96 bottomSqrBottom96Bits = uint96(bottomSqr);

            remainder += uint96(
                uint96(uint192(amount0) >> 96) * bottomSqrBottom96Bits
                    + amount0Lowest96Bits * uint96(bottomSqr >> 96)
            );
            remainder += uint96(uint192(amount0Lowest96Bits) * bottomSqrBottom96Bits);
        }

        // Add remainder to amount1
        amount1 += remainder >> 96;

        // Return the final computed amount
        return amount1;
    }
}
