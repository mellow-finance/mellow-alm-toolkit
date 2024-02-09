// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "../../../interfaces/external/agni/IAgniFactory.sol";
import "../../../interfaces/external/agni/IAgniPool.sol";
import "../../../interfaces/external/agni/INonfungiblePositionManager.sol";

library Constants {
    address public constant USDC = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9;
    address public constant WETH = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111;
    address public constant USDT = 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE;
    address public constant METH = 0xcDA86A272531e8640cD7F1a92c01839911B90bb0;
    address public constant USDY = 0x5bE26527e817998A7206475496fDE1E68957c5A6;
    address public constant AXLETH = 0xb829b68f57CC546dA7E5806A929e53bE32a4625D;

    address public constant NONFUNGIBLE_POSITION_MANAGER =
        0x218bf598D1453383e2F4AA7b14fFB9BfB102D637;
    address public constant AGNI_FACTORY =
        0x25780dc8Fc3cfBD75F33bFDAB65e969b603b2035;
    address public constant AGNI_SWAP_ROUTER =
        0x319B69888b0d11cEC22caA5034e25FfFBDc88421;
    address public constant AGNI_QUOTER_V2 =
        0xc4aaDc921E1cdb66c5300Bc158a313292923C0cb;
    address public constant DEPLOYER = address(bytes20(keccak256("deployer")));
    address public constant DEPOSITOR =
        address(bytes20(keccak256("depositor")));
    address public constant OWNER = address(bytes20(keccak256("owner")));
}
