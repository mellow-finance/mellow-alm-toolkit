// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../src/Core.sol";
import "../../src/bots/PulseVeloBot.sol";

import "../../src/modules/velo/VeloAmmModule.sol";
import "../../src/modules/velo/VeloDepositWithdrawModule.sol";
import "../../src/modules/strategies/PulseStrategyModule.sol";
import "../../src/oracles/VeloOracle.sol";

import "../../src/interfaces/external/velo/ICLFactory.sol";
import "../../src/interfaces/external/velo/ICLPool.sol";

import {IUniswapV3Pool} from "../../src/interfaces/external/univ3/IUniswapV3Pool.sol";

import "../../src/interfaces/external/velo/INonfungiblePositionManager.sol";

import "../../src/libraries/external/LiquidityAmounts.sol";
import "../../src/libraries/external/velo/PositionValue.sol";

import "../../src/utils/LpWrapper.sol";
import "../../src/utils/external/synthetix/StakingRewards.sol";

library Constants {
    address public constant USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant VELO = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;

    address public constant NONFUNGIBLE_POSITION_MANAGER =
        0xd557d3b47D159EB3f9B48c0f1B4a6e67e82e8B3f;
    address public constant VELO_FACTORY =
        0x6890F9215fC8D17f4000ba91e8a5E538e78F14EB;

    address public constant DEPLOYER = address(bytes20(keccak256("deployer")));
    address public constant DEPOSITOR =
        address(bytes20(keccak256("depositor-1")));
    address public constant DEPOSITOR_2 =
        address(bytes20(keccak256("depositor-2")));
    address public constant DEPOSITOR_3 =
        address(bytes20(keccak256("depositor-3")));
    address public constant DEPOSITOR_4 =
        address(bytes20(keccak256("depositor-4")));
    address public constant OWNER = address(bytes20(keccak256("owner")));
    address public constant ADMIN = address(bytes20(keccak256("admin")));
    address public constant PROTOCOL_TREASURY =
        address(bytes20(keccak256("protocol-treasury")));
    uint256 public constant PROTOCOL_FEE_D9 = 1e8; // 10%
}
