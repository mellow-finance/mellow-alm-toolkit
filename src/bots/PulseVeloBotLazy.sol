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
    using Math for uint256;

    uint256 public constant Q128 = 2 ** 128;
    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D6 = 1e6;

    INonfungiblePositionManager public immutable positionManager;

    ICore public immutable core;
    IVeloDeployFactory public immutable fatory;
    IPulseStrategyModule public immutable strategyModule;

    constructor(address positionManager_, address core_, address fatory_) {
        positionManager = INonfungiblePositionManager(positionManager_);
        core = ICore(core_);
        fatory = IVeloDeployFactory(fatory_);
        strategyModule = IPulseStrategyModule(address(core.strategyModule()));
    }

    /// @dev returns quotes for swap
    /// @param pool address of Pool
    /// @param priceTargetX96 actual price of exchange token0<->token1: 2^96 * amount0/amount1
    /// @return swapQuoteParams contains ecessery amountIn amd amountOut to swap for desired target position
    function necessarySwapAmountForMint(
        address pool,
        uint256 priceTargetX96
    ) external view returns (SwapQuoteParams memory swapQuoteParams) {
        if (!needRebalancePosition(pool)) return swapQuoteParams;

        ICore.ManagedPositionInfo memory managedPositionInfo = core
            .managedPositionAt(poolPositionId(pool));

        if (managedPositionInfo.ammPositionIds.length == 0)
            return swapQuoteParams;

        (
            bool isRebalanceRequired,
            ICore.TargetPositionInfo memory target
        ) = strategyModule.getTargets(
                managedPositionInfo,
                core.ammModule(),
                core.oracle()
            );

        if (!isRebalanceRequired) return swapQuoteParams;
        require(target.lowerTicks.length == 1, "lowerTicks lenght");
        require(target.upperTicks.length == 1, "upperTicks lenght");

        swapQuoteParams = _fitAmountInForTargetSwapPrice(
            ICLPool(pool),
            priceTargetX96,
            managedPositionInfo,
            target
        );
    }

    /// @dev return current positionId for @param pool
    function poolPositionId(
        address pool
    ) public view returns (uint256 positionId) {
        IVeloDeployFactory.PoolAddresses memory poolAddresses = fatory
            .poolToAddresses(pool);
        ILpWrapper lpWrapper = ILpWrapper(payable(poolAddresses.lpWrapper));
        positionId = lpWrapper.positionId();
    }

    /// @dev returns flags, true if rebalance is necessery
    function needRebalancePosition(
        address pool
    ) public view returns (bool isRebalanceRequired) {
        uint256 positionId = poolPositionId(pool);
        ICore.ManagedPositionInfo memory managedPositionInfo = core
            .managedPositionAt(positionId);

        uint256 tokenId = managedPositionInfo.ammPositionIds[0];
        (, , , , , int24 tickLower, int24 tickUpper, , , , , ) = positionManager
            .positions(tokenId);
        (, int24 tick, , , , ) = ICLPool(pool).slot0();

        IPulseStrategyModule.StrategyParams memory params = abi.decode(
            managedPositionInfo.strategyParams,
            (IPulseStrategyModule.StrategyParams)
        );

        (isRebalanceRequired, ) = strategyModule.calculateTarget(
            tick,
            tickLower,
            tickUpper,
            params
        );
    }

    /// @param priceTargetX96 relation 2^96 * amountInDelta/amountOutDelta
    function _fitAmountInForTargetSwapPrice(
        ICLPool pool,
        uint256 priceTargetX96,
        ICore.ManagedPositionInfo memory managedPositionInfo,
        ICore.TargetPositionInfo memory target
    ) internal view returns (SwapQuoteParams memory swapQuoteParams) {
        address[2] memory tokens;
        uint256[2] memory amounts;
        uint256[2] memory amountsTarget;

        tokens[0] = pool.token0();
        tokens[1] = pool.token1();
        (
            amounts[0],
            amounts[1],
            amountsTarget[0],
            amountsTarget[1]
        ) = _getTargetAmounts(pool, managedPositionInfo, target);

        uint256 tokenIdIn = (amountsTarget[0] > amounts[0]) ? 1 : 0;
        uint256 tokenIdOut = tokenIdIn == 0 ? 1 : 0;

        if (amountsTarget[tokenIdIn] == 0) return swapQuoteParams;

        /// @dev relation between amountTargetOut/amountTargetIn
        uint256 relationTargetX96 = amountsTarget[tokenIdOut].mulDiv(
            Q96,
            amountsTarget[tokenIdIn]
        );

        /// @dev take price from pool, if given swap price is zero
        if (priceTargetX96 == 0) {
            (uint160 sqrtPriceX96, , , , , ) = pool.slot0();
            priceTargetX96 = uint256(sqrtPriceX96).mulDiv(sqrtPriceX96, Q96);
        }

        /// @dev amountIn = (relationTarget * anountInTotal - anountOutTotal)/(priceTarget + relationTarget)
        uint256 priceDenominatorX96 = priceTargetX96 + relationTargetX96;
        swapQuoteParams.amountIn = amounts[tokenIdIn].mulDiv(
            relationTargetX96,
            priceDenominatorX96
        );
        swapQuoteParams.amountIn -= amounts[tokenIdOut].mulDiv(
            Q96,
            priceDenominatorX96
        );

        swapQuoteParams.tokenIn = tokens[tokenIdIn];
        swapQuoteParams.tokenOut = tokens[tokenIdOut];
    }

    function _getTargetAmounts(
        ICLPool pool,
        ICore.ManagedPositionInfo memory managedPositionInfo,
        ICore.TargetPositionInfo memory target
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
        (uint160 sqrtPriceX96, , , , , ) = pool.slot0();
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;

        (, , , , , tickLower, tickUpper, liquidity, , , , ) = positionManager
            .positions(managedPositionInfo.ammPositionIds[0]);

        uint160 sqrtPricex96Lower = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPricex96Upper = TickMath.getSqrtRatioAtTick(tickUpper);

        /// @dev current amounts for current position
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            sqrtPricex96Lower,
            sqrtPricex96Upper,
            liquidity
        );

        uint160 sqrtPricex96LowerTarget = TickMath.getSqrtRatioAtTick(
            target.lowerTicks[0]
        );
        uint160 sqrtPricex96UpperTarget = TickMath.getSqrtRatioAtTick(
            target.upperTicks[0]
        );

        /// @dev fit liquidity due to change of sqrtPrice diff
        uint128 liquidityTarget = uint128(
            uint256(liquidity).mulDiv(
                sqrtPricex96UpperTarget - sqrtPricex96LowerTarget,
                sqrtPricex96Upper - sqrtPricex96Lower
            )
        );

        /// @dev current amounts for target position
        (amount0Target, amount1Target) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                sqrtPricex96LowerTarget,
                sqrtPricex96UpperTarget,
                liquidityTarget
            );
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
