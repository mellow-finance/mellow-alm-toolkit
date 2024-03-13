// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

interface ICounter {
    function value() external view returns (uint256);
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
    function add(uint256 additionalValue) external;
    function reset() external;
}
