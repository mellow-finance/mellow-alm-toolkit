// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/external/univ3/IUniswapV3Pool.sol";
import "../interfaces/oracles/IOracle.sol";

import "../libraries/external/FullMath.sol";
import "../libraries/external/TickMath.sol";

import "../libraries/CommonLibrary.sol";

contract UniV3Oracle is IOracle {
    error NotEnoughObservations();
    error InvalidParams();
    error PriceManipulationDetected();

    struct SecurityParams {
        uint16 anomalyLookback;
        uint16 anomalyOrder;
        uint256 anomalyFactorD9;
    }

    uint256 public constant D9 = 1e9;

    function validateSecurityParams(
        bytes memory params
    ) external pure override {
        SecurityParams memory securityParams = abi.decode(
            params,
            (SecurityParams)
        );
        if (securityParams.anomalyLookback <= securityParams.anomalyOrder)
            revert InvalidParams();
        if (securityParams.anomalyFactorD9 > D9 * 10) revert InvalidParams();
    }

    function getOraclePrice(
        address pool,
        bytes memory
    ) external view override returns (uint160, int24) {
        (
            uint160 spotSqrtPriceX96,
            int24 spotTick,
            uint16 observationIndex,
            uint16 observationCardinality,
            ,
            ,

        ) = IUniswapV3Pool(pool).slot0();
        if (observationCardinality < 2) revert NotEnoughObservations();
        (uint32 blockTimestamp, int56 tickCumulative, , ) = IUniswapV3Pool(pool)
            .observations(observationIndex);
        if (block.timestamp != blockTimestamp)
            return (spotSqrtPriceX96, spotTick);
        uint16 previousObservationIndex = observationCardinality - 1;
        if (observationIndex != 0)
            previousObservationIndex = observationIndex - 1;
        (
            uint32 previousBlockTimestamp,
            int56 previousTickCumulative,
            ,

        ) = IUniswapV3Pool(pool).observations(previousObservationIndex);
        unchecked {
            int56 tickCumulativesDelta = tickCumulative -
                previousTickCumulative;
            int24 tick = int24(
                tickCumulativesDelta /
                    int56(uint56(blockTimestamp - previousBlockTimestamp))
            );
            uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
            return (sqrtPriceX96, tick);
        }
    }

    function ensureNoMEV(
        address pool,
        bytes memory params
    ) external view override {
        if (params.length == 0) return;
        SecurityParams memory securityParams = abi.decode(
            params,
            (SecurityParams)
        );
        uint32[] memory timestamps = new uint32[](
            securityParams.anomalyLookback + 2
        );
        int56[] memory tickCumulatives = new int56[](timestamps.length);
        (
            ,
            int24 spotTick,
            uint16 observationIndex,
            uint16 observationCardinality,
            ,
            ,

        ) = IUniswapV3Pool(pool).slot0();
        if (observationCardinality < timestamps.length) revert InvalidParams();
        for (uint16 i = 0; i < timestamps.length; i++) {
            uint16 index = (observationCardinality + observationIndex - i) %
                observationCardinality;
            (timestamps[i], tickCumulatives[i], , ) = IUniswapV3Pool(pool)
                .observations(index);
        }

        int24[] memory ticks = new int24[](timestamps.length);
        ticks[0] = spotTick;
        for (uint256 i = 0; i + 1 < timestamps.length - 1; i++) {
            unchecked {
                ticks[i + 1] = int24(
                    (tickCumulatives[i] - tickCumulatives[i + 1]) /
                        int56(uint56(timestamps[i] - timestamps[i + 1]))
                );
            }
        }

        uint256[] memory deltas = new uint256[](
            securityParams.anomalyLookback + 1
        );
        for (uint256 i = 0; i < deltas.length; i++) {
            int24 delta = ticks[i] - ticks[i + 1];
            if (delta > 0) delta = -delta;
            deltas[i] = uint256(uint24(delta));
        }
        deltas = CommonLibrary.sort(deltas);
        if (
            deltas[deltas.length - 1] >
            FullMath.mulDiv(
                deltas[securityParams.anomalyOrder],
                securityParams.anomalyFactorD9,
                D9
            )
        ) {
            revert PriceManipulationDetected();
        }
    }
}
