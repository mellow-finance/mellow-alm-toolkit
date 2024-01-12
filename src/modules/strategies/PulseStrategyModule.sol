// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../interfaces/modules/IStrategyModule.sol";

import "../../libraries/external/FullMath.sol";

contract PulseStrategyModule is IStrategyModule {
    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D4 = 1e4;

    struct StrategyParams {
        int24 tickNeighborhood;
        int24 tickSpacing;
    }

    function validateStrategyParams(
        bytes memory params
    ) external pure override {
        StrategyParams memory strategyParams = abi.decode(
            params,
            (StrategyParams)
        );
        require(strategyParams.tickNeighborhood != 0);
        require(strategyParams.tickSpacing != 0);
    }

    function getTarget(
        IAmmIntent.NftInfo memory info,
        IAmmModule ammModule,
        IOracle oracle
    )
        external
        view
        override
        returns (
            bool isRebalanceRequired,
            IAmmIntent.TargetNftInfo memory target
        )
    {
        uint160 sqrtRatioX96;
        {
            StrategyParams memory strategyParams = abi.decode(
                info.strategyParams,
                (StrategyParams)
            );
            int24 tick;
            (sqrtRatioX96, tick) = oracle.getOraclePrice(
                info.pool,
                info.securityParams
            );
            if (
                tick >= info.tickLower + strategyParams.tickNeighborhood &&
                tick <= info.tickUpper - strategyParams.tickNeighborhood
            ) {
                return (false, target);
            }

            int24 width = info.tickUpper - info.tickLower;
            target.tickLower = tick - width / 2;
            int24 remainder = target.tickLower % strategyParams.tickSpacing;
            if (remainder < 0) remainder += strategyParams.tickSpacing;
            target.tickLower -= remainder;
            target.tickUpper = target.tickLower + width;
        }
        isRebalanceRequired = true;
        uint256 priceX96 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, Q96);

        uint256 targetCapitalQ96;
        {
            (uint256 target0, uint256 target1) = ammModule
                .getAmountsForLiquidity(
                    uint128(Q96),
                    sqrtRatioX96,
                    target.tickLower,
                    target.tickUpper
                );
            targetCapitalQ96 =
                FullMath.mulDiv(target0, priceX96, Q96) +
                target1;
        }

        uint256 currentCapital;
        {
            (uint256 amount0, uint256 amount1) = ammModule.tvl(
                info.tokenId,
                sqrtRatioX96,
                info.pool,
                info.farm
            );
            currentCapital = FullMath.mulDiv(amount0, priceX96, Q96) + amount1;
        }
        target.minLiquidity = uint128(
            FullMath.mulDiv(Q96, currentCapital, targetCapitalQ96)
        );
        target.minLiquidity = uint128(
            FullMath.mulDiv(target.minLiquidity, D4 - info.slippageD4, D4)
        );
    }
}
