// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title Minimal Voter interface for Terminal AMM
/// @notice Contains a subset of the full Voter interface that is used by the Terminal pool factory
interface IVoterMinimal {
    /// @notice Return the address of the Governor
    function governor() external view returns (address);
}
