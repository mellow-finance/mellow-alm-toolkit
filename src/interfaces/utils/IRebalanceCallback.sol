// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../ICore.sol";

interface IRebalanceCallback {
    /**
     * @dev Executes a callback function for rebalancing.
     * @param data The data to be passed to the callback function.
     * @param targets An array of target position information.
     * @return newAmmPositionIds An array of new AMM position IDs.
     */
    function call(
        bytes memory data,
        ICore.TargetPositionInfo[] memory targets
    ) external returns (uint256[][] memory newAmmPositionIds);
}
