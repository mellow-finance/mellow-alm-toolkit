// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../utils/IRebalanceCallback.sol";
import "../external/velo/ICLPool.sol";
import "../external/velo/ICLFactory.sol";
import "../external/velo/IQuoterV2.sol";
import "../external/velo/ISwapRouter.sol";
import "../external/velo/INonfungiblePositionManager.sol";

interface IPulseVeloBotLazy is IRebalanceCallback {
    struct SwapArbitraryParams {
        address tokenIn;
        address tokenOut;
        address router;
        bytes callData;
        uint256 amountIn;
        uint256 expectedAmountOut;
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
