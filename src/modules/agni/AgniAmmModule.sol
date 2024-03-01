// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// import "../../interfaces/modules/IAmmModule.sol";

// import "../../interfaces/external/agni/IAgniPool.sol";
// import "../../interfaces/external/agni/IAgniFactory.sol";
// import "../../interfaces/external/agni/INonfungiblePositionManager.sol";
// import "../../interfaces/external/agni/IMasterChefV3.sol";

// import "../../libraries/external/LiquidityAmounts.sol";
// import "../../libraries/external/agni/PositionValue.sol";

// import "../../libraries/external/TickMath.sol";

// contract AgniAmmModule is IAmmModule {
//     using SafeERC20 for IERC20;

//     address public immutable positionManager;
//     IAgniFactory public immutable factory;

//     constructor(INonfungiblePositionManager positionManager_) {
//         positionManager = address(positionManager_);
//         factory = IAgniFactory(positionManager_.factory());
//     }

//     /**
//      * @dev Calculates the amounts of token0 and token1 for a given liquidity amount.
//      * @param liquidity The liquidity amount.
//      * @param sqrtPriceX96 The square root of the current price of the pool.
//      * @param tickLower The lower tick of the range.
//      * @param tickUpper The upper tick of the range.
//      * @return The amounts of token0 and token1.
//      */
//     function getAmountsForLiquidity(
//         uint128 liquidity,
//         uint160 sqrtPriceX96,
//         int24 tickLower,
//         int24 tickUpper
//     ) external pure override returns (uint256, uint256) {
//         return
//             LiquidityAmounts.getAmountsForLiquidity(
//                 sqrtPriceX96,
//                 TickMath.getSqrtRatioAtTick(tickLower),
//                 TickMath.getSqrtRatioAtTick(tickUpper),
//                 liquidity
//             );
//     }

//     /**
//      * @dev Calculates the total value locked (TVL) for a given token ID and pool.
//      * @param tokenId The ID of the token.
//      * @param sqrtRatioX96 The square root of the current tick value of the pool.
//      * @param pool The address of the pool contract.
//      * @return uint256, uint256 - amount0 and amount1 locked in the position.
//      */
//     function tvl(
//         uint256 tokenId,
//         uint160 sqrtRatioX96,
//         address pool,
//         address
//     ) external view override returns (uint256, uint256) {
//         return
//             PositionValue.total(
//                 INonfungiblePositionManager(positionManager),
//                 tokenId,
//                 sqrtRatioX96,
//                 IAgniPool(pool)
//             );
//     }

//     /**
//      * @dev Retrieves the information of a position.
//      * @param tokenId The ID of the position.
//      * @return position The Position struct containing the position information.
//      */
//     function getPositionInfo(
//         uint256 tokenId
//     ) public view override returns (Position memory position) {
//         (
//             ,
//             ,
//             position.token0,
//             position.token1,
//             position.property,
//             position.tickLower,
//             position.tickUpper,
//             position.liquidity,
//             ,
//             ,
//             ,

//         ) = INonfungiblePositionManager(positionManager).positions(tokenId);
//     }

//     /**
//      * @dev Retrieves the address of the pool for the specified tokens and fee.
//      * @param token0 The address of the first token in the pool.
//      * @param token1 The address of the second token in the pool.
//      * @param fee The fee of the pool.
//      * @return address The address of the pool.
//      */
//     function getPool(
//         address token0,
//         address token1,
//         uint24 fee
//     ) external view override returns (address) {
//         return factory.getPool(token0, token1, fee);
//     }

//     /**
//      * @dev Retrieves the fee property of a given pool.
//      * @param pool The address of the pool.
//      * @return uint24 fee value of the pool.
//      */
//     function getProperty(address pool) external view override returns (uint24) {
//         return IAgniPool(pool).fee();
//     }

//     /**
//      * @dev Executes actions before rebalancing.
//      * @param farm The address of the farm contract.
//      * @param synthetixFarm The address of the Synthetix farm contract.
//      * @param tokenId The ID of the token.
//      */
//     function beforeRebalance(
//         address farm,
//         address synthetixFarm,
//         uint256 tokenId
//     ) external virtual override {
//         if (farm == address(0)) return;
//         require(
//             synthetixFarm != address(0),
//             "AgniAmmModule: synthetixFarm is zero"
//         );
//         IMasterChefV3(farm).harvest(tokenId, synthetixFarm);
//         IMasterChefV3(farm).withdraw(tokenId, address(this));
//     }

//     /**
//      * @dev Executes after a rebalance operation.
//      * @param farm The address of the farm.
//      * @param tokenId The ID of the token being transferred.
//      */
//     function afterRebalance(
//         address farm,
//         address,
//         uint256 tokenId
//     ) external virtual override {
//         if (farm == address(0)) return;
//         INonfungiblePositionManager(positionManager).safeTransferFrom(
//             address(this),
//             address(farm),
//             tokenId
//         );
//     }

//     function transferFrom(
//         address from,
//         address to,
//         uint256 tokenId
//     ) external virtual override {
//         INonfungiblePositionManager(positionManager).transferFrom(
//             from,
//             to,
//             tokenId
//         );
//     }
// }
