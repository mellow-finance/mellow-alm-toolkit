// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/modules/velo/IVeloDepositWithdrawModule.sol";

contract VeloDepositWithdrawModule is IVeloDepositWithdrawModule {
    using SafeERC20 for IERC20;

    /// @inheritdoc IVeloDepositWithdrawModule
    INonfungiblePositionManager public immutable positionManager;
    /// @inheritdoc IVeloDepositWithdrawModule
    IAmmModule public immutable ammModule;

    constructor(
        INonfungiblePositionManager positionManager_,
        IAmmModule ammModule_
    ) {
        positionManager = positionManager_;
        ammModule = ammModule_;
    }

    /// @inheritdoc IVeloDepositWithdrawModule
    function deposit(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1,
        address from
    ) external override returns (uint256 actualAmount0, uint256 actualAmount1) {
        IAmmModule.Position memory position = ammModule.getPositionInfo(
            tokenId
        );
        IERC20(position.token0).safeTransferFrom(from, address(this), amount0);
        IERC20(position.token1).safeTransferFrom(from, address(this), amount1);
        IERC20(position.token0).safeIncreaseAllowance(
            address(positionManager),
            amount0
        );
        IERC20(position.token1).safeIncreaseAllowance(
            address(positionManager),
            amount1
        );
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
            IERC20(position.token0).safeTransfer(from, amount0 - actualAmount0);
        }
        if (actualAmount1 != amount1) {
            IERC20(position.token1).safeTransfer(from, amount1 - actualAmount1);
        }
    }

    /// @inheritdoc IVeloDepositWithdrawModule
    function withdraw(
        uint256 tokenId,
        uint256 liquidity,
        address to
    ) external override returns (uint256 actualAmount0, uint256 actualAmount1) {
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
