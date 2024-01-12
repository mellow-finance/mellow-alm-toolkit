// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../strategies/IAmmIntent.sol";

interface IAmmIntentCallback {
    function call(
        bytes memory data,
        IAmmIntent.TargetNftInfo[] memory targets
    ) external returns (uint256[] memory);
}
