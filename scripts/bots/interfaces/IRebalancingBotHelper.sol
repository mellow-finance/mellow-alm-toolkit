// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../../src/interfaces/ICore.sol";

interface IRebalancingBotHelper {
    struct SwapQuoteParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
    }

    /// @dev returns quotes for swap
    /// @param pool address of Pool
    /// @param priceTargetX96 actual price of exchange token0<->token1: 2^96 * amountOut/amountIn
    /// @return swapQuoteParams contains ecessery amountIn amd amountOut to swap for desired target position
    function necessarySwapAmountForMint(address pool, uint256 priceTargetX96)
        external
        view
        returns (SwapQuoteParams memory swapQuoteParams);

    /// @dev return current positionId for @param pool
    function poolManagedPositionInfo(address pool)
        external
        view
        returns (uint256 positionId, ICore.ManagedPositionInfo memory managedPositionInfo);

    /// @dev returns flags, true if rebalance is necessary for @param pool
    function needRebalancePosition(address pool)
        external
        view
        returns (bool isRebalanceRequired);

}
