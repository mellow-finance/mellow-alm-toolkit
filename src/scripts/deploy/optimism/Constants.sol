// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "../../src.sol";
import "./Addresses.sol";
import "./PoolParameters.sol";

library Constants {
    address public constant OP = 0x4200000000000000000000000000000000000042; // OP
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant VELO = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db; // VELO

    address public constant NONFUNGIBLE_POSITION_MANAGER =
        0xbB5DFE1380333CEE4c2EeBd7202c80dE2256AdF4;
    address public constant VELO_FACTORY = 0x548118C7E0B865C2CfA94D15EC86B666468ac758;

    bytes4 public constant SELECTOR_IS_POOL = 0xe5e31b13; // isPair(address)

    address public constant SWAP_ROUTER = 0xF132bdb9573867cD72f2585C338B923F973EB817;
    address public constant QUOTER_V2 = 0xA2DEcF05c16537C702779083Fe067e308463CE45;

    uint128 constant MIN_INITIAL_LIQUDITY = 1000;
    uint32 constant PROTOCOL_FEE_D9 = 1e8; // 10%
}
