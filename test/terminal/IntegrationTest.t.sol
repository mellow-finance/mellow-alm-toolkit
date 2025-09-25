// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./Fixture.sol";

contract IntegrationTest is DeployScriptTerm, Fixture {
    using SafeERC20 for IERC20;

    CoreDeploymentParams private coreParams;
    CoreDeployment private contracts;

    address public TERMINAL;

    function setUp() external {
        coreParams = Constants.getDeploymentParams();
        vm.prank(coreParams.deployer);
        contracts = deployCore(coreParams);

        increaseObservationCardinality(poolAB, 2);

        (, int24 tick) = contracts.ammModule.getSqrtPriceX96AndTick(address(poolAB));
        int24 tickSpacing = poolAB.tickSpacing();
        int24 tickAligned = (tick / tickSpacing) * tickSpacing;
        mint(
            tickAligned - tickSpacing * 20,
            tickAligned + tickSpacing * 20,
            1e30,
            poolAB,
            address(this),
            true
        );
        TERMINAL = contracts.ammModule.getRewardToken(address(poolAB));
    }

    function testDeploy() external {
        address user = vm.createWallet("random-user").addr;
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(poolAB, IPulseStrategyModule.StrategyType.LazySyncing, contracts);
        vm.startPrank(user);

        uint256 amountA = 1 ether;
        uint256 amountB = 1.5 ether;

        deal(tokenA, user, amountA);
        deal(tokenB, user, amountB);

        IERC20(tokenA).safeIncreaseAllowance(address(lpWrapper), amountA);
        IERC20(tokenB).safeIncreaseAllowance(address(lpWrapper), amountB);

        uint256 n = 20;
        for (uint256 i = 0; i < n; i++) {
            lpWrapper.mint(
                ILpWrapper.MintParams({
                    lpAmount: Math.min(amountB, amountA) / n * 99 / 100,
                    amount0Max: amountB / n,
                    amount1Max: amountA / n,
                    recipient: user,
                    deadline: block.timestamp
                })
            );
            skip(1 hours);
        }

        IERC20(address(lpWrapper)).safeTransfer(user, 0);

        IERC20 rewardToken = IERC20(lpWrapper.rewardToken());
        uint256 wrapperBalanceBefore = rewardToken.balanceOf(address(lpWrapper));
        uint256 userBalanceBefore = rewardToken.balanceOf(user);
        uint256 earned = lpWrapper.earned(user);

        lpWrapper.getRewards(user);

        uint256 wrapperBalanceAfter = rewardToken.balanceOf(address(lpWrapper));
        uint256 userBalanceAfter = rewardToken.balanceOf(user);

        console2.log("user: actual/expected:", userBalanceAfter - userBalanceBefore, earned);
        console2.log("lp wrapper delta:", wrapperBalanceBefore - wrapperBalanceAfter);
        console2.log(lpWrapper.earned(user));

        vm.stopPrank();
    }

    function testPositionsModified() external {
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(poolAB, IPulseStrategyModule.StrategyType.LazySyncing, contracts);

        uint256 tokenId = contracts.core.managedPositionAt(lpWrapper.positionId()).ammPositionIds[0];

        uint256 g_ = gasleft();
        IVeloAmmModule.Position memory position = contracts.ammModule.getPosition(tokenId);

        console2.log("Modified call usage:", g_ - gasleft());

        console2.log(position.tokenId);
        console2.log(position.liquidity);
    }

    function testLpWrappers() external {
        address user = vm.createWallet("user").addr;

        ILpWrapper[] memory lpWrapper = new ILpWrapper[](5);
        (lpWrapper[0],) =
            deployLpWrapper(poolAB, IPulseStrategyModule.StrategyType.LazySyncing, contracts);
        (lpWrapper[1],) =
            deployLpWrapper(poolAB, IPulseStrategyModule.StrategyType.LazyAscending, contracts);
        (lpWrapper[2],) =
            deployLpWrapper(poolAB, IPulseStrategyModule.StrategyType.LazyDescending, contracts);
        (lpWrapper[3],) =
            deployLpWrapper(poolAB, IPulseStrategyModule.StrategyType.Original, contracts);
        (lpWrapper[4],) =
            deployLpWrapper(poolAB, IPulseStrategyModule.StrategyType.Tamper, contracts);

        uint256 lpAmount = 1 ether;
        uint256 amount0Initial = 10 ether;
        uint256 amount1Initial = 10 ether;
        uint256 rewardBalance = IERC20(TERMINAL).balanceOf(user);
        uint256 rewardBalanceTreasury =
            IERC20(TERMINAL).balanceOf(Constants.TERMINAL_MELLOW_TREASURY);
        deal(tokenA, user, amount0Initial);
        deal(tokenB, user, amount1Initial);

        vm.startPrank(user);
        for (uint256 i = 0; i < lpWrapper.length; i++) {
            IERC20(tokenA).safeIncreaseAllowance(address(lpWrapper[i]), type(uint256).max);
            IERC20(tokenB).safeIncreaseAllowance(address(lpWrapper[i]), type(uint256).max);

            (,, uint256 actualLpAmount) = lpWrapper[i].mint(
                ILpWrapper.MintParams({
                    lpAmount: lpAmount,
                    amount0Max: type(uint256).max,
                    amount1Max: type(uint256).max,
                    recipient: user,
                    deadline: block.timestamp
                })
            );
            assertApproxEqAbs(actualLpAmount, lpAmount, 1);
        }
        vm.stopPrank();

        addRewardToGauge(1 ether, IGauge(poolAB.gauge()));
        skip(1 days);

        vm.startPrank(user);
        for (uint256 i = 0; i < lpWrapper.length; i++) {
            lpWrapper[i].getRewards(user);
            assertTrue(rewardBalance < IERC20(TERMINAL).balanceOf(user));
            rewardBalance = IERC20(TERMINAL).balanceOf(user);
            /// @dev check that user and treasury received some rewards
            assertTrue(
                rewardBalanceTreasury
                    < IERC20(TERMINAL).balanceOf(Constants.TERMINAL_MELLOW_TREASURY)
            );
            rewardBalanceTreasury = IERC20(TERMINAL).balanceOf(Constants.TERMINAL_MELLOW_TREASURY);
        }
        vm.stopPrank();

        vm.startPrank(user);
        for (uint256 i = 0; i < lpWrapper.length; i++) {
            uint256 actualLpAmount = lpWrapper[i].balanceOf(user);
            assertApproxEqAbs(actualLpAmount, lpAmount, 1);

            lpWrapper[i].withdraw(lpAmount, 0, 0, user, block.timestamp);

            /// @dev check that user and treasury didn't receive rewards
            assertTrue(rewardBalance == IERC20(TERMINAL).balanceOf(user));
            assertTrue(
                rewardBalanceTreasury
                    == IERC20(TERMINAL).balanceOf(Constants.TERMINAL_MELLOW_TREASURY)
            );
        }
        vm.stopPrank();

        assertApproxEqAbs(IERC20(tokenA).balanceOf(user), amount0Initial, lpWrapper.length * 2);
        assertApproxEqAbs(IERC20(tokenB).balanceOf(user), amount1Initial, lpWrapper.length * 2);
    }

    function addRewardToGauge(uint256 amount, IGauge gauge) public {
        address voter = address(gauge.voter());
        deal(TERMINAL, voter, amount);
        vm.startPrank(voter);
        IERC20(TERMINAL).safeIncreaseAllowance(address(gauge), amount);
        IGauge(gauge).notifyRewardAmount(amount);
        vm.stopPrank();
    }
}
