// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "src/Core.sol";

import "src/helpers/CreateStrategyHelper.sol";

import "src/bots/PulseVeloBot.sol";
import "src/bots/PulseVeloBotLazy.sol";

import "src/modules/velo/VeloAmmModule.sol";
import "src/modules/velo/VeloDepositWithdrawModule.sol";
import "src/modules/strategies/PulseStrategyModule.sol";
import "src/modules/strategies/PulseStrategyModuleV2.sol";
import "src/oracles/VeloOracle.sol";

import "src/interfaces/external/velo/ICLFactory.sol";
import "src/interfaces/external/velo/ICLPool.sol";

import {IUniswapV3Pool} from "src/interfaces/external/univ3/IUniswapV3Pool.sol";

import "src/interfaces/external/velo/INonfungiblePositionManager.sol";

import "src/libraries/external/LiquidityAmounts.sol";
import "src/libraries/external/velo/PositionValue.sol";

import "src/utils/Compounder.sol";
import "src/utils/LpWrapper.sol";
import "src/utils/StakingRewards.sol";
import "src/utils/VeloDeployFactory.sol";
import "src/utils/VeloDeployFactoryHelper.sol";
import "src/utils/VeloSugarHelper.sol";