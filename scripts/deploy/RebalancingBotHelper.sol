// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import "../bots/interfaces/IRebalancingBotHelper.sol";
import "../../src/interfaces/utils/IVeloDeployFactory.sol";
import "../../src/modules/strategies/PulseStrategyModule.sol";


contract RebalancingBotHelper is IRebalancingBotHelper {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 public constant Q128 = 2 ** 128;
    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D6 = 1e6;

    INonfungiblePositionManager public immutable positionManager;

    ICore public immutable core;
    IVeloDeployFactory public immutable factory;
    IPulseStrategyModule public immutable strategyModule;

    constructor(address positionManager_, address core_, address factory_) {
        positionManager = INonfungiblePositionManager(positionManager_);
        core = ICore(core_);
        factory = IVeloDeployFactory(factory_);
        strategyModule = IPulseStrategyModule(address(core.strategyModule()));
    }

    /// @dev returns quotes for swap
    /// @param pool address of Pool
    /// @param priceTargetX96 actual price of exchange tokenIn<->tokenOut: 2^96 * amountOut/amountIn
    /// @return swapQuoteParams contains ecessery amountIn amd amountOut to swap for desired target position
    function necessarySwapAmountForMint(address pool, uint256 priceTargetX96)
        external
        view
        returns (SwapQuoteParams memory swapQuoteParams)
    {
        if (!needRebalancePosition(pool)) {
            return swapQuoteParams;
        }

        (, ICore.ManagedPositionInfo memory managedPositionInfo) = poolManagedPositionInfo(pool);

        if (managedPositionInfo.ammPositionIds.length == 0) {
            return swapQuoteParams;
        }

        (bool isRebalanceRequired, ICore.TargetPositionInfo memory target) =
            strategyModule.getTargets(managedPositionInfo, core.ammModule(), core.oracle());

        if (!isRebalanceRequired) {
            return swapQuoteParams;
        }
        require(target.lowerTicks.length == 1, "lowerTicks lenght");
        require(target.upperTicks.length == 1, "upperTicks lenght");

        swapQuoteParams =
            _fitAmountInForTargetSwapPrice(priceTargetX96, managedPositionInfo, target);
    }

    /// @dev return current positionId for @param pool
    function poolManagedPositionInfo(address pool)
        public
        view
        returns (uint256 positionId, ICore.ManagedPositionInfo memory managedPositionInfo)
    {
        ILpWrapper lpWrapper = ILpWrapper(factory.poolToWrapper(pool));
        positionId = lpWrapper.positionId();
        managedPositionInfo = core.managedPositionAt(positionId);
    }

    /// @dev returns flags, true if rebalance is necessery for @param pool
    function needRebalancePosition(address pool)
        public
        view
        returns (bool isRebalanceRequired)
    {
        (, ICore.ManagedPositionInfo memory managedPositionInfo) = poolManagedPositionInfo(pool);
        (isRebalanceRequired,) = strategyModule.getTargets(managedPositionInfo,
            core.ammModule(), core.oracle());
    }

    /**
     * @param priceTargetX96 relation 2^96 * amountOut/amountIn
     * @param managedPositionInfo struct with current managed position info
     * @param target struct with tagret position info
     */
    function _fitAmountInForTargetSwapPrice(
        uint256 priceTargetX96,
        ICore.ManagedPositionInfo memory managedPositionInfo,
        ICore.TargetPositionInfo memory target
    ) internal view returns (SwapQuoteParams memory swapQuoteParams) {
        address[2] memory tokens;
        uint256[2] memory amounts;
        uint256 tokenIdIn;
        uint256 relationTargetX96;

        ICLPool pool = ICLPool(managedPositionInfo.pool);
        tokens[0] = pool.token0();
        tokens[1] = pool.token1();
        (uint160 sqrtPriceX96,,,,,) = pool.slot0();

        (amounts[0], amounts[1], tokenIdIn, relationTargetX96) =
            _getTargetAmounts(sqrtPriceX96, managedPositionInfo, target);

        if (relationTargetX96 == 0) {
            return swapQuoteParams;
        }

        uint256 tokenIdOut = tokenIdIn == 0 ? 1 : 0;

        /// @dev take price from pool, if given swap price is zero
        if (priceTargetX96 == 0) {
            priceTargetX96 = uint256(sqrtPriceX96).mulDiv(sqrtPriceX96, Q96);
        }

        /// @dev amountIn = (relationTarget * anountInTotal - anountOutTotal)/(priceTarget + relationTarget)
        uint256 priceDenominatorX96 = priceTargetX96 + relationTargetX96;
        swapQuoteParams.amountIn = amounts[tokenIdIn].mulDiv(relationTargetX96, priceDenominatorX96);
        swapQuoteParams.amountIn -= amounts[tokenIdOut].mulDiv(Q96, priceDenominatorX96);

        swapQuoteParams.tokenIn = tokens[tokenIdIn];
        swapQuoteParams.tokenOut = tokens[tokenIdOut];
    }

    /**
     *
     * @param sqrtPriceX96 current sqrtPriceX96 at pool
     * @param managedPositionInfo struct with current managed position info
     * @param target struct with tagret position info
     * @return amount0 amount of token0 in current managed position
     * @return amount1 amount of token1 in current managed position
     * @return tokenIdIn index of input for swap token
     * @return relationTargetX96 relation between amount in target position: amountTargetOut/amountTargetIn
     */

    function _getTargetAmounts(
        uint160 sqrtPriceX96,
        ICore.ManagedPositionInfo memory managedPositionInfo,
        ICore.TargetPositionInfo memory target
    )
        internal
        view
        returns (uint256 amount0, uint256 amount1, uint256 tokenIdIn, uint256 relationTargetX96)
    {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;

        (,,,,, tickLower, tickUpper, liquidity,,,,) =
            positionManager.positions(managedPositionInfo.ammPositionIds[0]);

        {
            uint160 sqrtPricex96Lower = TickMath.getSqrtRatioAtTick(tickLower);
            uint160 sqrtPricex96Upper = TickMath.getSqrtRatioAtTick(tickUpper);

            /// @dev current amounts for current position
            (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96, sqrtPricex96Lower, sqrtPricex96Upper, liquidity
            );

            /// @dev check if position is active
            if (sqrtPriceX96 <= sqrtPricex96Upper && sqrtPriceX96 >= sqrtPricex96Lower) {
                return (amount0, amount1, 0, 0);
            }

            /// @dev index of input token for swap
            tokenIdIn = sqrtPriceX96 > sqrtPricex96Upper ? 1 : 0;
        }

        /// @dev current amounts for target position
        (uint256 amount0Target, uint256 amount1Target) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(target.lowerTicks[0]),
            TickMath.getSqrtRatioAtTick(target.upperTicks[0]),
            uint128(Q96)
        );

        /// @dev relation between amountTargetOut/amountTargetIn
        if (tokenIdIn == 0) {
            relationTargetX96 = amount1Target.mulDiv(Q96, amount0Target);
        } else {
            relationTargetX96 = amount0Target.mulDiv(Q96, amount1Target);
        }
    }
}
