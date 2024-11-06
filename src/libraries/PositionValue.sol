// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {FixedPoint128} from "@uniswap/v3-core/contracts/libraries/FixedPoint128.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import "../interfaces/external/velo/ICLFactory.sol";
import "../interfaces/external/velo/ICLPool.sol";

import "./PositionLibrary.sol";

/**
 * @title PositionValue
 * @notice Provides utilities to calculate the total value held by a Uniswap V3 NFT position, including principal and accrued fees.
 * @dev This library calculates the principal and fees in token0 and token1 that a position represents, based on current market conditions and position parameters.
 */
library PositionValue {
    /**
     * @notice Returns the total amounts of token0 and token1 held by a Uniswap V3 NFT position, including both principal and fees.
     * @dev Fetches principal amounts via `principal` and accrued fees via `fees`, then sums them for a complete value.
     * @param positionManager The address of the NonfungiblePositionManager contract managing the positions.
     * @param tokenId The ID of the NFT position token to calculate the total value for.
     * @param sqrtRatioX96 The square root of the current price, in Q96 format, used for calculating principal.
     * @return amount0 The total amount of token0 including principal and fees.
     * @return amount1 The total amount of token1 including principal and fees.
     */
    function total(
        INonfungiblePositionManager positionManager,
        uint256 tokenId,
        uint160 sqrtRatioX96
    ) internal view returns (uint256 amount0, uint256 amount1) {
        (uint256 amount0Principal, uint256 amount1Principal) =
            principal(positionManager, tokenId, sqrtRatioX96);
        (uint256 amount0Fee, uint256 amount1Fee) = fees(positionManager, tokenId);
        return (amount0Principal + amount0Fee, amount1Principal + amount1Fee);
    }

    /**
     * @notice Calculates the principal amounts of token0 and token1 that would be returned if the position were burned.
     * @dev Uses liquidity and tick bounds of the position to compute the value based on the current market price.
     * @param positionManager The address of the NonfungiblePositionManager contract managing the positions.
     * @param tokenId The ID of the NFT position token to calculate the principal for.
     * @param sqrtRatioX96 The square root of the current price, in Q96 format, used for calculating principal.
     * @return amount0 The principal amount of token0.
     * @return amount1 The principal amount of token1.
     */
    function principal(
        INonfungiblePositionManager positionManager,
        uint256 tokenId,
        uint160 sqrtRatioX96
    ) internal view returns (uint256 amount0, uint256 amount1) {
        PositionLibrary.Position memory position =
            PositionLibrary.getPosition(address(positionManager), tokenId);
        return LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            TickMath.getSqrtRatioAtTick(position.tickLower),
            TickMath.getSqrtRatioAtTick(position.tickUpper),
            position.liquidity
        );
    }

    /**
     * @notice Parameters needed to calculate the fees for a Uniswap V3 position.
     * @dev The struct stores position-specific information to facilitate fee calculation.
     * @param token0 The address of token0.
     * @param token1 The address of token1.
     * @param tickSpacing The tick spacing of the AMM pool.
     * @param tickLower The lower tick boundary of the position.
     * @param tickUpper The upper tick boundary of the position.
     * @param liquidity The liquidity of the position.
     * @param positionFeeGrowthInside0LastX128 The last recorded fee growth inside the position’s range for token0.
     * @param positionFeeGrowthInside1LastX128 The last recorded fee growth inside the position’s range for token1.
     * @param tokensOwed0 The amount of token0 owed to the position.
     * @param tokensOwed1 The amount of token1 owed to the position.
     */
    struct FeeParams {
        address token0;
        address token1;
        int24 tickSpacing;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 positionFeeGrowthInside0LastX128;
        uint256 positionFeeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    /**
     * @notice Calculates the accrued fees in token0 and token1 for a Uniswap V3 NFT position.
     * @dev Fetches current fee growth from the pool and subtracts the last recorded fee growth for the position.
     *      The result is multiplied by the position’s liquidity to calculate total fees owed.
     * @param positionManager The address of the NonfungiblePositionManager contract managing the positions.
     * @param tokenId The ID of the NFT position token to calculate fees for.
     * @return amount0 The accrued fees in token0.
     * @return amount1 The accrued fees in token1.
     */
    function fees(INonfungiblePositionManager positionManager, uint256 tokenId)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        PositionLibrary.Position memory position =
            PositionLibrary.getPosition(address(positionManager), tokenId);
        return _fees(
            positionManager,
            FeeParams({
                token0: position.token0,
                token1: position.token1,
                tickSpacing: position.tickSpacing,
                tickLower: position.tickLower,
                tickUpper: position.tickUpper,
                liquidity: position.liquidity,
                positionFeeGrowthInside0LastX128: position.feeGrowthInside0LastX128,
                positionFeeGrowthInside1LastX128: position.feeGrowthInside1LastX128,
                tokensOwed0: position.tokensOwed0,
                tokensOwed1: position.tokensOwed1
            })
        );
    }

    /**
     * @notice Calculates fees accrued within a given tick range in the Uniswap V3 pool.
     * @dev Uses unchecked math for gas efficiency and to compute fees based on liquidity and fee growth changes.
     * @param positionManager The address of the NonfungiblePositionManager contract.
     * @param feeParams Struct containing position details needed for fee calculation.
     * @return amount0 The accrued fees in token0.
     * @return amount1 The accrued fees in token1.
     */
    function _fees(INonfungiblePositionManager positionManager, FeeParams memory feeParams)
        private
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (uint256 poolFeeGrowthInside0LastX128, uint256 poolFeeGrowthInside1LastX128) =
        _getFeeGrowthInside(
            ICLPool(
                ICLFactory(positionManager.factory()).getPool(
                    feeParams.token0, feeParams.token1, feeParams.tickSpacing
                )
            ),
            feeParams.tickLower,
            feeParams.tickUpper
        );
        unchecked {
            amount0 = Math.mulDiv(
                poolFeeGrowthInside0LastX128 - feeParams.positionFeeGrowthInside0LastX128,
                feeParams.liquidity,
                FixedPoint128.Q128
            ) + feeParams.tokensOwed0;

            amount1 = Math.mulDiv(
                poolFeeGrowthInside1LastX128 - feeParams.positionFeeGrowthInside1LastX128,
                feeParams.liquidity,
                FixedPoint128.Q128
            ) + feeParams.tokensOwed1;
        }
    }

    /**
     * @notice Retrieves the fee growth for the given tick range in the pool.
     * @dev Fetches tick data from the pool and calculates fee growth based on the position of the current tick.
     * @param pool The Uniswap V3 pool to get fee growth data from.
     * @param tickLower The lower tick boundary of the position.
     * @param tickUpper The upper tick boundary of the position.
     * @return feeGrowthInside0X128 The fee growth inside the tick range for token0.
     * @return feeGrowthInside1X128 The fee growth inside the tick range for token1.
     */
    function _getFeeGrowthInside(ICLPool pool, int24 tickLower, int24 tickUpper)
        private
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        (, int24 tickCurrent,,,,) = pool.slot0();
        (,,, uint256 lowerFeeGrowthOutside0X128, uint256 lowerFeeGrowthOutside1X128,,,,,) =
            pool.ticks(tickLower);
        (,,, uint256 upperFeeGrowthOutside0X128, uint256 upperFeeGrowthOutside1X128,,,,,) =
            pool.ticks(tickUpper);

        unchecked {
            if (tickCurrent < tickLower) {
                feeGrowthInside0X128 = lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
                feeGrowthInside1X128 = lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
            } else if (tickCurrent < tickUpper) {
                uint256 feeGrowthGlobal0X128 = pool.feeGrowthGlobal0X128();
                uint256 feeGrowthGlobal1X128 = pool.feeGrowthGlobal1X128();
                feeGrowthInside0X128 =
                    feeGrowthGlobal0X128 - lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
                feeGrowthInside1X128 =
                    feeGrowthGlobal1X128 - lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
            } else {
                feeGrowthInside0X128 = upperFeeGrowthOutside0X128 - lowerFeeGrowthOutside0X128;
                feeGrowthInside1X128 = upperFeeGrowthOutside1X128 - lowerFeeGrowthOutside1X128;
            }
        }
    }
}
