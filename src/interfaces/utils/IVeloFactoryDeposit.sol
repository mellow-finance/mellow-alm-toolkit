// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../ICore.sol";
import "../modules/velo/IVeloDepositWithdrawModule.sol";
import "../utils/IVeloDeployFactory.sol";
import "src/interfaces/modules/strategies/IPulseStrategyModule.sol";

/**
 * @title IVeloDeployFactory Interface
 * @dev Interface for the VeloDeployFactory contract, facilitating the creation of strategies,
 * LP wrappers, and managing their configurations for Velo pools.
 */
interface IVeloFactoryDeposit {
    error Forbidden();
    error AddressZero();
    error ZeroLiquidity();
    error ZeroNFT();
    error ForbiddenPool();

    struct PoolStrategyParameter {
        ICLPool pool;
        IPulseStrategyModule.StrategyType strategyType;
        int24 width;
        uint256 maxAmount0;
        uint256 maxAmount1;
    }
}
