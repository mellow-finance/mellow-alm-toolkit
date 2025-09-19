// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
pragma abicoder v2;

import "./pool/ITerminalGaugeActions.sol";
import "./pool/ITerminalPoolActions.sol";
import "./pool/ITerminalPoolDerivedState.sol";

import "./pool/ITerminalPoolEvents.sol";
import "./pool/ITerminalPoolImmutables.sol";
import "./pool/ITerminalPoolState.sol";

/// @title The interface for a Terminal Pool
/// @notice A Terminal pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface ITerminalPool is
    ITerminalPoolImmutables,
    ITerminalPoolState,
    ITerminalPoolDerivedState,
    ITerminalPoolActions,
    ITerminalGaugeActions,
    ITerminalPoolEvents
{}
