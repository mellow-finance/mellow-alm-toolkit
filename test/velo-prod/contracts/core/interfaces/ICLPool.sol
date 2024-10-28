// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./pool/ICLPoolActions.sol";
import "./pool/ICLPoolConstants.sol";
import "./pool/ICLPoolDerivedState.sol";

import "./pool/ICLPoolEvents.sol";
import "./pool/ICLPoolOwnerActions.sol";
import "./pool/ICLPoolState.sol";

/// @title The interface for a CL Pool
/// @notice A CL pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface ICLPool is
    ICLPoolConstants,
    ICLPoolState,
    ICLPoolDerivedState,
    ICLPoolActions,
    ICLPoolEvents,
    ICLPoolOwnerActions
{}
