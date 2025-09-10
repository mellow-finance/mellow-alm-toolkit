// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

/**
 * @title PositionMath
 * @notice Library for common mathematical operations related to positions in a UniswapV3 liquidity pool.
 * This library provides functions to calculate capital, liquidity, and token amounts for a given position.
 */
library PositionMath {
    using Math for uint256;

    uint256 internal constant Q64 = 0x10000000000000000;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;
    uint256 internal constant Q192 = 0x1000000000000000000000000000000000000000000000000;

    /**
     * @dev Calculates the capital for a given position based on its token amounts and current price.
     * @param amount0 Amount of token0.
     * @param amount1 Amount of token1.
     * @param sqrtPriceX96 Square root of the current price in the pool.
     * @return Capital amount in token1.
     */
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

    /**
     * @dev Converts token amounts between different tokens using the current pool price.
     * @param amount Amount of the token to convert.
     * @param zeroForOne Direction of the converting; true if converting token0 to token1, false - token1 to token0.
     * @param sqrtPriceX96 The current price of the pool as a sqrt(token1/token0)
     * @return convertedAmount Converted amount of the other token.
     */
    function convertAmount(uint256 amount, bool zeroForOne, uint256 sqrtPriceX96)
        internal
        pure
        returns (uint256 convertedAmount)
    {
        if (zeroForOne) {
            // converting token0 to token1: amount1 = amount0 * price
            if (sqrtPriceX96 < Q128) {
                return Math.mulDiv(amount, sqrtPriceX96 * sqrtPriceX96, Q192);
            } else {
                uint256 priceX128 = Math.mulDiv(sqrtPriceX96, sqrtPriceX96, Q64);
                return Math.mulDiv(amount, priceX128, Q128);
            }
        } else {
            // converting token1 to token0: amount0 = amount1 / price
            if (sqrtPriceX96 < Q128) {
                uint256 priceX128 = Math.mulDiv(sqrtPriceX96, sqrtPriceX96, Q64);
                return Math.mulDiv(amount, Q128, priceX128);
            } else {
                //uint256 convertedAmountX96 = Math.mulDiv(amount, Q192, sqrtPriceX96);
                //return Math.mulDiv(convertedAmountX96,  Q96, sqrtPriceX96);
                return Math.mulDiv(amount, Q192, sqrtPriceX96) / sqrtPriceX96;
            }
        }
    }

    /**
     * @dev Calculates liquidity for given token amounts and position parameters.
     * @param amount0 Amount of token0.
     * @param amount1 Amount of token1.
     * @param sqrtPriceX96 Square root of the current price in the pool.
     * @param tickLower Lower tick of the position.
     * @param tickUpper Upper tick of the position.
     * @return Liquidity amount.
     */
    function getLiquidityForAmounts(
        uint256 amount0,
        uint256 amount1,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (uint128) {
        return LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            amount0,
            amount1
        );
    }

    /**
     * @dev Calculates token amounts for a given liquidity amount in a position, rounding down.
     * @param liquidity Liquidity amount.
     * @param sqrtPriceX96 Square root of the current price in the pool.
     * @param tickLower Lower tick of the position.
     * @param tickUpper Upper tick of the position.
     * @return amount0 Amount of token0.
     * @return amount1 Amount of token1.
     */
    function getAmountsForLiquidity(
        uint256 liquidity,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        uint256 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint256 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        if (sqrtPriceX96 < sqrtPriceBX96) {
            uint256 sqrtRatioAX96_ = sqrtPriceAX96.max(sqrtPriceX96);
            amount0 = (liquidity << 96).mulDiv(sqrtPriceBX96 - sqrtRatioAX96_, sqrtPriceBX96)
                / sqrtRatioAX96_;
        }

        if (sqrtPriceX96 > sqrtPriceAX96) {
            amount1 = liquidity.mulDiv(sqrtPriceBX96.min(sqrtPriceX96) - sqrtPriceAX96, Q96);
        }
    }

    /**
     * @dev Calculates token amounts for a given liquidity amount in a position, rounding up.
     * @param liquidity Liquidity amount.
     * @param sqrtPriceX96 Square root of the current price in the pool.
     * @param tickLower Lower tick of the position.
     * @param tickUpper Upper tick of the position.
     * @return amount0 Amount of token0.
     * @return amount1 Amount of token1.
     */
    function getAmountsForLiquidityCeil(
        uint256 liquidity,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        uint256 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint256 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        if (sqrtPriceX96 < sqrtPriceBX96) {
            uint256 sqrtRatioAX96_ = sqrtPriceAX96.max(sqrtPriceX96);
            amount0 = Math.ceilDiv(
                (liquidity << 96).mulDiv(
                    sqrtPriceBX96 - sqrtRatioAX96_, sqrtPriceBX96, Math.Rounding.Ceil
                ),
                sqrtRatioAX96_
            );
        }

        if (sqrtPriceX96 > sqrtPriceAX96) {
            amount1 = liquidity.mulDiv(
                sqrtPriceBX96.min(sqrtPriceX96) - sqrtPriceAX96, Q96, Math.Rounding.Ceil
            );
        }
    }
}
