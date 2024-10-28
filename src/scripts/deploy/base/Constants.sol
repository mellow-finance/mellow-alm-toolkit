// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "../../src.sol";
import "./Addresses.sol";
import "./PoolParameters.sol";

library Constants {
    address public constant OP = 0x940181a94A35A4569E4529A3CDfB74e38FD98631; // AERO
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant VELO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631; // AERO

    address public constant NONFUNGIBLE_POSITION_MANAGER =
        0x827922686190790b37229fd06084350E74485b72;
    address public constant VELO_FACTORY = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;

    bytes4 public constant SELECTOR_IS_POOL = 0x5b16ebb7; // isPool(address)

    address public constant SWAP_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address public constant QUOTER_V2 = 0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a;

    uint128 constant MIN_INITIAL_LIQUDITY = 1000;
    uint32 constant PROTOCOL_FEE_D9 = 1e8; // 10%
}
