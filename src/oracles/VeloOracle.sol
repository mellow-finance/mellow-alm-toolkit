// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/oracles/IVeloOracle.sol";

contract VeloOracle is IVeloOracle {
    /// @inheritdoc IOracle
    function ensureNoMEV(address poolAddress, bytes memory params) external view override {
        if (params.length == 0) {
            return;
        }
        (, int24 spotTick, uint16 observationIndex, uint16 observationCardinality,,) =
            ICLPool(poolAddress).slot0();
        SecurityParams memory securityParams = abi.decode(params, (SecurityParams));
        uint16 lookback = securityParams.lookback;
        if (observationCardinality < lookback + 1) {
            revert NotEnoughObservations();
        }

        uint32 minimalTimestamp = uint32(block.timestamp) - securityParams.maxAge;
        (uint32 nextTimestamp, int56 nextCumulativeTick,,) =
            ICLPool(poolAddress).observations(observationIndex);
        int24 nextTick = spotTick;
        int24 maxAllowedDelta = securityParams.maxAllowedDelta;
        for (uint16 i = 1; i <= lookback; i++) {
            uint256 index = (observationCardinality + observationIndex - i) % observationCardinality;
            (uint32 timestamp, int56 tickCumulative,,) = ICLPool(poolAddress).observations(index);
            if (timestamp == 0) {
                revert NotEnoughObservations();
            }
            if (timestamp < minimalTimestamp) {
                return;
            }
            int24 tick = int24(
                (nextCumulativeTick - tickCumulative) / int56(uint56(nextTimestamp - timestamp))
            );
            (nextTimestamp, nextCumulativeTick) = (timestamp, tickCumulative);
            int24 delta = nextTick - tick;
            if (delta > maxAllowedDelta || delta < -maxAllowedDelta) {
                revert PriceManipulationDetected();
            }
            nextTick = tick;
        }
    }

    /// @inheritdoc IOracle
    function getOraclePrice(address pool)
        external
        view
        override
        returns (uint160 sqrtPriceX96, int24 tick)
    {
        (sqrtPriceX96, tick,,,,) = ICLPool(pool).slot0();
    }

    /// @inheritdoc IOracle
    function validateSecurityParams(bytes memory params) external pure override {
        if (params.length == 0) {
            return;
        }
        if (params.length != 0x60) {
            revert InvalidLength();
        }
        SecurityParams memory securityParams = abi.decode(params, (SecurityParams));
        if (
            securityParams.lookback == 0 || securityParams.maxAge == 0
                || securityParams.maxAge > 7 days || securityParams.maxAllowedDelta < 0
        ) {
            revert InvalidParams();
        }
    }
}
