// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract AccessControlCallsMock is AccessControlCalls, Mock {
    function call(address target, bytes memory data) external view {
        _requireAllowedCall(target, data);
    }

    function initialize(address admin_) external initializer {
        __AccessControlCalls_init(admin_);
    }
}

contract Unit is Fixture {
    address admin = vm.addr(uint256(keccak256("admin")));

    function testAllowCall() external {
        AccessControlCallsMock mock = new AccessControlCallsMock();
        mock.initialize(admin);

        address target = vm.addr(uint256(keccak256("target")));
        bytes4 selector = bytes4(keccak256("foo(uint256,address)"));

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                DefaultAccessControl(address(mock)).ADMIN_ROLE()
            )
        );
        mock.allowTargetCall(target, selector);

        assertFalse(mock.isAllowedCall(target, selector), "Call should not be allowed yet");

        vm.expectRevert(IAccessControlCalls.ForbiddenCall.selector);
        mock.call(target, abi.encode(selector));

        vm.prank(admin);
        mock.allowTargetCall(target, selector);

        assertTrue(mock.isAllowedCall(target, selector), "Call should be allowed now");

        /// @dev no revert expected
        mock.call(target, abi.encode(selector));
    }

    function testDisallowCall() external {
        AccessControlCallsMock mock = new AccessControlCallsMock();
        mock.initialize(admin);

        address target = vm.addr(uint256(keccak256("target")));
        bytes4 selector = bytes4(keccak256("foo(uint256,address)"));

        vm.prank(admin);
        mock.allowTargetCall(target, selector);
        assertTrue(mock.isAllowedCall(target, selector), "Call should be allowed now");

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                DefaultAccessControl(address(mock)).ADMIN_ROLE()
            )
        );
        mock.disallowTargetCall(target, selector);

        assertTrue(mock.isAllowedCall(target, selector), "Call should be allowed yet");

        vm.prank(admin);
        mock.disallowTargetCall(target, selector);
        assertFalse(mock.isAllowedCall(target, selector), "Call should be allowed now");
    }

    function testFuzzAllowDisallowCall(
        address[64] calldata target,
        bytes4[64] calldata selector,
        bool[64] calldata disallow
    ) external {
        for (uint256 index = 0; index < target.length; index++) {
            vm.assume(target[index] != address(0));
            vm.assume(selector[index] != bytes4(0));
        }

        AccessControlCallsMock mock = new AccessControlCallsMock();
        mock.initialize(admin);

        for (uint256 index = 0; index < target.length; index++) {
            vm.prank(admin);
            mock.allowTargetCall(target[index], selector[index]);
        }

        for (uint256 index = 0; index < target.length; index++) {
            assertTrue(
                mock.isAllowedCall(target[index], selector[index]), "Call should be allowed now"
            );
        }

        for (uint256 index = 0; index < target.length; index++) {
            if (disallow[index]) {
                vm.prank(admin);
                mock.disallowTargetCall(target[index], selector[index]);
            }
        }
        for (uint256 index = 0; index < target.length; index++) {
            if (disallow[index]) {
                assertFalse(
                    mock.isAllowedCall(target[index], selector[index]),
                    "Call should be disallowed now"
                );
            } else {
                assertTrue(
                    mock.isAllowedCall(target[index], selector[index]), "Call should be allowed now"
                );
            }
        }
    }
}
