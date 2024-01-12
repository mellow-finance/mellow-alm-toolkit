// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../IAlgebraPool.sol";
import "../IDataStorageOperator.sol";

library DataStorageLibrary {
    error InvalidLength();
    error InvalidState();

    function consultMultiple(
        address pool,
        uint32[] memory secondsAgo
    ) internal view returns (int24[] memory arithmeticMeanTicks) {
        if (secondsAgo.length < 2) revert InvalidLength();
        for (uint256 i = 1; i < secondsAgo.length; i++) {
            if (secondsAgo[i] <= secondsAgo[i - 1]) revert InvalidState();
        }

        IDataStorageOperator dsOperator = IDataStorageOperator(
            IAlgebraPool(pool).dataStorageOperator()
        );
        (int56[] memory tickCumulatives, ) = dsOperator.getTimepoints(
            secondsAgo
        );
        arithmeticMeanTicks = new int24[](secondsAgo.length - 1);

        for (uint256 i = 1; i < secondsAgo.length; i++) {
            int56 tickCumulativesDelta = tickCumulatives[i] -
                tickCumulatives[i - 1];
            uint32 timespan = secondsAgo[i] - secondsAgo[i - 1];
            arithmeticMeanTicks[i - 1] = int24(
                tickCumulativesDelta / int56(uint56(timespan))
            );

            if (
                tickCumulativesDelta < 0 &&
                (tickCumulativesDelta % int56(uint56(timespan)) != 0)
            ) arithmeticMeanTicks[i - 1]--;
        }
    }
}
