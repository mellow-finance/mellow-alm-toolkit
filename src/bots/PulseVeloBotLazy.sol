// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../interfaces/bots/IPulseVeloBotLazy.sol";
import "src/interfaces/modules/strategies/IPulseStrategyModule.sol";
import "src/interfaces/utils/IVeloDeployFactory.sol";

import "../libraries/external/LiquidityAmounts.sol";
import "../libraries/external/TickMath.sol";

contract PulseVeloBotLazy is IPulseVeloBotLazy {
    using SafeERC20 for IERC20;

    uint256 public constant Q128 = 2 ** 128;
    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D6 = 1e6;

    INonfungiblePositionManager public immutable positionManager;

    ICore public immutable core;
    IVeloDeployFactory public immutable fatory;

    constructor(address positionManager_, address core_, address fatory_) {
        positionManager = INonfungiblePositionManager(positionManager_);
        core = ICore(core_);
        fatory = IVeloDeployFactory(fatory_);
    }

    /// @dev returns quotes for swap
    /// @param pool address of Pool
    /// @param priceTargetX96 actual price of exchange token0<->token1: 2^96 * amount0/amount1
    /// @return swapQuoteParams contains ecessery amountIn amd amountOut to swap for desired target position
    function necessarySwapAmountForMint(
        address pool,
        uint256 priceTargetX96
    ) external view returns (SwapQuoteParams memory swapQuoteParams) {
        uint256 positionId = poolPositionId(pool);
        if (!_needRebalancePosition(positionId)) return swapQuoteParams;
        ICore.ManagedPositionInfo memory managedPositionInfo = core
            .managedPositionAt(positionId);

        if (managedPositionInfo.ammPositionIds.length == 0)
            return swapQuoteParams;

        (bool flag, ICore.TargetPositionInfo memory target) = core
            .strategyModule()
            .getTargets(managedPositionInfo, core.ammModule(), core.oracle());
        if (!flag) return swapQuoteParams;

        swapQuoteParams = _necessarySwapAmountForMint(
            priceTargetX96,
            target,
            managedPositionInfo
        );
    }

    /// @dev returns array of flags, true if rebalance is necessery
    function needRebalance(
        address[] memory poolAddress
    ) public view returns (bool[] memory needs) {
        needs = new bool[](poolAddress.length);
        for (uint256 i = 0; i < poolAddress.length; i++) {
            uint256 positionId = poolPositionId(poolAddress[i]);
            needs[i] = _needRebalancePosition(positionId);
        }
    }

    function poolPositionId(
        address pool
    ) public view returns (uint256 positionId) {
        IVeloDeployFactory.PoolAddresses memory poolAddresses = fatory
            .poolToAddresses(pool);
        ILpWrapper lpWrapper = ILpWrapper(payable(poolAddresses.lpWrapper));
        positionId = lpWrapper.positionId();
    }

    function needRebalancePosition(address pool) public view returns (bool) {
        uint256 positionId = poolPositionId(pool);
        return _needRebalancePosition(positionId);
    }

    function _needRebalancePosition(
        uint256 managedPositionId
    ) internal view returns (bool) {
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
        uint256 priceTargetX96,
        ICore.TargetPositionInfo memory target,
        ICore.ManagedPositionInfo memory managedPositionInfo
    ) private view returns (SwapQuoteParams memory swapQuoteParams) {
        ICLPool pool = ICLPool(managedPositionInfo.pool);
        (uint160 sqrtPriceX96, , , , , ) = pool.slot0();

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
            return
                _fitAmountInForTargetSwapPrice(
                    pool,
                    priceTargetX96,
                    sqrtPriceX96TargetLower,
                    sqrtPriceX96TargetUpper,
                    managedPositionInfo
                );
        }
    }

    function _getTargetAmounts(
        ICLPool pool,
        uint160 sqrtPriceX96TargetLower,
        uint160 sqrtPriceX96TargetUpper,
        ICore.ManagedPositionInfo memory managedPositionInfo
    )
        internal
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 amount0Target,
            uint256 amount1Target
        )
    {
        uint160 sqrtPriceX96Lower;
        uint160 sqrtPriceX96Upper;
        (uint160 sqrtPriceX96, , , , , ) = pool.slot0();
        uint128 liquidityTarget;
        {
            (
                ,
                ,
                ,
                ,
                ,
                int24 tickLower,
                int24 tickUpper,
                uint128 liquidityCurrent,
                ,
                ,
                ,

            ) = positionManager.positions(
                    managedPositionInfo.ammPositionIds[0]
                );

            sqrtPriceX96Lower = TickMath.getSqrtRatioAtTick(tickLower);
            sqrtPriceX96Upper = TickMath.getSqrtRatioAtTick(tickUpper);

            uint160 sqrtPricex96WidthTargetPostion = sqrtPriceX96TargetUpper -
                sqrtPriceX96TargetLower;
            uint160 sqrtPricex96WidthCurrentPostion = sqrtPriceX96Upper -
                sqrtPriceX96Lower;

            liquidityCurrent = uint128((liquidityCurrent * (D6 + 1)) / D6) + 1;

            /// @dev fit liquidity due to change of sqrtPrice range
            liquidityTarget = uint128(
                FullMath.mulDiv(
                    uint256(liquidityCurrent),
                    sqrtPricex96WidthTargetPostion,
                    sqrtPricex96WidthCurrentPostion
                )
            );
            /// @dev current amounts at position
            (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                sqrtPriceX96Lower,
                sqrtPriceX96Upper,
                liquidityCurrent
            );
        }

        /// @dev target amounts at position
        (amount0Target, amount1Target) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                sqrtPriceX96TargetLower,
                sqrtPriceX96TargetUpper,
                liquidityTarget
            );
    }

    /// @param priceTargetX96 relation 2^96 * amountInDelta/amountOutDelta
    function _fitAmountInForTargetSwapPrice(
        ICLPool pool,
        uint256 priceTargetX96,
        uint160 sqrtPriceX96TargetLower,
        uint160 sqrtPriceX96TargetUpper,
        ICore.ManagedPositionInfo memory managedPositionInfo
    ) internal view returns (SwapQuoteParams memory swapQuoteParams) {
        {
            address token0 = pool.token0();
            address token1 = pool.token1();
            (
                uint256 amount0,
                uint256 amount1,
                uint256 amount0Target,
                uint256 amount1Target
            ) = _getTargetAmounts(
                    pool,
                    sqrtPriceX96TargetLower,
                    sqrtPriceX96TargetUpper,
                    managedPositionInfo
                );

            /// @dev by default token in is token1, so amount0Target/amount1Target
            uint256 relationTargetX96 = FullMath.mulDiv(
                amount0Target,
                Q96,
                amount1Target
            );


            if (amount0Target > amount0) {
                /// @dev swap token1 -> token0, tokenIn is token1
                swapQuoteParams.tokenIn = token1;
                swapQuoteParams.tokenOut = token0;
            } else if (amount1Target > amount1) {
                /// @dev swap token0 -> token1, tokenIn is token0
                swapQuoteParams.tokenIn = token0;
                swapQuoteParams.tokenOut = token1;
                /// @dev relationTargetX96 invert relation -> amount1Target/amount0Target
                relationTargetX96 = FullMath.mulDiv(
                    Q96,
                    Q96,
                    relationTargetX96
                );
            }

            uint256 anountInTotal;

            if (swapQuoteParams.tokenIn == token1) {
                anountInTotal = amount1;
                swapQuoteParams.amountIn = amount1 - amount1Target;
                swapQuoteParams.amountOut = amount0;
            }
            if (swapQuoteParams.tokenIn == token0) {
                anountInTotal = amount0;
                swapQuoteParams.amountIn = amount0 - amount0Target;
                swapQuoteParams.amountOut = amount1;
            }

            /// @dev if priceTarget is equal to 0 (not defined)
            if (priceTargetX96 == 0) return swapQuoteParams;

            /// @dev just to save stack space, calculate (priceTarget + relationTarget)
            priceTargetX96 += relationTargetX96;

            /// @dev amountIn = (relationTarget * anountInTotal - anountOutTotal)/(priceTarget + relationTarget)
            swapQuoteParams.amountIn = FullMath.mulDiv(
                anountInTotal,
                relationTargetX96,
                priceTargetX96
            );
            //swapQuoteParams.errorX96 = relationTargetX96;
        }
        swapQuoteParams.amountIn -= FullMath.mulDiv(
            swapQuoteParams.amountOut,
            Q96,
            priceTargetX96
        );

        /// @dev recalc actual amountOut
        /* swapQuoteParams.amountOut = FullMath.mulDiv(
            swapQuoteParams.amountIn,
            priceTargetX96,
            Q96
        );
        uint256 relationActualX96 = FullMath.mulDiv(
            swapQuoteParams.amountOut,
            Q96,
            swapQuoteParams.amountIn
        );

        /// @dev calc related errorX96
        if (relationActualX96 > swapQuoteParams.errorX96){
            swapQuoteParams.errorX96 = relationActualX96 - swapQuoteParams.errorX96;
        } else {
            swapQuoteParams.errorX96 = swapQuoteParams.errorX96 - relationActualX96;
        } */
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
