// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IAccessControlCalls.sol";
import "./DefaultAccessControl.sol";

abstract contract AccessControlCalls is IAccessControlCalls, DefaultAccessControl {
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
     * @notice Mapping of allowed target calls
     */
    mapping(bytes32 => bool) internal allowedCalls;

    function __AccessControlCalls_init(address admin_) internal onlyInitializing {
        if (admin_ == address(0)) {
            revert AddressZero();
        }
        __DefaultAccessControl_init(admin_);
    }

    /// @inheritdoc IAccessControlCalls
    function allowTargetCall(address target, bytes4 selector) external onlyRole(ADMIN_ROLE) {
        bytes32 _hash = hashCall(target, selector);
        allowedCalls[_hash] = true;
        emit TargetCallAllowed(_hash, target, selector);
    }

    /// @inheritdoc IAccessControlCalls
    function disallowTargetCall(address target, bytes4 selector) external onlyRole(ADMIN_ROLE) {
        bytes32 _hash = hashCall(target, selector);
        allowedCalls[_hash] = false;
        emit TargetCallDisallowed(_hash, target, selector);
    }

    /// @inheritdoc IAccessControlCalls
    function isCallAllowed(address target, bytes4 selector) external view returns (bool) {
        return allowedCalls[hashCall(target, selector)];
    }

    function hashCall(address target, bytes4 selector) internal pure returns (bytes32) {
        return keccak256(abi.encode(target, selector));
    }
}
