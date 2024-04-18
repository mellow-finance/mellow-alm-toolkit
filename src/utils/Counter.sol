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

    /// @inheritdoc ICounter
    address public immutable token;
    /// @inheritdoc ICounter
    address public immutable farm;

    constructor(
        address owner_,
        address operator_,
        address token_,
        address farm_
    ) {
        owner = owner_;
        operator = operator_;
        token = token_;
        farm = farm_;
    }

    /// @inheritdoc ICounter
    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Counter: not owner");
        owner = newOwner;
    }

    /// @inheritdoc ICounter
    function add(
        uint256 additionalValue,
        address token_,
        address farm_
    ) external {
        require(msg.sender == operator, "Counter: not operator");
        require(token_ == token, "Counter: invalid token");
        require(farm_ == farm, "Counter: invalid farm");
        value += additionalValue;
    }

    /// @inheritdoc ICounter
    function reset() external {
        require(msg.sender == owner, "Counter: not owner");
        value = 0;
    }
}
