// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./pool/IAgniPoolImmutables.sol";
import "./pool/IAgniPoolState.sol";
import "./pool/IAgniPoolDerivedState.sol";
import "./pool/IAgniPoolActions.sol";
import "./pool/IAgniPoolOwnerActions.sol";
import "./pool/IAgniPoolEvents.sol";

/// @title The interface for a Agni Pool
/// @notice A Agni pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IAgniPool is
    IAgniPoolImmutables,
    IAgniPoolState,
    IAgniPoolDerivedState,
    IAgniPoolActions,
    IAgniPoolOwnerActions,
    IAgniPoolEvents
{}
