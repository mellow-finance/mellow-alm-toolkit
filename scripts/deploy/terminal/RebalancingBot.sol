// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "src/Core.sol";
import "src/modules/terminal/TerminalAmmModule.sol";

contract RebalancingBot is IRebalanceCallback {
    using SafeERC20 for IERC20;

    IVeloAmmModule public ammModule;
    INonfungiblePositionManager public immutable positionManager;

    constructor(INonfungiblePositionManager positionManager_) {
        positionManager = positionManager_;
        ammModule = IVeloAmmModule(address(new TerminalAmmModule(positionManager_)));
    }

    function _pullLiquidity(uint256 tokenId) internal {
        if (tokenId == 0) {
            return;
        }
        IVeloAmmModule.Position memory position = ammModule.getPosition(tokenId);
        if (position.liquidity == 0) {
            return;
        }
        positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: position.liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint256).max
            })
        );
        positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max,
                rewardMax: type(uint128).max
            })
        );
    }

    function _mint(address pool, int24 tickLower, int24 tickUpper, uint128 liquidity)
        internal
        returns (uint256 tokenId)
    {
        uint160 sqrtRatioX96 = ammModule.getSqrtPriceX96(pool);
        (address token0, address token1) = ammModule.getPoolTokens(pool);

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity * 10001 / 10000 + 100 // just to create not less than required liquidity
        );
        if (amount0 > 0) {
            IERC20(token0).safeIncreaseAllowance(address(positionManager), amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).safeIncreaseAllowance(address(positionManager), amount1);
        }
        (tokenId,,,) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                tickSpacing: int24(ammModule.getProperty(pool)),
                tickLower: tickLower,
                tickUpper: tickUpper,
                isStaked: true,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: type(uint256).max
            })
        );
    }

    struct SwapData {
        address target;
        bytes data;
    }

    function call(
        bytes memory data,
        ICore.TargetPositionInfo memory target,
        ICore.ManagedPositionInfo memory info
    ) external returns (uint256[] memory tokenIds) {
        for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
            _pullLiquidity(info.ammPositionIds[i]);
        }

        if (data.length != 0) {
            SwapData[] memory swaps = abi.decode(data, (SwapData[]));
            for (uint256 i = 0; i < swaps.length; i++) {
                Address.functionCall(swaps[i].target, swaps[i].data);
            }
        }

        uint256 length = target.lowerTicks.length;
        tokenIds = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            tokenIds[i] = _mint(
                info.pool,
                target.lowerTicks[i],
                target.upperTicks[i],
                uint128(target.minLiquidities[i])
            );
            positionManager.approve(msg.sender, tokenIds[i]);
        }
    }

    function test() internal pure {}
}
