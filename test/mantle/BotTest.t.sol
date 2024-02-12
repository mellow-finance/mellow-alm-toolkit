// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Integration is Test {
    using SafeERC20 for IERC20;

    INonfungiblePositionManager public positionManager =
        INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER);
    IAgniFactory public factory = IAgniFactory(Constants.AGNI_FACTORY);
    IAgniPool public pool =
        IAgniPool(factory.getPool(Constants.USDC, Constants.WETH, 2500));

    function removePosition(
        Core core,
        uint256 tokenId
    )
        public
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 liquidityAmount0,
            uint256 liquidityAmount1
        )
    {
        vm.startPrank(address(core));
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();

        (, , , , , , , uint128 liquidity, , , , ) = positionManager.positions(
            tokenId
        );
        (amount0, amount1) = PositionValue.total(
            positionManager,
            tokenId,
            sqrtRatioX96,
            pool
        );

        (liquidityAmount0, liquidityAmount1) = positionManager
            .decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: type(uint256).max
                })
            );

        positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                recipient: address(core),
                tokenId: tokenId,
                amount0Max: uint128(liquidityAmount0),
                amount1Max: uint128(liquidityAmount1)
            })
        );

        vm.stopPrank();
    }

    function addPosition(
        Core core,
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1
    ) public {
        vm.startPrank(address(core));
        IERC20(pool.token0()).safeIncreaseAllowance(
            address(positionManager),
            amount0
        );
        IERC20(pool.token1()).safeIncreaseAllowance(
            address(positionManager),
            amount1
        );
        positionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint256).max
            })
        );
        vm.stopPrank();
    }

    function determineSwapAmounts(
        Core core,
        PulseAgniBot bot,
        uint256 id
    ) public returns (bool, PulseAgniBot.SwapParams memory swapParams) {
        vm.startPrank(Constants.OWNER);
        ICore.NftsInfo memory info = core.nfts(id);
        (bool flag, ICore.TargetNftsInfo memory target) = core
            .strategyModule()
            .getTargets(info, core.ammModule(), core.oracle());
        uint256 tokenId = info.tokenIds[0];
        if (tokenId == 0) revert("Invalid token id");
        if (!flag) return (false, swapParams);
        vm.stopPrank();

        (
            uint256 amount0,
            uint256 amount1,
            uint256 liquidityAmount0,
            uint256 liquidityAmount1
        ) = removePosition(core, tokenId);

        swapParams = bot.calculateSwapAmountsPreciselySingle(
            PulseAgniBot.SingleIntervalData({
                amount0: amount0,
                amount1: amount1,
                sqrtLowerRatioX96: TickMath.getSqrtRatioAtTick(
                    target.lowerTicks[0]
                ),
                sqrtUpperRatioX96: TickMath.getSqrtRatioAtTick(
                    target.upperTicks[0]
                ),
                pool: pool
            })
        );

        addPosition(core, tokenId, liquidityAmount0, liquidityAmount1);

        return (true, swapParams);
    }

    function calculateRebalanceData(
        Core core,
        PulseAgniBot bot,
        uint256 tokenId
    ) public returns (bool, ICore.RebalanceParams memory rebalanceParams) {
        (
            bool flag,
            PulseAgniBot.SwapParams memory swapParams
        ) = determineSwapAmounts(core, bot, tokenId);
        if (!flag) {
            return (false, rebalanceParams);
        }
        rebalanceParams.ids = new uint256[](1);
        rebalanceParams.ids[0] = tokenId;
        rebalanceParams.callback = address(bot);
        ISwapRouter.ExactInputSingleParams[]
            memory ammParams = new ISwapRouter.ExactInputSingleParams[](1);
        ammParams[0] = ISwapRouter.ExactInputSingleParams({
            tokenIn: swapParams.tokenIn,
            tokenOut: swapParams.tokenOut,
            fee: swapParams.fee,
            amountIn: swapParams.amountIn,
            amountOutMinimum: (swapParams.expectedAmountOut * 9999) / 10000,
            deadline: type(uint256).max,
            recipient: address(bot),
            sqrtPriceLimitX96: 0
        });
        rebalanceParams.data = abi.encode(ammParams);
        return (true, rebalanceParams);
    }

    function testBot() external {
        Core core = Core(0x4b8e8aDbC9120ed438dF9DEe7ed0009f9D4B33E9);
        PulseAgniBot bot = PulseAgniBot(
            0x15b1bC5DF5C44F469394D295959bBEC861893F09
        );

        uint256 count = 1; // core.nftCount();
        for (uint256 nftId = 0; nftId < count; nftId++) {
            (
                bool flag,
                ICore.RebalanceParams memory rebalanceParams
            ) = calculateRebalanceData(core, bot, nftId);
            if (!flag) continue;
            string memory jsonPath = "/tmp/state_4.json";
            if (flag) {
                string memory s = string(
                    abi.encodePacked(
                        "{ ",
                        '"to": ',
                        vm.toString(address(core)),
                        ","
                        '"data": ',
                        vm.toString(
                            abi.encodeWithSelector(
                                core.rebalance.selector,
                                rebalanceParams
                            )
                        ),
                        " }"
                    )
                );
                console2.log("nft for rebalance:", nftId, "; data:", s);
                vm.writeJson(s, jsonPath);
            }
        }
    }
}
