// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

contract Counter {
    uint256 public value = 0;
    address public owner;
    address public immutable operator;

    constructor(address owner_, address operator_) {
        owner = owner_;
        operator = operator_;
    }

    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Counter: not owner");
        owner = newOwner;
    }

    function add(uint256 additionalValue) external {
        require(msg.sender == operator, "Counter: not operator");
        value += additionalValue;
    }

    function reset() external {
        require(msg.sender == owner, "Counter: not owner");
        value = 0;
    }
}
