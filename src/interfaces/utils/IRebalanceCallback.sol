// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../ICore.sol";

interface IRebalanceCallback {
    /**
     * @dev Executes a callback function for rebalancing.
     * @param data The data to be passed to the callback function.
     * @param target The target position information.
     * @return newAmmPositionIds An array of new AMM position IDs.
     */
    function call(
        bytes memory data,
        ICore.TargetPositionInfo memory target,
        ICore.ManagedPositionInfo memory info
    ) external returns (uint256[] memory newAmmPositionIds);
}
