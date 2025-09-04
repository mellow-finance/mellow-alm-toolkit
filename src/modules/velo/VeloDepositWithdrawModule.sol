// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../interfaces/modules/velo/IVeloDepositWithdrawModule.sol";

contract VeloDepositWithdrawModule is IVeloDepositWithdrawModule {
    using SafeERC20 for IERC20;

    /// @inheritdoc IVeloDepositWithdrawModule
    INonfungiblePositionManager public immutable positionManager;

    /// ---------------------- INITIALIZER FUNCTIONS ----------------------

    constructor(INonfungiblePositionManager positionManager_) {
        positionManager = positionManager_;
    }

    /// ---------------------- EXTERNAL MUTATING FUNCTIONS ----------------------

    /// @inheritdoc IAmmDepositWithdrawModule
    function deposit(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1,
        address from,
        address token0,
        address token1
    ) external override returns (uint256 actualAmount0, uint256 actualAmount1) {
        address this_ = address(this);
        if (amount0 != 0) {
            IERC20(token0).safeTransferFrom(from, this_, amount0);
            IERC20(token0).safeIncreaseAllowance(address(positionManager), amount0);
        }
        if (amount1 != 0) {
            IERC20(token1).safeTransferFrom(from, this_, amount1);
            IERC20(token1).safeIncreaseAllowance(address(positionManager), amount1);
        }
        (, actualAmount0, actualAmount1) = positionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint256).max
            })
        );
        if (actualAmount0 != amount0) {
            IERC20(token0).safeTransfer(from, amount0 - actualAmount0);
        }
        if (actualAmount1 != amount1) {
            IERC20(token1).safeTransfer(from, amount1 - actualAmount1);
        }
    }

    /// @inheritdoc IAmmDepositWithdrawModule
    function withdraw(uint256 tokenId, uint256 liquidity, address to)
        external
        override
        returns (uint256 actualAmount0, uint256 actualAmount1)
    {
        positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: uint128(liquidity),
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint256).max
            })
        );
        (actualAmount0, actualAmount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: to,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
    }
}
