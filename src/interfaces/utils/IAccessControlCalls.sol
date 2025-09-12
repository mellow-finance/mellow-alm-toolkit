// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IAccessControlCalls {
    /**
     * @dev Emitted when a target call is not allowed
     */
    error TargetCallNotAllowed(address target, bytes4 selector);

    /**
     * @dev Emitted when a target call is not allowed
     */
    error TargetCallAlreadyAllowed(bytes32 targetHash, address target, bytes4 selector);

    /**
     * @dev Emitted when a forbidden call is attempted
     */
    error ForbiddenCall();

    /**
     * @dev Emitted when the zero address is provided where it is not allowed
     */
    error AddressZero();

    /**
     * @notice Emitted when a target call is approved
     * @param targetHash The hash of the target address and selector that was approved.
     * @param target The address of the target contract where the call will be made.
     * @param selector The function selector of the target call that was approved.
     */
    event TargetCallAllowed(bytes32 indexed targetHash, address indexed target, bytes4 selector);

    /**
     * @notice Emitted when a target call is forbidden
     * @param targetHash The hash of the target address and selector that was forbidden.
     * @param target The address of the target contract where the call will be made.
     * @param selector The function selector of the target call that was forbidden.
     */
    event TargetCallDisallowed(bytes32 indexed targetHash, address indexed target, bytes4 selector);

    /**
     * @dev Returns the admin role identifier.
     * @return bytes32 - admin role identifier.
     */
    function ADMIN_ROLE() external view returns (bytes32);

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
    function isAllowedCall(address target, bytes4 selector) external view returns (bool);
}
