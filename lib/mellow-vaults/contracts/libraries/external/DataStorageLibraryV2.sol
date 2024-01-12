// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import '../../interfaces/external/algebrav2/FullMath.sol';
import '../../interfaces/external/algebrav2/TickMath.sol';
import '../../interfaces/external/algebrav2/IAlgebraPool.sol';
import '../../interfaces/external/algebrav2/IDataStorageOperator.sol';
import '../../interfaces/external/algebrav2/libraries/LowGasSafeMath.sol';

import '../../interfaces/external/algebrav2/libraries/PoolAddress.sol';

/// @title DataStorage library
/// @notice Provides functions to integrate with pool dataStorage
library DataStorageLibrary {
    /// @notice Fetches time-weighted average tick using Algebra dataStorage
    /// @param pool Address of Algebra pool that we want to getTimepoints
    /// @param period Number of seconds in the past to start calculating time-weighted average
    /// @return timeWeightedAverageTick The time-weighted average tick from (block.timestamp - period) to block.timestamp
    function consult(address pool, uint32 period) internal view returns (int24 timeWeightedAverageTick) {
        require(period != 0, 'BP');

        uint32[] memory secondAgos = new uint32[](2);
        secondAgos[0] = period;
        secondAgos[1] = 0;

        IDataStorageOperator dsOperator = IDataStorageOperator(IAlgebraPool(pool).dataStorageOperator());
        (int56[] memory tickCumulatives, ) = dsOperator.getTimepoints(secondAgos);
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];

        timeWeightedAverageTick = int24(tickCumulativesDelta / int56(uint56(period)));

        // Always round to negative infinity
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(uint56(period)) != 0)) timeWeightedAverageTick--;
    }

    /// @notice Given a tick and a token amount, calculates the amount of token received in exchange
    /// @param tick Tick value used to calculate the quote
    /// @param baseAmount Amount of token to be converted
    /// @param baseToken Address of an ERC20 token contract used as the baseAmount denomination
    /// @param quoteToken Address of an ERC20 token contract used as the quoteAmount denomination
    /// @return quoteAmount Amount of quoteToken received for baseAmount of baseToken
    function getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        address baseToken,
        address quoteToken
    ) internal pure returns (uint256 quoteAmount) {
        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);

        // Calculate quoteAmount with better precision if it doesn't overflow when multiplied by itself
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }
}