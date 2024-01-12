// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../ICore.sol";

interface IAmmIntentCallback {
    function call(
        bytes memory data,
        ICore.TargetNftInfo[] memory targets
    ) external returns (uint256[] memory);
}
