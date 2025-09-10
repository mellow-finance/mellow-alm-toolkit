// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IAccessControlCalls {
    /**
     * @dev Approves a target call.
     * @param target The address of the target contract where the call will be made.
     * @param selector The function selector of the target call that will be approved.
     */
    function allowTargetCall(address target, bytes4 selector) external;

    /**
     * @dev Forbids a target call.
     * @param target The address of the target contract where the call will be made.
     * @param selector The function selector of the target call that will be forbidden.
     */
    function disallowTargetCall(address target, bytes4 selector) external;

    /**
     * @dev Checks if a target call is allowed.
     * @param target The address of the target contract where the call will be made.
     * @param selector The function selector of the target call to check.
     * @return True if the call is allowed, false otherwise.
     */
    function isCallAllowed(address target, bytes4 selector) external view returns (bool);
}
