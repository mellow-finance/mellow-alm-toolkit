// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/modules/strategies/IPulseStrategyModule.sol";
import "./PositionMath.sol";

/**
 * @dev Helper functions for the PulseStrategyModule.
 */
library PulseStrategyModuleHelper {
    /**
     * @notice Parameters for configuring a pool strategy.
     * @param pool The address of the CLPool.
     * @param strategyParams Strategy parameters defining behavior for the pool.
     * @param maxAmount0 Maximum amount of token0 allowed for the strategy.
     * @param maxAmount1 Maximum amount of token1 allowed for the strategy.
     * @param securityParams Additional security parameters, encoded as bytes, for risk control.
     */
    struct PoolStrategyParameter {
        address pool;
        IPulseStrategyModule.StrategyParams strategyParams;
        uint256 maxAmount0;
        uint256 maxAmount1;
        bytes securityParams;
    }

    /**
     * @dev Retrieves the mint parameters for a given pool strategy.
     * @param params The pool strategy parameters.
     * @param ammModule The AMM module instance.
     * @return mintInfo An array of mint information for the specified strategy.
     */
    function getMintParams(
        PoolStrategyParameter memory params,
        IAmmModule ammModule,
        IPulseStrategyModule pulseStrategyModule
    ) internal view returns (IAmmModule.MintInfo[] memory) {
        (uint160 sqrtPriceX96, int24 tick) = ammModule.getSqrtPriceX96AndTick(params.pool);
        if (params.strategyParams.strategyType == IPulseStrategyModule.StrategyType.Tamper) {
            return getPositionParamTamper(params, sqrtPriceX96, tick, pulseStrategyModule);
        } else {
            return getPositionParamPulse(params, sqrtPriceX96, tick, pulseStrategyModule);
        }
    }

    /**
     * @dev Retrieves the position parameters for the Tamper strategy.
     * @param params The pool strategy parameters.
     * @param sqrtPriceX96 The square root price in X96 format.
     * @param tick The current tick.
     * @param pulseStrategyModule The PulseStrategyModule instance.
     * @return mintInfo An array of mint information for the specified strategy.
     */
    function getPositionParamTamper(
        PoolStrategyParameter memory params,
        uint160 sqrtPriceX96,
        int24 tick,
        IPulseStrategyModule pulseStrategyModule
    ) internal pure returns (IAmmModule.MintInfo[] memory mintInfo) {
        (, ICore.TargetPositionInfo memory target) = pulseStrategyModule.calculateTargetTamper(
            sqrtPriceX96, tick, new IAmmModule.AmmPosition[](0), params.strategyParams
        );
        (uint256 lowerAmount0X96, uint256 lowerAmount1X96) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(target.lowerTicks[0]),
            TickMath.getSqrtRatioAtTick(target.upperTicks[0]),
            uint128(target.liquidityRatiosX96[0])
        );
        (uint256 upperAmount0X96, uint256 upperAmount1X96) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(target.lowerTicks[1]),
            TickMath.getSqrtRatioAtTick(target.upperTicks[1]),
            uint128(PositionMath.Q96 - target.liquidityRatiosX96[0])
        );
        uint256 coefficient = Math.max(
            Math.ceilDiv(lowerAmount0X96 + upperAmount0X96, params.maxAmount0),
            Math.ceilDiv(lowerAmount1X96 + upperAmount1X96, params.maxAmount1)
        );

        mintInfo = new IAmmModule.MintInfo[](2);
        mintInfo[0] = IAmmModule.MintInfo({
            pool: params.pool,
            tickLower: target.lowerTicks[0],
            tickUpper: target.upperTicks[0],
            amount0: lowerAmount0X96 / coefficient,
            amount1: lowerAmount1X96 / coefficient
        });
        mintInfo[1] = IAmmModule.MintInfo({
            pool: params.pool,
            tickLower: target.lowerTicks[1],
            tickUpper: target.upperTicks[1],
            amount0: upperAmount0X96 / coefficient,
            amount1: upperAmount1X96 / coefficient
        });
    }

    /**
     * @dev Retrieves the position parameters for the Pulse strategy.
     * @param params The pool strategy parameters.
     * @param sqrtPriceX96 The square root price in X96 format.
     * @param tick The current tick.
     * @param pulseStrategyModule The PulseStrategyModule instance.
     * @return mintInfo An array of mint information for the specified strategy.
     */
    function getPositionParamPulse(
        PoolStrategyParameter memory params,
        uint160 sqrtPriceX96,
        int24 tick,
        IPulseStrategyModule pulseStrategyModule
    ) internal pure returns (IAmmModule.MintInfo[] memory mintInfo) {
        (, ICore.TargetPositionInfo memory target) = pulseStrategyModule.calculateTargetPulse(
            sqrtPriceX96, tick, new IAmmModule.AmmPosition[](0), params.strategyParams
        );
        mintInfo = new IAmmModule.MintInfo[](1);
        mintInfo[0] = IAmmModule.MintInfo({
            pool: params.pool,
            tickLower: target.lowerTicks[0],
            tickUpper: target.upperTicks[0],
            amount0: params.maxAmount0,
            amount1: params.maxAmount1
        });
    }
}
