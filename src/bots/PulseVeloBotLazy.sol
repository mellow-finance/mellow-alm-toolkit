// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../interfaces/bots/IPulseVeloBotLazy.sol";

import "../libraries/external/LiquidityAmounts.sol";
import "../libraries/external/TickMath.sol";

import "forge-std/Test.sol";

contract PulseVeloBotLazy is IPulseVeloBotLazy {
    using SafeERC20 for IERC20;

    uint256 public constant Q128 = 2 ** 128;
    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D6 = 1e6;

    INonfungiblePositionManager public immutable positionManager;

    ICore core;

    constructor(INonfungiblePositionManager positionManager_, ICore core_) {
        positionManager = positionManager_;
        core = core_;
    }

    /// @dev returns @param shareX96 shares necessery to swap for desired target position
    /// @param shareX96 fixed point number
    /// @param zeroForOne is true if swap 0->1, and vice versa
    function necessarySwapSharesX96ForMint()
        external
        view
        returns (uint256[] memory shareX96, bool[] memory zeroForOne)
    {
        uint256 positionCount = core.positionCount();
        shareX96 = new uint256[](positionCount);
        zeroForOne = new bool[](positionCount);

        for (uint256 i = 0; i < positionCount; i++) {
            ICore.ManagedPositionInfo memory managedPositionInfo = core
                .managedPositionAt(i);
            
            if (managedPositionInfo.ammPositionIds.length == 0) continue;

            (bool flag, ICore.TargetPositionInfo memory target) = core
                .strategyModule()
                .getTargets(
                    managedPositionInfo,
                    core.ammModule(),
                    core.oracle()
                );
            if (!flag) continue;

            (uint160 sqrtPriceX96, , , , , ) = ICLPool(managedPositionInfo.pool).slot0();
            
            (
                ,
                ,
                ,
                ,
                ,
                int24 tickLower,
                int24 tickUpper,
                ,
                ,
                ,
                ,

            ) = positionManager.positions(managedPositionInfo.ammPositionIds[0]);

            uint160 sqrtPriceX96TargetLower = TickMath.getSqrtRatioAtTick(
                target.lowerTicks[0]
            );
            uint160 sqrtPriceX96TargetUpper = TickMath.getSqrtRatioAtTick(
                target.upperTicks[0]
            );

            if (
                sqrtPriceX96 > sqrtPriceX96TargetLower &&
                sqrtPriceX96 < sqrtPriceX96TargetUpper
            ) {
                uint160 sqrtPriceWidthPostion = sqrtPriceX96TargetUpper -
                    sqrtPriceX96TargetLower;
                uint160 sqrtPriceDelta;
                if (sqrtPriceX96 < TickMath.getSqrtRatioAtTick(tickLower)) {
                    /// @dev we have only amount0 and must swap share0X96 into token1
                    sqrtPriceDelta = sqrtPriceX96 - sqrtPriceX96TargetLower;
                    zeroForOne[i] = true;
                } else if (sqrtPriceX96 > TickMath.getSqrtRatioAtTick(tickUpper)) {
                    /// @dev we have only amount1 and must swap share1X96 into token0
                    sqrtPriceDelta = sqrtPriceX96TargetUpper - sqrtPriceX96;
                    zeroForOne[i] = false;
                }
                shareX96[i] = FullMath.mulDiv(
                    sqrtPriceDelta,
                    Q96,
                    sqrtPriceWidthPostion
                );
            }
        }
    }
// [Return] [0, 0, 0, 26970768212937972007379803604 [2.697e28], 20300078980498621700011037303 [2.03e28], 0, 68561615716414635921866073687 [6.856e28], 0, 0, 0, 0], [false, false, false, true, true, false, true, false, false, false, false]
// [Return] [0, 0, 0, 13208756734212272860608015614 [1.32e28], 19831275905403760373214081239 [1.983e28], 0, 0, 0, 0, 0, 0], [false, false, false, true, true, false, false, false, false, false, false]
    function call(
        bytes memory data,
        ICore.TargetPositionInfo[] memory targets
    ) external returns (uint256[][] memory newTokenIds) {
        SwapArbitraryParams[] memory swapParams = abi.decode(
            data,
            (SwapArbitraryParams[])
        );

        // getting liquidity from all position
        for (uint256 i = 0; i < targets.length; i++) {
            uint256 tokenId = targets[i].info.ammPositionIds[0];
            (, , , , , , , uint128 liquidity, , , , ) = positionManager
                .positions(tokenId);
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

        // swapping to target ratio according result of function `necessaryAmountsForMint`
        for (uint256 i = 0; i < swapParams.length; i++) {
            address tokenIn = swapParams[i].tokenIn;
            uint256 balance = IERC20(swapParams[i].tokenIn).balanceOf(
                address(this)
            );
            if (balance < swapParams[i].amountIn) {
                swapParams[i].amountIn = balance;
            }
            if (swapParams[i].amountIn == 0) continue;
            if (
                IERC20(tokenIn).allowance(
                    address(this),
                    swapParams[i].router
                ) == 0
            ) {
                IERC20(tokenIn).forceApprove(
                    swapParams[i].router,
                    type(uint256).max
                );
            }
            (bool success, bytes memory returnData) = swapParams[i].router.call(
                swapParams[i].callData
            );
            require(success, "Swap call failed");
            require(
                IERC20(swapParams[i].tokenOut).balanceOf(address(this)) >=
                    swapParams[i].expectedAmountOut
            );
        }

        // creating new positions with minimal liquidity
        newTokenIds = new uint256[][](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            ICLPool pool = ICLPool(targets[i].info.pool);
            (uint160 sqrtPriceX96, , , , , ) = pool.slot0();
            (uint256 amount0, uint256 amount1) = LiquidityAmounts
                .getAmountsForLiquidity(
                    sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(targets[i].lowerTicks[0]),
                    TickMath.getSqrtRatioAtTick(targets[i].upperTicks[0]),
                    uint128((targets[i].minLiquidities[0] * (D6 + 1)) / D6) + 1
                );

            address token0 = pool.token0();
            if (
                IERC20(token0).allowance(
                    address(this),
                    address(positionManager)
                ) == 0
            ) {
                IERC20(token0).forceApprove(
                    address(positionManager),
                    type(uint256).max
                );
            }
            address token1 = pool.token1();
            if (
                IERC20(token1).allowance(
                    address(this),
                    address(positionManager)
                ) == 0
            ) {
                IERC20(token1).forceApprove(
                    address(positionManager),
                    type(uint256).max
                );
            }

            {
                console2.log(
                    "token0:",
                    IERC20(token0).balanceOf(address(this)),
                    ">=",
                    amount0
                );
                console2.log(
                    "token1:",
                    IERC20(token1).balanceOf(address(this)),
                    ">=",
                    amount1
                );
            }

            (uint256 tokenId, uint128 actualLiquidity, , ) = positionManager
                .mint(
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
