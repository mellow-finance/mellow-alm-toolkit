// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Integration is Fixture {
    using SafeERC20 for IERC20;

    struct DepositParams {
        int24 width;
        int24 tickNeighborhood;
        int24 tickSpacing;
        uint16 slippageD4;
        bytes securityParams;
    }

    uint256 public moveCoef = 1e4;

    function makeDeposit(DepositParams memory params) public returns (uint256) {
        ICore.DepositParams memory depositParams;
        depositParams.tokenIds = new uint256[](1);
        depositParams.tokenIds[0] = mint(
            Constants.USDC,
            Constants.WETH,
            TICK_SPACING,
            params.width,
            1e9
        );
        depositParams.owner = Constants.OWNER;
        depositParams.farm = address(0);
        depositParams.strategyParams = abi.encode(
            IPulseStrategyModule.StrategyParams({
                tickNeighborhood: params.tickNeighborhood,
                tickSpacing: params.tickSpacing,
                strategyType: IPulseStrategyModule.StrategyType.Original
            })
        );
        depositParams.securityParams = params.securityParams;
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

    function testDepositWithdraw() external {
        int24 tickSpacing = pool.tickSpacing();
        makeDeposit(
            DepositParams({
                tickSpacing: tickSpacing,
                width: tickSpacing * 4,
                tickNeighborhood: tickSpacing,
                slippageD4: 100,
                securityParams: new bytes(0)
            })
        );

        vm.startPrank(Constants.DEPOSITOR);
        uint256 usdcAmount = 1e6 * 1e6;
        uint256 wethAmount = 500 ether;
        deal(Constants.USDC, Constants.DEPOSITOR, usdcAmount);
        deal(Constants.WETH, Constants.DEPOSITOR, wethAmount);
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
                wethAmount / 1e6,
                usdcAmount / 1e6,
                1e8,
                Constants.DEPOSITOR
            );
            require(lpAmount > 1e8, "Invalid lp amount");
            console2.log("Actual lp amount:", lpAmount);
            lpWrapper.approve(address(stakingRewards), type(uint256).max);
            stakingRewards.stake(lpWrapper.balanceOf(Constants.DEPOSITOR));
        }
        vm.stopPrank();

        for (uint256 i = 0; i < 5; i++) {
            vm.startPrank(Constants.DEPOSITOR);
            stakingRewards.withdraw(
                stakingRewards.balanceOf(Constants.DEPOSITOR) / 2
            );
            uint256 lpAmount = lpWrapper.balanceOf(Constants.DEPOSITOR);
            (
                uint256 amount0,
                uint256 amount1,
                uint256 actualAmountLp
            ) = lpWrapper.withdraw(lpAmount, 0, 0, Constants.DEPOSITOR);

            console2.log(
                "Actual withdrawal amounts for depositor:",
                amount0,
                amount1,
                actualAmountLp
            );
            vm.stopPrank();
        }

        uint256 balance0 = IERC20(Constants.WETH).balanceOf(
            Constants.DEPOSITOR
        );
        uint256 balance1 = IERC20(Constants.USDC).balanceOf(
            Constants.DEPOSITOR
        );

        for (uint256 i = 1; i <= 5; i++) {
            vm.startPrank(Constants.DEPOSITOR);
            uint256 amount0 = balance0 / 2 ** i;
            uint256 amount1 = balance1 / 2 ** i;

            (
                uint256 actualAmount0,
                uint256 actualAmount1,
                uint256 lpAmount
            ) = lpWrapper.deposit(amount0, amount1, 0, Constants.DEPOSITOR);

            console2.log(
                "Actual deposit amounts for depositor:",
                actualAmount0,
                actualAmount1,
                lpAmount
            );
            vm.stopPrank();
        }
    }

    function testDepositRebalanceWithdraw() external {
        int24 tickSpacing = pool.tickSpacing();
        makeDeposit(
            DepositParams({
                tickSpacing: tickSpacing,
                width: tickSpacing * 10,
                tickNeighborhood: tickSpacing,
                slippageD4: 100,
                securityParams: new bytes(0)
            })
        );

        vm.startPrank(Constants.DEPOSITOR);
        uint256 usdcAmount = 1e6 * 1e6;
        uint256 wethAmount = 500 ether;
        deal(Constants.USDC, Constants.DEPOSITOR, usdcAmount);
        deal(Constants.WETH, Constants.DEPOSITOR, wethAmount);
        IERC20(Constants.USDC).safeApprove(
            address(lpWrapper),
            type(uint256).max
        );
        IERC20(Constants.WETH).safeApprove(
            address(lpWrapper),
            type(uint256).max
        );
        uint256 depositedAmount0;
        uint256 depositedAmount1;

        {
            uint256 lpAmount;
            (depositedAmount0, depositedAmount1, lpAmount) = lpWrapper.deposit(
                wethAmount / 1e6,
                usdcAmount / 1e6,
                1e8,
                Constants.DEPOSITOR
            );
            require(lpAmount > 1e8, "Invalid lp amount");
            console2.log("Actual lp amount:", lpAmount);
            lpWrapper.approve(address(stakingRewards), type(uint256).max);
            stakingRewards.stake(lpWrapper.balanceOf(Constants.DEPOSITOR));
        }
        vm.stopPrank();
        {
            (, int24 tick, , , , ) = pool.slot0();
            console2.log("Tick before:", vm.toString(tick));
        }
        movePrice(uint256(moveCoef));
        skip(5 * 60);
        {
            (, int24 tick, , , , ) = pool.slot0();
            console2.log("Tick after:", vm.toString(tick));
        }

        {
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

            vm.startPrank(Constants.OWNER);
            core.rebalance(rebalanceParams);
            vm.stopPrank();
        }
        uint256 withdrawAmount0;
        uint256 withdrawAmount1;
        {
            vm.startPrank(Constants.DEPOSITOR);
            stakingRewards.withdraw(
                stakingRewards.balanceOf(Constants.DEPOSITOR)
            );
            uint256 lpAmount = lpWrapper.balanceOf(Constants.DEPOSITOR);
            (withdrawAmount0, withdrawAmount1, ) = lpWrapper.withdraw(
                lpAmount,
                0,
                0,
                Constants.DEPOSITOR
            );
            vm.stopPrank();
        }
        console2.log(
            "Actual withdrawal amounts for depositor:",
            withdrawAmount0,
            withdrawAmount1
        );
        console2.log(
            "Actual deposited amounts for depositor:",
            depositedAmount0,
            depositedAmount1
        );
        console2.log(depositedAmount0, withdrawAmount0);
        console2.log(depositedAmount1, withdrawAmount1);

        assertTrue((depositedAmount0 * 95) / 100 <= withdrawAmount0);
        assertTrue((depositedAmount1 * 95) / 100 <= withdrawAmount1);
    }

    function testMEVDetection() external {
        int24 tickSpacing = pool.tickSpacing();
        makeDeposit(
            DepositParams({
                tickSpacing: tickSpacing,
                width: tickSpacing * 10,
                tickNeighborhood: tickSpacing,
                slippageD4: 100,
                securityParams: abi.encode(
                    IVeloOracle.SecurityParams({
                        lookback: 10,
                        maxAllowedDelta: 10
                    })
                )
            })
        );

        vm.startPrank(Constants.DEPOSITOR);
        uint256 usdcAmount = 1e6 * 1e6;
        uint256 wethAmount = 500 ether;
        deal(Constants.USDC, Constants.DEPOSITOR, usdcAmount);
        deal(Constants.WETH, Constants.DEPOSITOR, wethAmount);
        IERC20(Constants.USDC).safeApprove(
            address(lpWrapper),
            type(uint256).max
        );
        IERC20(Constants.WETH).safeApprove(
            address(lpWrapper),
            type(uint256).max
        );
        uint256 depositedAmount0;
        uint256 depositedAmount1;

        {
            uint256 lpAmount;
            (depositedAmount0, depositedAmount1, lpAmount) = lpWrapper.deposit(
                wethAmount / 1e6,
                usdcAmount / 1e6,
                1e8,
                Constants.DEPOSITOR
            );
            require(lpAmount > 1e8, "Invalid lp amount");
            console2.log("Actual lp amount:", lpAmount);
            lpWrapper.approve(address(stakingRewards), type(uint256).max);
            stakingRewards.stake(lpWrapper.balanceOf(Constants.DEPOSITOR));
        }
        vm.stopPrank();

        movePrice(uint256(moveCoef));
        skip(5 * 60);

        {
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

            vm.startPrank(Constants.OWNER);
            vm.expectRevert(bytes4(0xd9218acd));
            core.rebalance(rebalanceParams);
            vm.stopPrank();
        }
        uint256 withdrawAmount0;
        uint256 withdrawAmount1;
        {
            vm.startPrank(Constants.DEPOSITOR);
            stakingRewards.withdraw(
                stakingRewards.balanceOf(Constants.DEPOSITOR)
            );
            uint256 lpAmount = lpWrapper.balanceOf(Constants.DEPOSITOR);
            (withdrawAmount0, withdrawAmount1, ) = lpWrapper.withdraw(
                lpAmount,
                0,
                0,
                Constants.DEPOSITOR
            );
            vm.stopPrank();
        }
        assertTrue(depositedAmount0 > withdrawAmount0);
        assertTrue(depositedAmount1 < withdrawAmount1);
    }

    function testOracleEnsureNoMEV() external {
        // vm.expectRevert(abi.encodeWithSignature("PriceManipulationDetected()"));
        // oracle.ensureNoMEV(
        //     address(pool),
        //     abi.encode(
        //         IVeloOracle.SecurityParams({lookback: 5, maxAllowedDelta: 0})
        //     )
        // );
        vm.expectRevert(abi.encodeWithSignature("NotEnoughObservations()"));
        oracle.ensureNoMEV(
            address(pool),
            abi.encode(
                IVeloOracle.SecurityParams({
                    lookback: 1000,
                    maxAllowedDelta: 10
                })
            )
        );
        // vm.expectRevert(abi.encodeWithSignature("NotEnoughObservations()"));
        // oracle.ensureNoMEV(
        //     address(pool),
        //     abi.encode(
        //         VeloOracle.SecurityParams({lookback: 100, maxAllowedDelta: 1})
        //     )
        // );
        // vm.expectRevert(abi.encodeWithSignature("PriceManipulationDetected()"));
        // oracle.ensureNoMEV(
        //     address(pool),
        //     abi.encode(
        //         VeloOracle.SecurityParams({lookback: 1, maxAllowedDelta: 0})
        //     )
        // );

        // oracle.ensureNoMEV(
        //     address(pool),
        //     abi.encode(
        //         VeloOracle.SecurityParams({lookback: 5, maxAllowedDelta: 50})
        //     )
        // );
    }

    function testOracleValidateSecurityParams() external {
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        oracle.validateSecurityParams(
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 0, maxAllowedDelta: 0})
            )
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        oracle.validateSecurityParams(
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 1, maxAllowedDelta: -1})
            )
        );
        oracle.validateSecurityParams(
            abi.encode(
                IVeloOracle.SecurityParams({lookback: 10, maxAllowedDelta: 10})
            )
        );
    }
}
