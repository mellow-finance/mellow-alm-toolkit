// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    Counter public counter;

    address owner = address(1);
    address operator = address(2);
    address newOwner = address(3);

    function testConstructor() external {
        counter = new Counter(owner, operator);

        assertEq(counter.value(), 0);
        assertEq(counter.owner(), owner);
        assertEq(counter.operator(), operator);
    }

    function testTransferOwnership() external {
        counter = new Counter(owner, operator);

        vm.expectRevert("Counter: not owner");
        counter.transferOwnership(newOwner);

        vm.startPrank(operator);
        vm.expectRevert("Counter: not owner");
        counter.transferOwnership(newOwner);
        vm.stopPrank();

        vm.startPrank(owner);
        counter.transferOwnership(newOwner);
        vm.stopPrank();

        assertEq(counter.owner(), newOwner);
    }

    function testAdd() external {
        counter = new Counter(owner, operator);

        vm.expectRevert("Counter: not operator");
        counter.add(123);

        vm.startPrank(owner);
        vm.expectRevert("Counter: not operator");
        counter.add(123);
        vm.stopPrank();

        vm.startPrank(operator);
        assertEq(counter.value(), 0);
        counter.add(123);
        assertEq(counter.value(), 123);
        counter.add(123);
        assertEq(counter.value(), 246);
        counter.add(123);
        assertEq(counter.value(), 369);
        vm.stopPrank();
    }

    function testReset() external {
        counter = new Counter(owner, operator);

        vm.startPrank(operator);
        assertEq(counter.value(), 0);
        counter.add(369);
        assertEq(counter.value(), 369);
        vm.stopPrank();

        vm.expectRevert("Counter: not owner");
        counter.reset();

        vm.startPrank(operator);
        vm.expectRevert("Counter: not owner");
        counter.reset();
        vm.stopPrank();

        vm.startPrank(owner);
        counter.reset();
        assertEq(counter.value(), 0);
        vm.stopPrank();
    }
}
