// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

// import "forge-std/Test.sol";
// import "forge-std/Vm.sol";

// import "../../src/interfaces/bots/IPulseAgniBot.sol";
// import "../../src/libraries/external/agni/PositionValue.sol";

// interface IERC20 {
//     function approve(address, uint256) external returns (bool);
// }

// contract Integration is Test {
//     enum Status {
//         OK,
//         SKIP,
//         ERROR
//     }

//     address public constant NONFUNGIBLE_POSITION_MANAGER =
//         0x218bf598D1453383e2F4AA7b14fFB9BfB102D637;
//     address public constant AGNI_FACTORY =
//         0x25780dc8Fc3cfBD75F33bFDAB65e969b603b2035;

//     INonfungiblePositionManager public positionManager =
//         INonfungiblePositionManager(NONFUNGIBLE_POSITION_MANAGER);
//     IAgniFactory public factory = IAgniFactory(AGNI_FACTORY);

//     function removePosition(
//         ICore core,
//         IAgniPool pool,
//         uint256 tokenId
//     )
//         public
//         returns (
//             uint256 amount0,
//             uint256 amount1,
//             uint256 liquidityAmount0,
//             uint256 liquidityAmount1
//         )
//     {
//         vm.startPrank(address(core));
//         (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();

//         (, , , , , , , uint128 liquidity, , , , ) = positionManager.positions(
//             tokenId
//         );
//         (amount0, amount1) = PositionValue.total(
//             positionManager,
//             tokenId,
//             sqrtRatioX96,
//             pool
//         );

//         (liquidityAmount0, liquidityAmount1) = positionManager
//             .decreaseLiquidity(
//                 INonfungiblePositionManager.DecreaseLiquidityParams({
//                     tokenId: tokenId,
//                     liquidity: liquidity,
//                     amount0Min: 0,
//                     amount1Min: 0,
//                     deadline: type(uint256).max
//                 })
//             );

//         positionManager.collect(
//             INonfungiblePositionManager.CollectParams({
//                 recipient: address(core),
//                 tokenId: tokenId,
//                 amount0Max: uint128(liquidityAmount0),
//                 amount1Max: uint128(liquidityAmount1)
//             })
//         );

//         vm.stopPrank();
//     }

//     function addPosition(
//         ICore core,
//         IAgniPool pool,
//         uint256 tokenId,
//         uint256 amount0,
//         uint256 amount1
//     ) public {
//         vm.startPrank(address(core));
//         IERC20(pool.token0()).approve(address(positionManager), amount0);
//         IERC20(pool.token1()).approve(address(positionManager), amount1);
//         positionManager.increaseLiquidity(
//             INonfungiblePositionManager.IncreaseLiquidityParams({
//                 tokenId: tokenId,
//                 amount0Desired: amount0,
//                 amount1Desired: amount1,
//                 amount0Min: 0,
//                 amount1Min: 0,
//                 deadline: type(uint256).max
//             })
//         );
//         vm.stopPrank();
//     }

//     function determineSwapAmounts(
//         ICore core,
//         IPulseAgniBot bot,
//         uint256 id
//     ) public returns (Status, IPulseAgniBot.SwapParams memory swapParams) {
//         ICore.ManagedPositionInfo memory info;
//         try core.position(id) returns (ICore.ManagedPositionInfo memory _info) {
//             info = _info;
//         } catch {
//             return (Status.ERROR, swapParams);
//         }
//         if (info.tokenIds.length == 0) return (Status.SKIP, swapParams);
//         try core.oracle().ensureNoMEV(info.pool, info.securityParams) {} catch {
//             return (Status.ERROR, swapParams);
//         }
//         (bool flag, ICore.TargetPositionInfo memory target) = core
//             .strategyModule()
//             .getTargets(info, core.ammModule(), core.oracle());
//         uint256 tokenId = info.tokenIds[0];
//         if (tokenId == 0) revert("Invalid token id");
//         if (!flag) return (Status.SKIP, swapParams);
//         IAgniPool pool = IAgniPool(info.pool);
//         (
//             uint256 amount0,
//             uint256 amount1,
//             uint256 liquidityAmount0,
//             uint256 liquidityAmount1
//         ) = removePosition(core, pool, tokenId);

//         swapParams = bot.calculateSwapAmountsPreciselySingle(
//             IPulseAgniBot.SingleIntervalData({
//                 amount0: amount0,
//                 amount1: amount1,
//                 sqrtLowerRatioX96: TickMath.getSqrtRatioAtTick(
//                     target.lowerTicks[0]
//                 ),
//                 sqrtUpperRatioX96: TickMath.getSqrtRatioAtTick(
//                     target.upperTicks[0]
//                 ),
//                 pool: pool
//             })
//         );

//         addPosition(core, pool, tokenId, liquidityAmount0, liquidityAmount1);

//         return (Status.OK, swapParams);
//     }

//     function calculateRebalanceData(
//         ICore core,
//         IPulseAgniBot bot,
//         uint256 tokenId
//     ) public returns (Status, ICore.RebalanceParams memory rebalanceParams) {
//         (
//             Status status,
//             IPulseAgniBot.SwapParams memory swapParams
//         ) = determineSwapAmounts(core, bot, tokenId);
//         if (status != Status.OK) {
//             return (status, rebalanceParams);
//         }
//         rebalanceParams.ids = new uint256[](1);
//         rebalanceParams.ids[0] = tokenId;
//         rebalanceParams.callback = address(bot);
//         ISwapRouter.ExactInputSingleParams[]
//             memory ammParams = new ISwapRouter.ExactInputSingleParams[](1);
//         ammParams[0] = ISwapRouter.ExactInputSingleParams({
//             tokenIn: swapParams.tokenIn,
//             tokenOut: swapParams.tokenOut,
//             fee: swapParams.fee,
//             amountIn: swapParams.amountIn,
//             amountOutMinimum: (swapParams.expectedAmountOut * 9999) / 10000,
//             deadline: type(uint256).max,
//             recipient: address(bot),
//             sqrtPriceLimitX96: 0
//         });
//         rebalanceParams.data = abi.encode(ammParams);
//         return (status, rebalanceParams);
//     }

//     function getRebalanceData(address coreAddress, address botAddress) public {
//         ICore core = ICore(coreAddress);
//         IPulseAgniBot bot = IPulseAgniBot(botAddress);

//         string memory jsonPath = "/tmp/state_4.json";
//         for (uint256 nftId = 0; nftId < 10000; nftId++) {
//             (
//                 Status status,
//                 ICore.RebalanceParams memory rebalanceParams
//             ) = calculateRebalanceData(core, bot, nftId);
//             if (status == Status.SKIP) continue;
//             if (status == Status.ERROR) break;
//             string memory rebalanceData = string(
//                 abi.encodePacked(
//                     "{ ",
//                     '"to": ',
//                     vm.toString(address(core)),
//                     ","
//                     '"data": ',
//                     vm.toString(
//                         abi.encodeWithSelector(
//                             core.rebalance.selector,
//                             rebalanceParams
//                         )
//                     ),
//                     " }"
//                 )
//             );
//             console2.log("nft for rebalance:", nftId, "; data:", rebalanceData);
//             vm.writeJson(rebalanceData, jsonPath);
//             return;
//         }
//         console2.log("nothing to rebalance");
//         vm.writeJson(
//             string(
//                 abi.encodePacked("{ ", '"to": ', vm.toString(address(0)), " }")
//             ),
//             jsonPath
//         );
//     }

//     function test() external {
//         getRebalanceData(
//             0x4b8e8aDbC9120ed438dF9DEe7ed0009f9D4B33E9,
//             0x15b1bC5DF5C44F469394D295959bBEC861893F09
//         );
//     }
// }
