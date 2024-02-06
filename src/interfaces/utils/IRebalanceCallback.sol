// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../ICore.sol";

interface IRebalanceCallback {
    function call(
        bytes memory data,
        ICore.TargetNftsInfo[] memory targets
    ) external returns (uint256[][] memory);
}
