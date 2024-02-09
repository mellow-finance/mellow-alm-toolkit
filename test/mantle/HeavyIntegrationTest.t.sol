// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Integration is Fixture {
    using SafeERC20 for IERC20;

    struct DepositParams {
        int24 width;
        int24 tickNeighborhood;
        int24 tickSpacing;
        uint16 slippageD4;
    }

    function makeDeposit(DepositParams memory params) public returns (uint256) {
        ICore.DepositParams memory depositParams;
        depositParams.tokenIds = new uint256[](1);
        depositParams.tokenIds[0] = mint(
            Constants.USDC,
            Constants.WETH,
            FEE,
            params.width,
            1e9
        );
        depositParams.owner = Constants.OWNER;
        depositParams.farm = address(0);
        depositParams.strategyParams = abi.encode(
            PulseStrategyModule.StrategyParams({
                tickNeighborhood: params.tickNeighborhood,
                tickSpacing: params.tickSpacing
            })
        );
        depositParams.securityParams = new bytes(0);
        depositParams.slippageD4 = params.slippageD4;
        depositParams.owner = address(lpWrapper);
        depositParams.vault = address(stakingRewards);

        vm.startPrank(Constants.OWNER);
        positionManager.approve(address(core), depositParams.tokenIds[0]);
        uint256 nftId = core.deposit(depositParams);
        lpWrapper.initialize(nftId, 5e5);
        vm.stopPrank();
        return nftId;
    }

    function testHeavy() external {
        int24 tickSpacing = pool.tickSpacing();
        makeDeposit(
            DepositParams({
                tickSpacing: tickSpacing,
                width: tickSpacing * 10,
                tickNeighborhood: tickSpacing,
                slippageD4: 100
            })
        );

        vm.startPrank(Constants.DEPOSITOR);
        deal(Constants.USDC, Constants.DEPOSITOR, 1e6 * 1e6);
        deal(Constants.WETH, Constants.DEPOSITOR, 500 ether);
        IERC20(Constants.USDC).safeApprove(
            address(lpWrapper),
            type(uint256).max
        );
        IERC20(Constants.WETH).safeApprove(
            address(lpWrapper),
            type(uint256).max
        );
        {
            (, , uint256 lpAmount) = lpWrapper.deposit(
                1e6,
                500 ether,
                1e3,
                Constants.DEPOSITOR
            );
            require(lpAmount > 0, "Invalid lp amount");
            console2.log("Actual lp amount:", lpAmount);
            lpWrapper.approve(address(stakingRewards), type(uint256).max);
            stakingRewards.stake(
                lpWrapper.balanceOf(Constants.DEPOSITOR),
                Constants.DEPOSITOR
            );
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

            ICore.TargetNftsInfo memory target;
            while (true) {
                movePrice(true);
                uint256[] memory ids = new uint256[](1);
                ids[0] = lpWrapper.tokenId();
                bool flag;
                (flag, target) = core.strategyModule().getTargets(
                    core.nfts(lpWrapper.tokenId()),
                    core.ammModule(),
                    core.oracle()
                );
                skip(5 * 60);
                if (flag) break;
            }

            PulseAgniBot.SwapParams memory swapParams = determineSwapAmounts(
                lpWrapper.tokenId()
            );
            ICore.RebalanceParams memory rebalanceParams;

            rebalanceParams.ids = new uint256[](1);
            rebalanceParams.ids[0] = lpWrapper.tokenId();
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

            vm.prank(Constants.OWNER);
            core.rebalance(rebalanceParams);

            {
                ICore.NftsInfo memory info = core.nfts(lpWrapper.tokenId());
                uint160 sqrtPriceX96;
                (sqrtPriceX96, , , , , , ) = pool.slot0();

                (uint256 amount0, uint256 amount1) = PositionValue.total(
                    positionManager,
                    info.tokenIds[0],
                    sqrtPriceX96,
                    IAgniPool(info.pool)
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
                    vm.toString(info.tokenIds[0])
                );
            }
        }
    }
}
