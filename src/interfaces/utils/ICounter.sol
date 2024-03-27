// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

interface ICounter {
    /**
     * @dev Returns the current counter value.
     */
    function value() external view returns (uint256);

    /**
     * @dev Returns the counter's owner address.
     */
    function owner() external view returns (address);

    /**
     * @dev Returns the counter's operator address.
     */
    function operator() external view returns (address);

    /**
     * @dev Transfers ownership of the counter to a new address.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) external;

    /**
     * @dev Adds a value to the counter. Can only be called by the operator.
     */
    function add(uint256 additionalValue) external;

    /**
     * @dev Resets the counter to zero. Can only be called by the current owner.
     */
    function reset() external;
}
