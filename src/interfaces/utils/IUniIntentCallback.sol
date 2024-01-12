// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../IUniIntent.sol";

interface IUniIntentCallback {
    function call(
        bytes memory data,
        IUniIntent.TargetNftInfo[] memory targets
    ) external returns (uint256[] memory);
}
