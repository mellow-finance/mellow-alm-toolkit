// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title Immutable state
/// @notice Functions that return immutable state of the router
interface IPeripheryImmutableState {
    /// @return Returns the address of the Agni deployer
    function deployer() external view returns (address);

    /// @return Returns the address of the Agni factory
    function factory() external view returns (address);

    /// @return Returns the address of WMNT
    function WMNT() external view returns (address);
}
