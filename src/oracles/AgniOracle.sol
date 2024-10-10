// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/external/agni/IAgniPool.sol";
import "../interfaces/oracles/IOracle.sol";

import "../libraries/external/FullMath.sol";
import "../libraries/external/TickMath.sol";

/**
 * @title AgniOracle
 * @dev A contract that implements the IOracle interface for Agni pools.
 */
contract AgniOracle is IOracle {
    error InvalidParams();
    error PriceManipulationDetected();
    error NotEnoughObservations();

    /**
     * @dev Ensures that there is no Miner Extractable Value (MEV) manipulation in the AgniPool.
     * @param poolAddress The address of the Agni pool.
     * @param securityParams The parameters for security checks.
     * @notice throws PriceManipulationDetected if MEV manipulation is detected.
     */
    function ensureNoMEV(
        address poolAddress,
        SecurityParams memory securityParams
    ) external view {
        (
            ,
            int24 spotTick,
            uint16 observationIndex,
            uint16 observationCardinality,
            ,
            ,

        ) = IAgniPool(poolAddress).slot0();
        uint16 lookback = securityParams.lookback;
        if (observationCardinality < lookback + 1)
            revert NotEnoughObservations();

        (uint32 nextTimestamp, int56 nextCumulativeTick, , ) = IAgniPool(
            poolAddress
        ).observations(observationIndex);
        int24 nextTick = spotTick;
        int24 maxAllowedDelta = securityParams.maxAllowedDelta;
        for (uint16 i = 1; i <= lookback; i++) {
            uint256 index = (observationCardinality + observationIndex - i) %
                observationCardinality;
            (uint32 timestamp, int56 tickCumulative, , ) = IAgniPool(
                poolAddress
            ).observations(index);
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

    /**
     * @dev Retrieves the price information from an Agni pool oracle.
     * @param pool The address of the Agni pool.
     * @return uint160 square root price of the Agni pool.
     * @return int24 tick of the Agni pool.
     * @notice throws NotEnoughObservations if there are not enough observations in the pool.
     */
    function getOraclePrice(
        address pool
    ) external view override returns (uint160, int24) {
        (
            uint160 spotSqrtPriceX96,
            int24 spotTick,
            uint16 observationIndex,
            uint16 observationCardinality,
            ,
            ,

        ) = IAgniPool(pool).slot0();
        if (observationCardinality < 2) revert NotEnoughObservations();
        (uint32 blockTimestamp, int56 tickCumulative, , ) = IAgniPool(pool)
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

        ) = IAgniPool(pool).observations(previousObservationIndex);
        int56 tickCumulativesDelta = tickCumulative - previousTickCumulative;
        int24 tick = int24(
            tickCumulativesDelta /
                int56(uint56(blockTimestamp - previousBlockTimestamp))
        );
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
        return (sqrtPriceX96, tick);
    }

    /**
     * @dev Validates the security parameters.
     * @param securityParams The security parameters to be validated.
     * @notice This function checks if the security parameters are valid. It decodes the `params` parameter
     * and checks if the `lookback` value is non-zero and the `maxAllowedDelta` value is greater than or equal to zero.
     * If any of these conditions are not met, it reverts with an `InvalidParams` error.
     */
    function validateSecurityParams(
        SecurityParams memory securityParams
    ) external pure {
        if (securityParams.lookback == 0 || securityParams.maxAllowedDelta < 0)
            revert InvalidParams();
    }
}
