// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title Periphery Payments
/// @notice Functions to ease deposits and withdrawals of MNT
interface IPeripheryPayments {
    /// @notice Unwraps the contract's WMNT balance and sends it to recipient as MNT.
    /// @dev The amountMinimum parameter prevents malicious contracts from stealing WMNT from users.
    /// @param amountMinimum The minimum amount of WMNT to unwrap
    /// @param recipient The address receiving MNT
    function unwrapWMNT(
        uint256 amountMinimum,
        address recipient
    ) external payable;

    /// @notice Refunds any MNT balance held by this contract to the `msg.sender`
    /// @dev Useful for bundling with mint or increase liquidity that uses ether, or exact output swaps
    /// that use ether for the input amount
    function refundMNT() external payable;

    /// @notice Transfers the full amount of a token held by this contract to recipient
    /// @dev The amountMinimum parameter prevents malicious contracts from stealing the token from users
    /// @param token The contract address of the token which will be transferred to `recipient`
    /// @param amountMinimum The minimum amount of token required for a transfer
    /// @param recipient The destination address of the token
    function sweepToken(
        address token,
        uint256 amountMinimum,
        address recipient
    ) external payable;
}
