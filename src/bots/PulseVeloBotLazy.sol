// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../interfaces/bots/IPulseVeloBotLazy.sol";
import "src/interfaces/modules/strategies/IPulseStrategyModule.sol";

import "../libraries/external/LiquidityAmounts.sol";
import "../libraries/external/TickMath.sol";

contract PulseVeloBotLazy is IPulseVeloBotLazy {
    using SafeERC20 for IERC20;

    uint256 public constant Q128 = 2 ** 128;
    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D6 = 1e6;

    INonfungiblePositionManager public immutable positionManager;

    ICore public immutable core;

    constructor(address positionManager_, address core_) {
        positionManager = INonfungiblePositionManager(positionManager_);
        core = ICore(core_);
    }

    /// @dev returns quotes for swap
    /// @param swapQuoteParams contains ecessery amountIn amd amountOut to swap for desired target position
    function necessarySwapAmountForMint(
        uint256 positionId
    ) external view returns (SwapQuoteParams memory swapQuoteParams) {
        if (!needRebalancePosition(positionId)) return swapQuoteParams;
        ICore.ManagedPositionInfo memory managedPositionInfo = core
            .managedPositionAt(positionId);

        if (managedPositionInfo.ammPositionIds.length == 0)
            return swapQuoteParams;

        (bool flag, ICore.TargetPositionInfo memory target) = core
            .strategyModule()
            .getTargets(managedPositionInfo, core.ammModule(), core.oracle());
        if (!flag) return swapQuoteParams;

        swapQuoteParams = _necessarySwapAmountForMint(
            target,
            managedPositionInfo
        );
    }

    /// @dev returns array of flags, true if rebalance is necessery
    function needRebalance(
        uint256[] memory postionIds
    ) public view returns (bool[] memory needs) {
        needs = new bool[](postionIds.length);
        for (uint256 i = 0; i < postionIds.length; i++) {
            needs[i] = needRebalancePosition(postionIds[i]);
        }
    }

    function needRebalancePosition(
        uint256 managedPositionId
    ) public view returns (bool) {
        ICore.ManagedPositionInfo memory managedPositionInfo = core
            .managedPositionAt(managedPositionId);

        ICLPool pool = ICLPool(managedPositionInfo.pool);
        uint256 positionCount = managedPositionInfo.ammPositionIds.length;

        for (uint ammId = 0; ammId < positionCount; ammId++) {
            uint256 tokenId = managedPositionInfo.ammPositionIds[ammId];
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

            ) = positionManager.positions(tokenId);
            (, int24 tick, , , , ) = pool.slot0();

            IPulseStrategyModule.StrategyParams memory params = abi.decode(
                managedPositionInfo.strategyParams,
                (IPulseStrategyModule.StrategyParams)
            );
            if (tick < tickLower) {
                if (tickLower - tick > params.tickNeighborhood) {
                    return true;
                }
            } else if (tick > tickUpper) {
                if (tick - tickUpper > params.tickNeighborhood) {
                    return true;
                }
            }
        }

        return false;
    }

    function _necessarySwapAmountForMint(
        ICore.TargetPositionInfo memory target,
        ICore.ManagedPositionInfo memory managedPositionInfo
    ) private view returns (SwapQuoteParams memory swapQuoteParams) {
        ICLPool pool = ICLPool(managedPositionInfo.pool);
        (uint160 sqrtPriceX96, , , , , ) = pool.slot0();

        (
            ,
            ,
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
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

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                uint128((liquidity * (D6 + 1)) / D6) + 1
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
                swapQuoteParams.tokenIn = pool.token0();
                swapQuoteParams.tokenOut = pool.token1();
                swapQuoteParams.amountIn = amount0;
            } else if (sqrtPriceX96 > TickMath.getSqrtRatioAtTick(tickUpper)) {
                /// @dev we have only amount1 and must swap share1X96 into token0
                sqrtPriceDelta = sqrtPriceX96TargetUpper - sqrtPriceX96;
                swapQuoteParams.tokenIn = pool.token1();
                swapQuoteParams.tokenOut = pool.token0();
                swapQuoteParams.amountIn = amount1;
            }
            swapQuoteParams.amountIn =
                FullMath.mulDiv(
                    swapQuoteParams.amountIn,
                    sqrtPriceDelta,
                    sqrtPriceWidthPostion
                ) +
                1;
        }
    }

    function call(
        bytes memory data,
        ICore.TargetPositionInfo[] memory targets
    ) external returns (uint256[][] memory newTokenIds) {
        SwapParams[] memory swapParams = abi.decode(data, (SwapParams[]));
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

        // swapping to target ratio according result of function `necessarySwapAmountForMint`
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
            uint256 tokenOutBalanceBefore = IERC20(swapParams[i].tokenOut)
                .balanceOf(address(this));
            (bool success, bytes memory returnData) = swapParams[i].router.call(
                swapParams[i].callData
            );
            require(success, "Swap call failed");

            uint256 amountOutDelta = IERC20(swapParams[i].tokenOut).balanceOf(
                address(this)
            ) - tokenOutBalanceBefore;

            /// @dev 32 - just actual amount out
            if (returnData.length == 32) {
                require(
                    abi.decode(returnData, (uint256)) == amountOutDelta,
                    string(
                        abi.encodePacked(
                            "Wrong amount out after swap",
                            abi.decode(returnData, (uint256)),
                            amountOutDelta
                        )
                    )
                );

                require(
                    amountOutDelta >= swapParams[i].expectedAmountOut,
                    string(
                        abi.encodePacked(
                            "Min return: want ",
                            Strings.toString(swapParams[i].expectedAmountOut),
                            "; actual: ",
                            Strings.toString(amountOutDelta)
                        )
                    )
                );
                /// @dev revert string Error(string)
            } else {
                assembly {
                    let returndata_size := mload(returnData)
                    revert(add(32, returnData), returndata_size)
                }
            }
        }

        // creating new positions with minimal liquidity
        newTokenIds = new uint256[][](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            ICLPool pool = ICLPool(targets[i].info.pool);

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
