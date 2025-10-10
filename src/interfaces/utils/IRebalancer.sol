// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "src/interfaces/modules/IAmmDepositWithdrawModule.sol";
import "src/interfaces/modules/velo/IVeloAmmModule.sol";
import "src/interfaces/utils/ILpStaker.sol";
import "src/interfaces/utils/ILpWrapper.sol";

interface IPoolSwap {
    struct GaugeFees {
        uint128 token0;
        uint128 token1;
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
    function fee() external view returns (uint24);
    function liquidity() external view returns (uint128);
    function gaugeFees() external view returns (GaugeFees memory);
}

/**
 * @title IRebalancer
 * @notice Read-only and callable interface for the Rebalancer contract that coordinates
 *         liquidity moves for managed UniV3-style positions (via Core/AMM/Strategy/Oracle modules).
 *
 * @dev
 * # Overview
 * - The Rebalancer queries the StrategyModule to decide whether a managed position needs a move,
 *   and computes whether that move requires a swap or can be done by “moving liquidity”.
 * - If a swap is needed, it calls Core.rebalance() and then performs robust post-checks to ensure
 *   the effective execution price is not worse than the estimated pool price (slippage guard).
 * - If a swap is *not* needed and there is only a single target range, it withdraws, burns, and
 *   mints liquidity into the new range via the AMM Deposit/Withdraw module (delegatecalls).
 * - The fallback is intentionally used during quoting: the pool calls back `swap(...)` and this
 *   contract reverts with encoded quote info (amountOut and sqrtPriceAfter), which is decoded by
 *   the caller to simulate a swap without changing state.
 *
 * # Important notes
 * - This interface only declares the external/public surface of the Rebalancer; internal helpers
 *   from the implementation are intentionally omitted.
 * - Types from other modules (ICore, IAmmModule, IPulseStrategyModule, IVeloOracle, etc.) are
 *   referenced but *not* redefined here. Import your existing module interfaces to compile.
 */
interface IRebalancer {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the callback target address is zero.
    error InvalidCallback();

    /// @notice Thrown when a caller that is not a recognized pool triggers the fallback path.
    error InvalidPool();

    /// @notice Thrown when no rebalance is required per StrategyModule targets.
    error NoNeedRebalance();

    /// @notice Thrown when the effective execution price is worse than the estimated bound.
    error HighSlippage();

    /// @notice Thrown when a requested action would require a swap but only pure “move liquidity” is allowed.
    error OnlyMoveLiquidity();

    /// @notice Thrown when a pool liquidity or price was manipulated during rebalance.
    error PoolManipulated();

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice A convenient snapshot of a managed position and its recommended target.
     * @param positionId           Managed position ID (Core).
     * @param lpWrapper            The LP wrapper (owner) address of the managed position.
     * @param isRebalanceRequired  Whether a rebalance is currently required.
     * @param target               Target position info returned by StrategyModule.
     * @param info                 Current managed position info from Core.
     * @param strategyParams       Decoded strategy parameters specific to Pulse strategy.
     * @param securityParams       Decoded oracle/security parameters for safety checks.
     */
    struct RebalanceData {
        uint256 positionId;
        address lpWrapper;
        bool isRebalanceRequired;
        ICore.TargetPositionInfo target;
        ICore.ManagedPositionInfo info;
        IPulseStrategyModule.StrategyParams strategyParams;
        IVeloOracle.SecurityParams securityParams;
    }

    /*//////////////////////////////////////////////////////////////
                       READ-ONLY PUBLIC GETTERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns a compact, user-friendly snapshot for a given LP wrapper.
     * @param lpWrapper Address of the LP wrapper (the owner of the managed position).
     * @return data Filled {RebalanceData} (including decoded strategy/security params).
     */
    function positionData(address lpWrapper) external view returns (RebalanceData memory data);

    /**
     * @notice Returns (positionId, info) for a given LP wrapper.
     * @param lpWrapper Address of the LP wrapper (the owner of the managed position).
     * @return positionId The managed position id in Core.
     * @return info       The current managed position info in Core.
     */
    function managedPositionInfo(address lpWrapper)
        external
        view
        returns (uint256 positionId, ICore.ManagedPositionInfo memory info);

    /**
     * @notice Decodes and returns strategy parameters for a wrapper’s managed position.
     * @param lpWrapper Address of the LP wrapper.
     * @return strategyParams Decoded {IPulseStrategyModule.StrategyParams}.
     */
    function getStrategyParams(address lpWrapper)
        external
        view
        returns (IPulseStrategyModule.StrategyParams memory strategyParams);

    /**
     * @notice Decodes and returns oracle/security parameters for a wrapper’s managed position.
     * @param lpWrapper Address of the LP wrapper.
     * @return securityParams Decoded {IVeloOracle.SecurityParams}.
     */
    function getSecurityParams(address lpWrapper)
        external
        view
        returns (IVeloOracle.SecurityParams memory securityParams);

    /**
     * @notice Enumerates all Core positions and returns only those that require a rebalance
     *         and are owned by a recognized entity (per the DeployFactory).
     * @dev The returned array length may be shrunk in-place by the implementation.
     * @return data Array of {RebalanceData} for positions that need action.
     */
    function rebalanceRequired() external view returns (RebalanceData[] memory data);

    /**
     * @notice Computes the total capital (AUM) of a managed position in token1 terms.
     * @param info Current managed position info from Core.
     * @param sqrtPriceX96 Current pool sqrt price (Q96).
     * @return Total capital in token1 terms (including fees).
     */
    function capitalPosition(ICore.ManagedPositionInfo memory info, uint160 sqrtPriceX96)
        external
        view
        returns (uint256);

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Triggers a rebalance flow for a managed position.
     * @dev May perform a swap or a move-liquidity-only flow depending on targets.
     *      Reverts with {NoNeedRebalance} if the strategy indicates no action is required.
     * @param params Rebalance parameters for Core (position id, callback target, data).
     */
    function rebalance(ICore.RebalanceParams calldata params) external;
}
