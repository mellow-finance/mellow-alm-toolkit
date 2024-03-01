// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// import "../../interfaces/modules/IAmmModule.sol";
// import "../../interfaces/modules/IAmmDepositWithdrawModule.sol";

// import "../../interfaces/external/agni/INonfungiblePositionManager.sol";
// import "../../interfaces/external/agni/IAgniPool.sol";

// /**
//  * @title AgniDepositWithdrawModule
//  * @dev A contract that implements the IAmmDepositWithdrawModule interface for Agni pools.
//  */
// contract AgniDepositWithdrawModule is IAmmDepositWithdrawModule {
//     using SafeERC20 for IERC20;

//     INonfungiblePositionManager public immutable positionManager;
//     IAmmModule public immutable ammModule;

//     constructor(
//         INonfungiblePositionManager positionManager_,
//         IAmmModule ammModule_
//     ) {
//         positionManager = positionManager_;
//         ammModule = ammModule_;
//     }

//     /**
//      * @dev Deposits the specified amounts of token0 and token1 into the pool.
//      * @param tokenId The ID of the token.
//      * @param amount0 The amount of token0 to deposit.
//      * @param amount1 The amount of token1 to deposit.
//      * @param from The address from which the tokens are to be transferred.
//      * @notice The caller must approve the contract to spend the tokens.
//      * @notice Tokens distributes proportionally accross all positions.
//      */
//     function deposit(
//         uint256 tokenId,
//         uint256 amount0,
//         uint256 amount1,
//         address from
//     ) external override returns (uint256 actualAmount0, uint256 actualAmount1) {
//         IAmmModule.Position memory position = ammModule.getPositionInfo(
//             tokenId
//         );
//         IERC20(position.token0).safeTransferFrom(from, address(this), amount0);
//         IERC20(position.token1).safeTransferFrom(from, address(this), amount1);
//         IERC20(position.token0).safeIncreaseAllowance(
//             address(positionManager),
//             amount0
//         );
//         IERC20(position.token1).safeIncreaseAllowance(
//             address(positionManager),
//             amount1
//         );
//         (, actualAmount0, actualAmount1) = positionManager.increaseLiquidity(
//             INonfungiblePositionManager.IncreaseLiquidityParams({
//                 tokenId: tokenId,
//                 amount0Desired: amount0,
//                 amount1Desired: amount1,
//                 amount0Min: 0,
//                 amount1Min: 0,
//                 deadline: type(uint256).max
//             })
//         );
//         if (actualAmount0 != amount0) {
//             IERC20(position.token0).safeTransfer(from, amount0 - actualAmount0);
//         }
//         if (actualAmount1 != amount1) {
//             IERC20(position.token1).safeTransfer(from, amount1 - actualAmount1);
//         }
//     }

//     /**
//      * @dev Withdraws liquidity from a position and transfers the collected tokens to the specified recipient.
//      * @param tokenId The ID of the position.
//      * @param liquidity The amount of liquidity to withdraw.
//      * @param to The address to transfer the collected tokens to.
//      * @return actualAmount0 The actual amount of token0 collected.
//      * @return actualAmount1 The actual amount of token1 collected.
//      * @notice Function collects tokens proportionally from all positions.
//      */
//     function withdraw(
//         uint256 tokenId,
//         uint256 liquidity,
//         address to
//     ) external override returns (uint256 actualAmount0, uint256 actualAmount1) {
//         positionManager.decreaseLiquidity(
//             INonfungiblePositionManager.DecreaseLiquidityParams({
//                 tokenId: tokenId,
//                 liquidity: uint128(liquidity),
//                 amount0Min: 0,
//                 amount1Min: 0,
//                 deadline: type(uint256).max
//             })
//         );
//         (actualAmount0, actualAmount1) = positionManager.collect(
//             INonfungiblePositionManager.CollectParams({
//                 tokenId: tokenId,
//                 recipient: to,
//                 amount0Max: type(uint128).max,
//                 amount1Max: type(uint128).max
//             })
//         );
//     }
// }
