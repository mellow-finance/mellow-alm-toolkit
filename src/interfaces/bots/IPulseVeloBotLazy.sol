// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../utils/IRebalanceCallback.sol";
import "../external/velo/ICLPool.sol";
import "../external/velo/INonfungiblePositionManager.sol";

interface IPulseVeloBotLazy is IRebalanceCallback {
    struct SwapQuoteParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
    }

    struct SwapParams {
        uint256 amountIn;
        bytes callData;
        uint256 expectedAmountOut;
        uint256 positionId;
        address router;
        address tokenIn;
        address tokenOut;
    }

    function Q96() external view returns (uint256);

    function D6() external view returns (uint256);

    function positionManager()
        external
        view
        returns (INonfungiblePositionManager);

    function call(
        bytes memory data,
        ICore.TargetPositionInfo[] memory targets
    ) external returns (uint256[][] memory newTokenIds);
}