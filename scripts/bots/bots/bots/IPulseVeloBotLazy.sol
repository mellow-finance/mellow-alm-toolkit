// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

// TO BE REMOVED, FIXED TO COMPILE THE CODE BASE
import "src/interfaces/external/velo/ICLPool.sol";
import "src/interfaces/external/velo/INonfungiblePositionManager.sol";
import "src/interfaces/utils/IRebalanceCallback.sol";

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
        address pool;
        address router;
        address tokenIn;
        address tokenOut;
    }

    function Q96() external view returns (uint256);

    function D6() external view returns (uint256);

    function positionManager() external view returns (INonfungiblePositionManager);

    function call(bytes memory data, ICore.TargetPositionInfo[] memory targets)
        external
        returns (uint256[][] memory newTokenIds);
}
