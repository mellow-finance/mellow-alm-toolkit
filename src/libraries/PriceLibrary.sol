// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/math/Math.sol";

library PriceLibrary {
    // Constants for fixed-point math
    uint256 private constant Q192 = 0x1000000000000000000000000000000000000000000000000;
    uint256 private constant Q190 = 0x400000000000000000000000000000000000000000000000;
    uint256 private constant MAX_Q192 = 0xffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256 private constant MAX_Q96 = 0xffffffffffffffffffffffff;

    /// @notice Converts `amount` to `amountOut` using the given square root price in Q96 fixed-point format (`sqrtPriceX96`).
    /// @dev Ensures precision and prevents overflow. Reverts if the result exceeds `type(uint256).max`.
    /// @param amount The input amount to be converted.
    /// @param sqrtPriceX96 The square root of the price ratio in Q96 fixed-point format.
    /// @return amountOut The equivalent amount in the other token's denomination.
    function convertBySqrtPriceX96(uint256 amount, uint160 sqrtPriceX96)
        internal
        pure
        returns (uint256 amountOut)
    {
        // Direct calculation for small sqrtPriceX96
        if (sqrtPriceX96 < type(uint128).max) {
            unchecked {
                return Math.mulDiv(amount, uint256(sqrtPriceX96) * sqrtPriceX96, Q192);
            }
        }

        uint256 intermediate;
        unchecked {
            intermediate = amount * sqrtPriceX96;

            // Ensure no overflow during intermediate multiplication
            if (intermediate / sqrtPriceX96 == amount) {
                return Math.mulDiv(intermediate, sqrtPriceX96, Q192);
            }
        }

        uint256 upperBits; // Upper 64 bits of sqrtPriceX96
        uint256 lowerBits; // Lower 96 bits of sqrtPriceX96
        assembly {
            // Extract the lower 96 bits and upper 64 bits
            lowerBits := and(sqrtPriceX96, MAX_Q96)
            upperBits := shr(96, sqrtPriceX96)

            // Calculate intermediate value based on upper and lower bits
            intermediate :=
                add(shl(95, mul(upperBits, lowerBits)), shr(2, mul(lowerBits, lowerBits)))

            // Square the upper 64 bits for later use
            upperBits := mul(upperBits, upperBits)
        }

        // Calculate the output amount
        amountOut = amount * upperBits + Math.mulDiv(amount, intermediate, Q190);

        assembly {
            // Handle rounding adjustments when the lowest bit of lowerBits is 1
            if and(lowerBits, 1) {
                // Check for overflow and increment amountOut as needed
                if lt(
                    xor(MAX_Q192, and(shl(2, mul(amount, intermediate)), MAX_Q192)),
                    and(amount, MAX_Q192)
                ) {
                    amountOut := add(amountOut, 1)
                    // Revert if addition causes overflow
                    if iszero(amountOut) { revert(0, 0) }
                }
            }
        }
    }
}
