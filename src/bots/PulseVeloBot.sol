// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import "../interfaces/bots/IPulseVeloBot.sol";
import "forge-std/Test.sol";

contract PulseVeloBot is IPulseVeloBot {
    using SafeERC20 for IERC20;

    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D6 = 1e6;

    IQuoterV2 public immutable quoter;
    ISwapRouter public immutable router;
    INonfungiblePositionManager public immutable positionManager;

    constructor(
        IQuoterV2 quoter_,
        ISwapRouter router_,
        INonfungiblePositionManager positionManager_
    ) {
        quoter = quoter_;
        router = router_;
        positionManager = positionManager_;
    }

    function _getSingleRatio(uint160 sqrtRatioX96, SingleIntervalData memory data)
        private
        pure
        returns (uint256)
    {
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96, data.sqrtLowerRatioX96, data.sqrtUpperRatioX96, uint128(Q96)
        );
        return Math.mulDiv(amount0, Q96, amount0 + amount1);
    }

    function calculateSwapAmountsPreciselySingle(SingleIntervalData memory data)
        public
        returns (SwapParams memory swapParams)
    {
        if (data.amount0 + data.amount1 == 0) {
            return swapParams;
        }
        uint256 currentRatioX96 = Math.mulDiv(data.amount0, Q96, data.amount0 + data.amount1);
        uint256 finalRatioX96;
        {
            (uint160 finalSqrtPriceX96,,,,,) = data.pool.slot0();
            finalRatioX96 = _getSingleRatio(finalSqrtPriceX96, data);
        }
        if (currentRatioX96 == finalRatioX96) {
            return swapParams;
        }
        if (currentRatioX96 > finalRatioX96) {
            swapParams.tokenIn = data.pool.token0();
            swapParams.tokenOut = data.pool.token1();
            swapParams.tickSpacing = data.pool.tickSpacing();
            unchecked {
                int256 left = 1;
                int256 right = int256(data.amount0);
                int256 mid;
                while (left <= right) {
                    mid = (left + right) >> 1;
                    swapParams.amountIn = uint256(mid);
                    uint160 sqrtPriceX96After;
                    (swapParams.expectedAmountOut, sqrtPriceX96After,,) = quoter
                        .quoteExactInputSingle(
                        IQuoterV2.QuoteExactInputSingleParams({
                            tokenIn: data.pool.token0(),
                            tokenOut: data.pool.token1(),
                            tickSpacing: data.pool.tickSpacing(),
                            amountIn: uint256(mid),
                            sqrtPriceLimitX96: 0
                        })
                    );

                    uint256 resultingRatioX96 = Math.mulDiv(
                        data.amount0 - uint256(mid),
                        Q96,
                        data.amount0 - uint256(mid) + data.amount1 + swapParams.expectedAmountOut
                    );
                    finalRatioX96 = _getSingleRatio(sqrtPriceX96After, data);
                    if (finalRatioX96 == resultingRatioX96) {
                        return swapParams;
                    }
                    if (finalRatioX96 < resultingRatioX96) {
                        left = mid + 1;
                    } else {
                        right = mid - 1;
                    }
                }
                return swapParams;
            }
        } else {
            swapParams.tokenIn = data.pool.token1();
            swapParams.tokenOut = data.pool.token0();
            swapParams.tickSpacing = data.pool.tickSpacing();
            unchecked {
                int256 left = 1;
                int256 right = int256(data.amount1);
                int256 mid;
                while (left <= right) {
                    mid = (left + right) >> 1;
                    swapParams.amountIn = uint256(mid);
                    uint160 sqrtPriceX96After;
                    (swapParams.expectedAmountOut, sqrtPriceX96After,,) = quoter
                        .quoteExactInputSingle(
                        IQuoterV2.QuoteExactInputSingleParams({
                            tokenIn: data.pool.token1(),
                            tokenOut: data.pool.token0(),
                            tickSpacing: data.pool.tickSpacing(),
                            amountIn: uint256(mid),
                            sqrtPriceLimitX96: 0
                        })
                    );

                    uint256 resultingRatioX96 = Math.mulDiv(
                        data.amount0 + swapParams.expectedAmountOut,
                        Q96,
                        data.amount0 + swapParams.expectedAmountOut + data.amount1
                            - swapParams.amountIn
                    );
                    finalRatioX96 = _getSingleRatio(sqrtPriceX96After, data);
                    if (finalRatioX96 == resultingRatioX96) {
                        return swapParams;
                    }
                    if (finalRatioX96 > resultingRatioX96) {
                        left = mid + 1;
                    } else {
                        right = mid - 1;
                    }
                }
                return swapParams;
            }
        }
    }

    function _getMultipleRatioX96(uint160 sqrtRatioX96, MultipleIntervalsData memory data)
        private
        pure
        returns (uint256 finalRatioX96)
    {
        for (uint256 i = 0; i < data.sqrtLowerRatiosX96.length; i++) {
            uint256 tokenRatioX96 = _getSingleRatio(
                sqrtRatioX96,
                SingleIntervalData({
                    amount0: 0,
                    amount1: 0,
                    sqrtLowerRatioX96: data.sqrtLowerRatiosX96[i],
                    sqrtUpperRatioX96: data.sqrtUpperRatiosX96[i],
                    pool: ICLPool(address(0))
                })
            );
            finalRatioX96 += Math.mulDiv(tokenRatioX96, data.ratiosX96[i], Q96);
        }
    }

    function calculateSwapAmountsPreciselyMultiple(MultipleIntervalsData memory data)
        public
        returns (SwapParams memory swapParams)
    {
        if (data.amount0 + data.amount1 == 0) {
            return swapParams;
        }
        uint256 currentRatioX96 = Math.mulDiv(data.amount0, Q96, data.amount0 + data.amount1);
        uint256 finalRatioX96;
        {
            (uint160 finalSqrtPriceX96,,,,,) = data.pool.slot0();
            finalRatioX96 = _getMultipleRatioX96(finalSqrtPriceX96, data);
        }
        if (currentRatioX96 == finalRatioX96) {
            return swapParams;
        }
        if (currentRatioX96 > finalRatioX96) {
            swapParams.tokenIn = data.pool.token0();
            swapParams.tokenOut = data.pool.token1();
            swapParams.tickSpacing = data.pool.tickSpacing();
            unchecked {
                int256 left = 1;
                int256 right = int256(data.amount0);
                int256 mid;
                while (left <= right) {
                    mid = (left + right) >> 1;
                    swapParams.amountIn = uint256(mid);
                    uint160 sqrtPriceX96After;
                    (swapParams.expectedAmountOut, sqrtPriceX96After,,) = quoter
                        .quoteExactInputSingle(
                        IQuoterV2.QuoteExactInputSingleParams({
                            tokenIn: data.pool.token0(),
                            tokenOut: data.pool.token1(),
                            tickSpacing: data.pool.tickSpacing(),
                            amountIn: uint256(mid),
                            sqrtPriceLimitX96: 0
                        })
                    );

                    uint256 resultingRatioX96 = Math.mulDiv(
                        data.amount0 - uint256(mid),
                        Q96,
                        data.amount0 - uint256(mid) + data.amount1 + swapParams.expectedAmountOut
                    );
                    finalRatioX96 = _getMultipleRatioX96(sqrtPriceX96After, data);
                    if (finalRatioX96 == resultingRatioX96) {
                        return swapParams;
                    }
                    if (finalRatioX96 < resultingRatioX96) {
                        left = mid + 1;
                    } else {
                        right = mid - 1;
                    }
                }
                return swapParams;
            }
        } else {
            swapParams.tokenIn = data.pool.token1();
            swapParams.tokenOut = data.pool.token0();
            swapParams.tickSpacing = data.pool.tickSpacing();
            unchecked {
                int256 left = 1;
                int256 right = int256(data.amount0);
                int256 mid;
                while (left <= right) {
                    mid = (left + right) >> 1;
                    swapParams.amountIn = uint256(mid);
                    uint160 sqrtPriceX96After;
                    (swapParams.expectedAmountOut, sqrtPriceX96After,,) = quoter
                        .quoteExactInputSingle(
                        IQuoterV2.QuoteExactInputSingleParams({
                            tokenIn: data.pool.token1(),
                            tokenOut: data.pool.token0(),
                            tickSpacing: data.pool.tickSpacing(),
                            amountIn: uint256(mid),
                            sqrtPriceLimitX96: 0
                        })
                    );

                    uint256 resultingRatioX96 = Math.mulDiv(
                        data.amount0 + swapParams.expectedAmountOut,
                        Q96,
                        data.amount0 + swapParams.expectedAmountOut + data.amount1
                            - swapParams.amountIn
                    );
                    finalRatioX96 = _getMultipleRatioX96(sqrtPriceX96After, data);
                    if (finalRatioX96 == resultingRatioX96) {
                        return swapParams;
                    }
                    if (finalRatioX96 > resultingRatioX96) {
                        left = mid + 1;
                    } else {
                        right = mid - 1;
                    }
                }
                return swapParams;
            }
        }
    }

    function call(bytes memory data, ICore.TargetPositionInfo[] memory targets)
        external
        returns (uint256[][] memory newTokenIds)
    {
        ISwapRouter.ExactInputSingleParams[] memory swapParams =
            abi.decode(data, (ISwapRouter.ExactInputSingleParams[]));
        // getting liquidity from all position
        for (uint256 i = 0; i < targets.length; i++) {
            uint256 tokenId = targets[i].info.ammPositionIds[0];
            (,,,,,,, uint128 liquidity,,,,) = positionManager.positions(tokenId);
            positionManager.decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: type(uint256).max
                })
            );
            positionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    recipient: address(this),
                    tokenId: tokenId,
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );
            positionManager.burn(tokenId);
        }

        // swapping to target ratio according result of function `calculateSwapAmountsPrecisely`
        for (uint256 i = 0; i < swapParams.length; i++) {
            address tokenIn = swapParams[i].tokenIn;
            uint256 balance = IERC20(swapParams[i].tokenIn).balanceOf(address(this));
            if (balance < swapParams[i].amountIn) {
                swapParams[i].amountIn = balance;
            }
            if (swapParams[i].amountIn == 0) {
                continue;
            }
            if (IERC20(tokenIn).allowance(address(this), address(router)) == 0) {
                IERC20(tokenIn).forceApprove(address(router), type(uint256).max);
            }
            router.exactInputSingle(swapParams[i]);
        }

        // creating new positions with minimal liquidity
        newTokenIds = new uint256[][](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            ICLPool pool = ICLPool(targets[i].info.pool);
            (uint160 sqrtPriceX96,,,,,) = pool.slot0();
            (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(targets[i].lowerTicks[0]),
                TickMath.getSqrtRatioAtTick(targets[i].upperTicks[0]),
                uint128((targets[i].minLiquidities[0] * (D6 + 1)) / D6) + 1
            );

            address token0 = pool.token0();
            if (IERC20(token0).allowance(address(this), address(positionManager)) == 0) {
                IERC20(token0).forceApprove(address(positionManager), type(uint256).max);
            }
            address token1 = pool.token1();
            if (IERC20(token1).allowance(address(this), address(positionManager)) == 0) {
                IERC20(token1).forceApprove(address(positionManager), type(uint256).max);
            }

            {
                console2.log("token0:", IERC20(token0).balanceOf(address(this)), ">=", amount0);
                console2.log("token1:", IERC20(token1).balanceOf(address(this)), ">=", amount1);
            }

            (uint256 tokenId, uint128 actualLiquidity,,) = positionManager.mint(
                INonfungiblePositionManager.MintParams({
                    token0: token0,
                    token1: token1,
                    tickSpacing: pool.tickSpacing(),
                    tickLower: targets[i].lowerTicks[0],
                    tickUpper: targets[i].upperTicks[0],
                    amount0Desired: IERC20(token0).balanceOf(address(this)),
                    amount1Desired: IERC20(token1).balanceOf(address(this)),
                    amount0Min: 0,
                    amount1Min: 0,
                    recipient: address(this),
                    deadline: type(uint256).max,
                    sqrtPriceX96: 0
                })
            );
            require(
                actualLiquidity >= targets[i].minLiquidities[0],
                string(
                    abi.encodePacked(
                        "Insufficient amount of liquidity. Actual: ",
                        Strings.toString(actualLiquidity),
                        "; Expected: ",
                        Strings.toString(targets[i].minLiquidities[0])
                    )
                )
            );
            positionManager.approve(msg.sender, tokenId);
            newTokenIds[i] = new uint256[](1);
            newTokenIds[i][0] = tokenId;
        }
    }
}
