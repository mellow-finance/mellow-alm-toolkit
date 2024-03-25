// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/utils/ICounter.sol";

contract Counter is ICounter {
    /// @inheritdoc ICounter
    uint256 public value = 0;
    /// @inheritdoc ICounter
    address public owner;
    /// @inheritdoc ICounter
    address public immutable operator;

    constructor(address owner_, address operator_) {
        owner = owner_;
        operator = operator_;
    }

    /// @inheritdoc ICounter
    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Counter: not owner");
        owner = newOwner;
    }

    /// @inheritdoc ICounter
    function add(uint256 additionalValue) external {
        require(msg.sender == operator, "Counter: not operator");
        value += additionalValue;
    }

    /// @inheritdoc ICounter
    function reset() external {
        require(msg.sender == owner, "Counter: not owner");
        value = 0;
    }
}
