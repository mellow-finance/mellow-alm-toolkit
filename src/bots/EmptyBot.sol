// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/utils/IRebalanceCallback.sol";

contract EmptyBot is IRebalanceCallback {
    function call(bytes memory, ICore.TargetPositionInfo[] memory)
        external
        returns (uint256[][] memory)
    {}
}
