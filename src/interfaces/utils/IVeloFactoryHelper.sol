// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../ICore.sol";
import "../modules/strategies/IPulseStrategyModule.sol";
import "../modules/velo/IVeloDepositWithdrawModule.sol";
import "../utils/IVeloDeployFactory.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

/**
 * @title IVeloFactoryHelper Interface
 * @dev Interface for the VeloFactoryHelper contract, facilitating the creation of Velo slipstream nfts
 */
interface IVeloFactoryHelper {
    error Forbidden();
    error AddressZero();
    error ForbiddenPool();

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
