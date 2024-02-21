// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../utils/IRebalanceCallback.sol";
import "../external/velo/ICLPool.sol";
import "../external/velo/ICLFactory.sol";
import "../external/velo/IQuoterV2.sol";
import "../external/velo/ISwapRouter.sol";
import "../external/velo/INonfungiblePositionManager.sol";

interface IPulseVeloBot is IRebalanceCallback {
    struct SwapParams {
        address tokenIn;
        address tokenOut;
        int24 tickSpacing;
        uint256 amountIn;
        uint256 expectedAmountOut;
    }

    struct SingleIntervalData {
        uint256 amount0;
        uint256 amount1;
        uint160 sqrtLowerRatioX96;
        uint160 sqrtUpperRatioX96;
        ICLPool pool;
    }

    struct MultipleIntervalsData {
        uint256 amount0;
        uint256 amount1;
        uint256[] ratiosX96;
        uint160[] sqrtLowerRatiosX96;
        uint160[] sqrtUpperRatiosX96;
        ICLPool pool;
    }

    function Q96() external view returns (uint256);

    function D6() external view returns (uint256);

    function quoter() external view returns (IQuoterV2);

    function router() external view returns (ISwapRouter);

    function positionManager()
        external
        view
        returns (INonfungiblePositionManager);

    function calculateSwapAmountsPreciselySingle(
        SingleIntervalData memory data
    ) external returns (SwapParams memory swapParams);

    function calculateSwapAmountsPreciselyMultiple(
        MultipleIntervalsData memory data
    ) external returns (SwapParams memory swapParams);

    function call(
        bytes memory data,
        ICore.TargetPositionInfo[] memory targets
    ) external returns (uint256[][] memory newTokenIds);
}
