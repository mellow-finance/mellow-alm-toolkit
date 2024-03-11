// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Constants.sol";

import {SwapRouter} from "../contracts/periphery/SwapRouter.sol";
import {QuoterV2} from "../contracts/periphery/lens/QuoterV2.sol";

contract Fixture is Test {
    using SafeERC20 for IERC20;

    int24 public constant TICK_SPACING = 200;
    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D4 = 1e4;

    INonfungiblePositionManager public positionManager =
        INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER);
    ICLFactory public factory = ICLFactory(Constants.VELO_FACTORY);

    ISwapRouter public swapRouter =
        ISwapRouter(
            address(new SwapRouter(positionManager.factory(), Constants.WETH))
        );

    IQuoterV2 public quoterV2 =
        IQuoterV2(
            address(new QuoterV2(positionManager.factory(), Constants.WETH))
        );

    function mint(
        address token0,
        address token1,
        int24 tickSpacing,
        int24 width,
        uint128 liquidity,
        ICLPool pool
    ) public returns (uint256) {
        vm.startPrank(Constants.OWNER);
        if (token0 > token1) (token0, token1) = (token1, token0);
        (uint160 sqrtRatioX96, int24 spotTick, , , , ) = pool.slot0();
        {
            int24 remainder = spotTick % pool.tickSpacing();
            if (remainder < 0) remainder += pool.tickSpacing();
            spotTick -= remainder;
        }
        INonfungiblePositionManager.MintParams memory mintParams;
        mintParams.tickLower = spotTick - width / 2;
        mintParams.tickUpper = mintParams.tickLower + width;
        mintParams.recipient = Constants.OWNER;
        mintParams.deadline = type(uint256).max;
        mintParams.token0 = token0;
        mintParams.token1 = token1;
        mintParams.tickSpacing = tickSpacing;
        {
            uint160 sqrtLowerRatioX96 = TickMath.getSqrtRatioAtTick(
                mintParams.tickLower
            );
            uint160 sqrtUpperRatioX96 = TickMath.getSqrtRatioAtTick(
                mintParams.tickUpper
            );
            (
                mintParams.amount0Desired,
                mintParams.amount1Desired
            ) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                sqrtLowerRatioX96,
                sqrtUpperRatioX96,
                liquidity
            );
        }
        deal(token0, Constants.OWNER, mintParams.amount0Desired);
        deal(token1, Constants.OWNER, mintParams.amount1Desired);
        IERC20(token0).safeIncreaseAllowance(
            address(positionManager),
            mintParams.amount0Desired
        );
        IERC20(token1).safeIncreaseAllowance(
            address(positionManager),
            mintParams.amount1Desired
        );
        (uint256 tokenId, uint128 actualLiquidity, , ) = positionManager.mint(
            mintParams
        );
        require((liquidity * 99) / 100 <= actualLiquidity && tokenId > 0);
        vm.stopPrank();
        return tokenId;
    }

    function movePrice(int24 targetTick, ICLPool pool) public {
        int24 spotTick;
        (, spotTick, , , , ) = pool.slot0();
        uint256 usdcAmount = IERC20(Constants.USDC).balanceOf(address(pool));
        uint256 wethAmount = IERC20(Constants.WETH).balanceOf(address(pool));
        if (spotTick < targetTick) {
            while (spotTick < targetTick) {
                _swapAmount(usdcAmount, 1);
                (, spotTick, , , , ) = pool.slot0();
            }
        } else {
            while (spotTick > targetTick) {
                _swapAmount(wethAmount, 0);
                (, spotTick, , , , ) = pool.slot0();
            }
        }

        while (spotTick != targetTick) {
            if (spotTick < targetTick) {
                while (spotTick < targetTick) {
                    _swapAmount(usdcAmount, 1);
                    (, spotTick, , , , ) = pool.slot0();
                }
                usdcAmount >>= 1;
            } else {
                while (spotTick > targetTick) {
                    _swapAmount(wethAmount, 0);
                    (, spotTick, , , , ) = pool.slot0();
                }
                wethAmount >>= 1;
            }
        }
    }

    function _swapAmount(uint256 amountIn, uint256 tokenInIndex) private {
        if (amountIn == 0) revert("Insufficient amount for swap");
        address[] memory tokens = new address[](2);
        tokens[0] = Constants.WETH;
        tokens[1] = Constants.USDC;
        address tokenIn = tokens[tokenInIndex];
        address tokenOut = tokens[tokenInIndex ^ 1];
        deal(tokenIn, Constants.DEPLOYER, amountIn);
        IERC20(tokenIn).safeIncreaseAllowance(address(swapRouter), amountIn);
        ISwapRouter(swapRouter).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                tickSpacing: TICK_SPACING,
                recipient: Constants.DEPLOYER,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0,
                deadline: type(uint256).max
            })
        );
    }

    function addLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        ICLPool pool
    ) public {
        (uint160 sqrtRatioX96, , , , , ) = pool.slot0();
        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );
        amount0 *= 2;
        amount1 *= 2;
        deal(Constants.WETH, address(Constants.DEPLOYER), amount0);
        deal(Constants.USDC, address(Constants.DEPLOYER), amount1);
        IERC20(Constants.WETH).safeIncreaseAllowance(
            address(positionManager),
            amount0
        );
        IERC20(Constants.USDC).safeIncreaseAllowance(
            address(positionManager),
            amount1
        );
        positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: Constants.WETH,
                token1: Constants.USDC,
                tickSpacing: TICK_SPACING,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: type(uint256).max
            })
        );
    }

    function normalizePool(ICLPool pool) public {
        pool.increaseObservationCardinalityNext(2);
        {
            int24 lowerTick = -800000;
            int24 upperTick = 800000;
            addLiquidity(lowerTick, upperTick, 2500 ether, pool);
        }

        (, int24 targetTick, , , , , ) = IUniswapV3Pool(
            0x85149247691df622eaF1a8Bd0CaFd40BC45154a9
        ).slot0();

        _swapAmount(2621439999999999988840005632, 0);
        movePrice(targetTick, pool);

        targetTick -= targetTick % TICK_SPACING;

        {
            (uint160 sqrtRatioX96, , , , , ) = pool.slot0();
            uint256 priceX96 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, Q96);
            uint256 usdcAmount = 5e12;
            uint256 wethAmount = FullMath.mulDiv(usdcAmount, Q96, priceX96);

            for (int24 i = 1; i <= 20; i++) {
                int24 lowerTick = targetTick - i * TICK_SPACING;
                int24 upperTick = targetTick + i * TICK_SPACING;
                uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
                    sqrtRatioX96,
                    TickMath.getSqrtRatioAtTick(lowerTick),
                    TickMath.getSqrtRatioAtTick(upperTick),
                    wethAmount,
                    usdcAmount
                );
                addLiquidity(lowerTick, upperTick, liquidity, pool);
            }
        }

        skip(3 * 24 * 3600);
    }
}
