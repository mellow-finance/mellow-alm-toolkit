// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./CommonImports.sol";

import "../src/interfaces/external/velo/ICLFactory.sol";
import "../src/interfaces/external/velo/ICLPool.sol";
import "../src/interfaces/external/velo/INonfungiblePositionManager.sol";

import "../src/modules/velo/VeloAmmModule.sol";

import "../src/modules/velo/VeloDepositWithdrawModule.sol";
import "../src/oracles/VeloOracle.sol";

import "test/mocks/CLPoolMock.sol";
import "test/mocks/GaugeMock.sol";
import "test/mocks/NonfungiblePositionManagerMock.sol";
import "test/mocks/RebalancingBotMock.sol";

import "test/mocks/SwapRouterMock.sol";
import "test/mocks/VeloDepositWithdrawModuleMock.sol";
import "test/mocks/VeloFarmMock.sol";
import "test/mocks/VoterMock.sol";
