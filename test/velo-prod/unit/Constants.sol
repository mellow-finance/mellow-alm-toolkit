// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../../../src/Core.sol";

import "../../../src/bots/PulseVeloBot.sol";
import "../../../src/bots/PulseVeloBotLazy.sol";

import "../../../src/modules/strategies/PulseStrategyModule.sol";
import "../../../src/modules/strategies/PulseStrategyModule.sol";
import "../../../src/modules/velo/VeloAmmModule.sol";
import "../../../src/modules/velo/VeloDepositWithdrawModule.sol";
import "../../../src/oracles/VeloOracle.sol";

import "../../../src/interfaces/external/velo/ICLFactory.sol";
import "../../../src/interfaces/external/velo/ICLPool.sol";

import "../../../src/interfaces/external/velo/INonfungiblePositionManager.sol";

import "../../../src/libraries/external/velo/PositionValue.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

import "../../../src/utils/Compounder.sol";
import "../../../src/utils/LpWrapper.sol";
import "../../../src/utils/StakingRewards.sol";
import "../../../src/utils/VeloDeployFactory.sol";

import "../../../src/utils/VeloDeployFactoryHelper.sol";
import "../../../src/utils/VeloFactoryDeposit.sol";
import "../../../src/utils/VeloSugarHelper.sol";

library Constants {
    address public constant OP = 0x4200000000000000000000000000000000000042;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant VELO = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;

    address public constant NONFUNGIBLE_POSITION_MANAGER =
        0x416b433906b1B72FA758e166e239c43d68dC6F29;
    address public constant VELO_FACTORY = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F;

    bytes4 public constant SELECTOR_IS_POOL = bytes4(keccak256("isPair(address)"));

    address public constant SWAP_ROUTER = 0xF132bdb9573867cD72f2585C338B923F973EB817;
    address public constant QUOTER_V2 = 0xA2DEcF05c16537C702779083Fe067e308463CE45;

    address public constant DEPLOYER = address(bytes20(keccak256("deployer")));
    address public constant USER = address(bytes20(keccak256("USER")));
    address public constant DEPOSITOR = address(bytes20(keccak256("depositor-1")));
    address public constant DEPOSITOR_2 = address(bytes20(keccak256("depositor-2")));
    address public constant DEPOSITOR_3 = address(bytes20(keccak256("depositor-3")));
    address public constant DEPOSITOR_4 = address(bytes20(keccak256("depositor-4")));
    address public constant DEPOSITOR_FACTORY = address(bytes20(keccak256("depositor factory")));
    address public constant ADMIN = address(bytes20(keccak256("admin")));
    address public constant OWNER = address(bytes20(keccak256("owner")));
    address public constant FARM_OWNER = address(bytes20(keccak256("farm owner")));
    address public constant FARM_OPERATOR = address(bytes20(keccak256("farm operator")));
    address public constant WRAPPER_ADMIN = address(bytes20(keccak256("wrapper admin")));
    address public constant PROTOCOL_TREASURY = address(bytes20(keccak256("protocol-treasury")));
    uint32 public constant PROTOCOL_FEE_D9 = 1e8; // 10%
}
