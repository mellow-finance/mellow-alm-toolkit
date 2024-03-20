// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Integration is Fixture {
    using SafeERC20 for IERC20;

    function testSynthetixFarm() external {
        ICore.DepositParams memory depositParams;
        depositParams.ammPositionIds = new uint256[](1);
        depositParams.ammPositionIds[0] = mint(
            Constants.OP,
            Constants.WETH,
            TICK_SPACING,
            pool.tickSpacing() * 8,
            1e9
        );
        depositParams.owner = Constants.OWNER;
        depositParams.callbackParams = abi.encode(
            IVeloAmmModule.CallbackParams({
                farm: address(0),
                gauge: address(0),
                counter: address(0)
            })
        );

        depositParams.strategyParams = abi.encode(
            IPulseStrategyModule.StrategyParams({
                tickNeighborhood: pool.tickSpacing() / 4,
                tickSpacing: pool.tickSpacing(),
                strategyType: IPulseStrategyModule.StrategyType.Original,
                width: pool.tickSpacing()
            })
        );

        Counter counter = new Counter(Constants.OWNER, address(core));

        depositParams.securityParams = new bytes(0);
        depositParams.slippageD4 = 100;
        depositParams.callbackParams = abi.encode(
            IVeloAmmModule.CallbackParams({
                farm: address(stakingRewards),
                gauge: pool.gauge(),
                counter: address(counter)
            })
        );

        vm.startPrank(Constants.OWNER);
        positionManager.approve(address(core), depositParams.ammPositionIds[0]);
        {
            uint256 nftId = core.deposit(depositParams);
            core.withdraw(nftId, Constants.OWNER);
        }

        positionManager.approve(address(core), depositParams.ammPositionIds[0]);
        depositParams.owner = address(lpWrapper);

        uint256 nftId2 = core.deposit(depositParams);

        lpWrapper.initialize(nftId2, 5e5);
        vm.stopPrank();

        vm.startPrank(Constants.DEPOSITOR);
        deal(Constants.OP, Constants.DEPOSITOR, 1e6 * 1e6);
        deal(Constants.WETH, Constants.DEPOSITOR, 500 ether);
        IERC20(Constants.OP).safeApprove(address(lpWrapper), type(uint256).max);
        IERC20(Constants.WETH).safeApprove(
            address(lpWrapper),
            type(uint256).max
        );
        {
            (, , uint256 lpAmount) = lpWrapper.deposit(
                500 ether,
                1e6,
                1e3,
                Constants.DEPOSITOR
            );
            require(lpAmount > 0, "Invalid lp amount");
            console2.log("Actual lp amount:", lpAmount);
            lpWrapper.approve(address(stakingRewards), type(uint256).max);
            stakingRewards.stake(lpWrapper.balanceOf(Constants.DEPOSITOR));
        }
        vm.stopPrank();

        for (uint256 i = 0; i < 2; i++) {
            {
                vm.startPrank(Constants.DEPOSITOR);
                stakingRewards.withdraw(
                    stakingRewards.balanceOf(Constants.DEPOSITOR) / 2
                );
                (
                    uint256 amount0,
                    uint256 amount1,
                    uint256 actualAmountLp
                ) = lpWrapper.withdraw(1e6, 0, 0, Constants.DEPOSITOR);

                console2.log(
                    "Actual withdrawal amounts for depositor:",
                    amount0,
                    amount1,
                    actualAmountLp
                );

                vm.stopPrank();
            }

            {
                uint256[] memory ids = new uint256[](1);
                ids[0] = lpWrapper.positionId();
                while (true) {
                    movePrice(uint256(20));
                    (bool flag, ) = core.strategyModule().getTargets(
                        core.managedPositionAt(lpWrapper.positionId()),
                        core.ammModule(),
                        core.oracle()
                    );
                    skip(5 * 60);
                    if (flag) break;
                }
            }
            PulseVeloBot.SwapParams memory swapParams = determineSwapAmounts(
                lpWrapper.positionId()
            );
            ICore.RebalanceParams memory rebalanceParams;

            rebalanceParams.ids = new uint256[](1);
            rebalanceParams.ids[0] = lpWrapper.positionId();
            rebalanceParams.callback = address(bot);
            ISwapRouter.ExactInputSingleParams[]
                memory ammParams = new ISwapRouter.ExactInputSingleParams[](1);
            ammParams[0] = ISwapRouter.ExactInputSingleParams({
                tokenIn: swapParams.tokenIn,
                tokenOut: swapParams.tokenOut,
                tickSpacing: swapParams.tickSpacing,
                amountIn: swapParams.amountIn,
                amountOutMinimum: (swapParams.expectedAmountOut * 9999) / 10000,
                deadline: type(uint256).max,
                recipient: address(bot),
                sqrtPriceLimitX96: 0
            });
            rebalanceParams.data = abi.encode(ammParams);

            vm.prank(Constants.OWNER);
            core.rebalance(rebalanceParams);

            {
                ICore.ManagedPositionInfo memory info = core.managedPositionAt(
                    lpWrapper.positionId()
                );
                uint160 sqrtPriceX96;
                (sqrtPriceX96, , , , , ) = pool.slot0();

                (uint256 amount0, uint256 amount1) = PositionValue.total(
                    positionManager,
                    info.ammPositionIds[0],
                    sqrtPriceX96
                );
                uint256 priceX96 = FullMath.mulDiv(
                    sqrtPriceX96,
                    sqrtPriceX96,
                    2 ** 96
                );
                uint256 capital = FullMath.mulDiv(amount0, priceX96, 2 ** 96) +
                    amount1;
                console2.log("Capital usdc:", capital);
                console2.log(
                    "New position params:",
                    vm.toString(info.ammPositionIds[0])
                );
            }
        }
    }
}
