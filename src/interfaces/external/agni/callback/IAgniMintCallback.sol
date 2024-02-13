// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title Callback for IAgniPoolActions#mint
/// @notice Any contract that calls IAgniPoolActions#mint must implement this interface
interface IAgniMintCallback {
    /// @notice Called to `msg.sender` after minting liquidity to a position from IAgniPool#mint.
    /// @dev In the implementation you must pay the pool tokens owed for the minted liquidity.
    /// The caller of this method must be checked to be a AgniPool deployed by the canonical AgniFactory.
    /// @param amount0Owed The amount of token0 due to the pool for the minted liquidity
    /// @param amount1Owed The amount of token1 due to the pool for the minted liquidity
    /// @param data Any data passed through by the caller via the IAgniPoolActions#mint call
    function agniMintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;
}
