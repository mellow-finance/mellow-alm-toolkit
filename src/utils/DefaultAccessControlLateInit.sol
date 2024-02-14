// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

/// @notice This is a default access control with 3 roles:
///
/// - ADMIN: allowed to do anything
/// - ADMIN_DELEGATE: allowed to do anything except assigning ADMIN and ADMIN_DELEGATE roles
/// - OPERATOR: low-privileged role, generally keeper or some other bot
contract DefaultAccessControlLateInit is AccessControlEnumerable {
    error Forbidden();
    error AddressZero();
    error AlreadyIniitialized();

    bool public initialized;

    bytes32 public constant OPERATOR = keccak256("operator");
    bytes32 public constant ADMIN_ROLE = keccak256("admin");
    bytes32 public constant ADMIN_DELEGATE_ROLE = keccak256("admin_delegate");

    // -------------------------  EXTERNAL, VIEW  ------------------------------

    function isAdmin(address sender) public view returns (bool) {
        return
            hasRole(ADMIN_ROLE, sender) || hasRole(ADMIN_DELEGATE_ROLE, sender);
    }

    function isOperator(address sender) public view returns (bool) {
        return hasRole(OPERATOR, sender);
    }

    // -------------------------  EXTERNAL, MUTATING  ------------------------------

    /// @notice Initializes a new contract with roles and single ADMIN.
    /// @param admin Admin of the contract
    function init(address admin) public {
        if (admin == address(0)) revert AddressZero();
        if (initialized) revert AlreadyIniitialized();

        _setupRole(OPERATOR, admin);
        _setupRole(ADMIN_ROLE, admin);

        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADMIN_DELEGATE_ROLE, ADMIN_ROLE);
        _setRoleAdmin(OPERATOR, ADMIN_DELEGATE_ROLE);

        initialized = true;
    }

    // -------------------------  INTERNAL, VIEW  ------------------------------

    function _requireAdmin() internal view {
        if (!isAdmin(msg.sender)) {
            revert Forbidden();
        }
    }

    function _requireAtLeastOperator() internal view {
        if (!isAdmin(msg.sender) && !isOperator(msg.sender)) {
            revert Forbidden();
        }
    }
}
