// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IAgniLmPool {
    function accumulateReward(uint32 currTimestamp) external;

    function crossLmTick(int24 tick, bool zeroForOne) external;
}
