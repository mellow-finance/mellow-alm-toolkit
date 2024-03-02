// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/oracles/IVeloOracle.sol";

import "../libraries/external/FullMath.sol";
import "../libraries/external/TickMath.sol";

contract VeloOracle is IVeloOracle {
    /// @inheritdoc IVeloOracle
    function ensureNoMEV(
        address poolAddress,
        bytes memory params
    ) external view override {
        if (params.length == 0) return;
        (
            ,
            int24 spotTick,
            uint16 observationIndex,
            uint16 observationCardinality,
            ,

        ) = ICLPool(poolAddress).slot0();
        SecurityParams memory securityParams = abi.decode(
            params,
            (SecurityParams)
        );
        uint16 lookback = securityParams.lookback;
        if (observationCardinality < lookback + 1)
            revert NotEnoughObservations();

        (uint32 nextTimestamp, int56 nextCumulativeTick, , ) = ICLPool(
            poolAddress
        ).observations(observationIndex);
        int24 nextTick = spotTick;
        int24 maxAllowedDelta = securityParams.maxAllowedDelta;
        for (uint16 i = 1; i <= lookback; i++) {
            uint256 index = (observationCardinality + observationIndex - i) %
                observationCardinality;
            (uint32 timestamp, int56 tickCumulative, , ) = ICLPool(poolAddress)
                .observations(index);
            int24 tick = int24(
                (nextCumulativeTick - tickCumulative) /
                    int56(uint56(nextTimestamp - timestamp))
            );
            (nextTimestamp, nextCumulativeTick) = (timestamp, tickCumulative);
            int24 delta = nextTick - tick;
            if (delta > maxAllowedDelta || delta < -maxAllowedDelta)
                revert PriceManipulationDetected();
            nextTick = tick;
        }
    }

    /// @inheritdoc IVeloOracle
    function getOraclePrice(
        address pool
    ) external view override returns (uint160, int24) {
        (
            uint160 spotSqrtPriceX96,
            int24 spotTick,
            uint16 observationIndex,
            uint16 observationCardinality,
            ,

        ) = ICLPool(pool).slot0();
        if (observationCardinality < 2) revert NotEnoughObservations();
        (uint32 blockTimestamp, int56 tickCumulative, , ) = ICLPool(pool)
            .observations(observationIndex);
        if (block.timestamp != blockTimestamp)
            return (spotSqrtPriceX96, spotTick);
        uint16 previousObservationIndex = observationCardinality - 1;
        if (observationIndex != 0)
            previousObservationIndex = observationIndex - 1;
        if (previousObservationIndex == observationCardinality)
            revert NotEnoughObservations();
        (
            uint32 previousBlockTimestamp,
            int56 previousTickCumulative,
            ,

        ) = ICLPool(pool).observations(previousObservationIndex);
        int56 tickCumulativesDelta = tickCumulative - previousTickCumulative;
        int24 tick = int24(
            tickCumulativesDelta /
                int56(uint56(blockTimestamp - previousBlockTimestamp))
        );
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
        return (sqrtPriceX96, tick);
    }

    /// @inheritdoc IVeloOracle
    function validateSecurityParams(
        bytes memory params
    ) external pure override {
        if (params.length == 0) return;
        if (params.length != 0x40) revert InvalidLength();
        SecurityParams memory securityParams = abi.decode(
            params,
            (SecurityParams)
        );
        if (securityParams.lookback == 0 || securityParams.maxAllowedDelta < 0)
            revert InvalidParams();
    }
}
