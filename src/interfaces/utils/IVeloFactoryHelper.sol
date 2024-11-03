// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../ICore.sol";

import "../modules/strategies/IPulseStrategyModule.sol";
import "../modules/velo/IVeloDepositWithdrawModule.sol";
import "../utils/IVeloDeployFactory.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

/**
 * @title IVeloDeployFactory Interface
 * @dev Interface for the VeloDeployFactory contract, facilitating the creation of strategies,
 * LP wrappers, and managing their configurations for Velo pools.
 */
interface IVeloFactoryHelper {
    error Forbidden();
    error AddressZero();
    error ZeroLiquidity();
    error ZeroNFT();
    error ForbiddenPool();
    error InvalidParams();

    struct PoolStrategyParameter {
        ICLPool pool;
        IPulseStrategyModule.StrategyParams strategyParams;
        uint256 maxAmount0;
        uint256 maxAmount1;
        bytes securityParams;
    }

    struct MintInfo {
        uint256 amount0;
        uint256 amount1;
        int24 tickLower;
        int24 tickUpper;
    }

    function create(address depositor, PoolStrategyParameter calldata params)
        external
        returns (uint256[] memory tokenIds);
}
