// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../interfaces/modules/IStrategyModule.sol";

import "../../libraries/external/FullMath.sol";

contract LStrategyModule is IStrategyModule {
    error InvalidParams();
    error InvalidLength();

    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D4 = 1e4;

    struct StrategyParams {
        uint256 maxLiquidityRatioDeviationX96;
    }

    function validateStrategyParams(
        bytes memory params
    ) external pure override {
        StrategyParams memory strategyParams = abi.decode(
            params,
            (StrategyParams)
        );
        if (
            strategyParams.maxLiquidityRatioDeviationX96 == 0 ||
            strategyParams.maxLiquidityRatioDeviationX96 > Q96 / 2
        ) {
            revert InvalidParams();
        }
    }

    function calculateTarget(
        int24 tickLower,
        int24 half,
        int24 tick
    ) public pure returns (int24 targetLower, uint256 liquidityRatioX96) {
        int24 width = half * 2;
        if (tick < tickLower + half) {
            targetLower = tickLower - half;
        } else if (tick > tickLower + width) {
            targetLower = tickLower + half;
        } else {
            targetLower = tickLower;
        }
        if (tickLower + half >= tick) {
            liquidityRatioX96 = Q96;
        } else if (tickLower + width <= tick) {
            liquidityRatioX96 = 0;
        } else {
            int24 delta = tickLower + width - tick;
            liquidityRatioX96 = FullMath.mulDiv(
                uint24(delta),
                Q96,
                uint24(half)
            );
        }
    }

    function getTargets(
        ICore.NftsInfo memory info,
        IAmmModule ammModule,
        IOracle oracle
    )
        external
        view
        override
        returns (bool isRebalanceRequired, ICore.TargetNftsInfo memory target)
    {
        {
            int24 tick;
            (, tick) = oracle.getOraclePrice(info.pool);
            if (info.tokenIds.length != 2) {
                revert InvalidLength();
            }
            IAmmModule.Position memory lowerPosition = ammModule
                .getPositionInfo(info.tokenIds[0]);
            IAmmModule.Position memory upperPosition = ammModule
                .getPositionInfo(info.tokenIds[1]);

            int24 width = lowerPosition.tickUpper - lowerPosition.tickLower;
            int24 half = width / 2;

            if (
                half % 2 != 0 ||
                upperPosition.tickLower != lowerPosition.tickLower + half ||
                upperPosition.tickUpper != lowerPosition.tickUpper + half
            ) {
                revert InvalidLength();
            }

            (int24 targetLower, uint256 targetRatioX96) = calculateTarget(
                lowerPosition.tickLower,
                half,
                tick
            );

            StrategyParams memory strategyParams = abi.decode(
                info.strategyParams,
                (StrategyParams)
            );

            uint256 ratioX96 = FullMath.mulDiv(
                lowerPosition.liquidity,
                Q96,
                lowerPosition.liquidity + upperPosition.liquidity
            );

            target.lowerTicks = new int24[](2);
            target.upperTicks = new int24[](2);
            target.lowerTicks[0] = targetLower;
            target.lowerTicks[1] = targetLower + half;
            target.upperTicks[0] = targetLower + width;
            target.upperTicks[1] = targetLower + half + width;
            target.liquidityRatiosX96 = new uint256[](2);
            target.liquidityRatiosX96[0] = ratioX96;
            target.liquidityRatiosX96[1] = Q96 - ratioX96;

            uint256 maxDeviationX96 = strategyParams
                .maxLiquidityRatioDeviationX96;

            if (targetLower == lowerPosition.tickLower) {
                if (
                    ratioX96 + maxDeviationX96 > targetRatioX96 ||
                    targetRatioX96 + maxDeviationX96 > ratioX96
                ) {
                    return (true, target);
                }
            } else if (targetLower + half == lowerPosition.tickLower) {
                uint256 upperRatioX96 = Q96 - ratioX96;
                if (
                    targetRatioX96 + maxDeviationX96 > upperRatioX96 ||
                    upperRatioX96 + maxDeviationX96 > targetRatioX96
                ) {
                    return (true, target);
                }
            } else if (targetLower - half == lowerPosition.tickLower) {
                uint256 targetUpperRatioX96 = Q96 - targetRatioX96;
                if (
                    targetUpperRatioX96 + maxDeviationX96 > ratioX96 ||
                    ratioX96 + maxDeviationX96 > targetUpperRatioX96
                ) {
                    return (true, target);
                }
            }
        }

        return (false, target);
    }
}
