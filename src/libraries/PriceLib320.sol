// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/math/Math.sol";

library PriceLib320 {
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

        {
            uint256 top64Bits;
            uint256 bottom96Bits;
            uint256 term;
            unchecked {
                top64Bits = uint64(sqrtPriceX96 >> 96);
                bottom96Bits = uint96(sqrtPriceX96);
                term = (top64Bits * bottom96Bits << 95) + (bottom96Bits * bottom96Bits >> 2);
            }

            // NOTE: Possible overflow for the case where amount1 is large than type(uint256).max
            amount1 = amount0 * top64Bits * top64Bits + Math.mulDiv(amount0, term, Q190);
            unchecked {
                if (
                    bottom96Bits & 1 == 0
                        || type(uint192).max ^ (uint192(amount0 * term) << 2) >= uint192(amount0)
                ) {
                    return amount1;
                }
            }
        }
        return amount1 + 1;
    }
}
