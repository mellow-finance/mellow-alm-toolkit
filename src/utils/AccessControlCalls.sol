// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IAccessControlCalls.sol";
import "./DefaultAccessControl.sol";

import "forge-std/Test.sol";

abstract contract AccessControlCalls is IAccessControlCalls, DefaultAccessControl {
    /// @dev keccak256(abi.encode(target, selector)) => allowed
    mapping(bytes32 => bool) internal allowedCalls;

    function __AccessControlCalls_init(address admin_) internal onlyInitializing {
        if (admin_ == address(0)) {
            revert AddressZero();
        }
        __DefaultAccessControl_init(admin_);
    }

    /// @inheritdoc IAccessControlCalls
    function allowTargetCall(address target, bytes4 selector) external onlyRole(ADMIN_ROLE) {
        if (target == address(0)) {
            revert AddressZero();
        }
        bytes32 _hash = hashCall(target, selector);
        if (allowedCalls[_hash]) {
            revert TargetCallAlreadyAllowed(_hash, target, selector);
        }
        allowedCalls[_hash] = true;
        emit TargetCallAllowed(_hash, target, selector);
    }

    /// @inheritdoc IAccessControlCalls
    function disallowTargetCall(address target, bytes4 selector) external onlyRole(ADMIN_ROLE) {
        bytes32 _hash = hashCall(target, selector);
        if (!allowedCalls[_hash]) {
            revert TargetCallNotAllowed(target, selector);
        }
        allowedCalls[_hash] = false;
        emit TargetCallDisallowed(_hash, target, selector);
    }

    /// @inheritdoc IAccessControlCalls
    function isAllowedCall(address target, bytes4 selector) public view returns (bool) {
        return allowedCalls[hashCall(target, selector)];
    }

    function hashCall(address target, bytes4 selector) internal pure returns (bytes32) {
        return keccak256(abi.encode(target, selector));
    }

    function _requireAllowedCall(address target, bytes memory data) internal view {
        bytes4 selector;
        assembly {
            selector := shl(224, shr(224, mload(add(data, 32))))
        }
        if (!isAllowedCall(target, selector)) {
            revert ForbiddenCall();
        }
    }
}
