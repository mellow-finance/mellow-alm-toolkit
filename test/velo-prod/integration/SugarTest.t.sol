// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Integration is Fixture {
    using SafeERC20 for IERC20;

    ICLGauge public gauge = ICLGauge(pool.gauge());

    function addRewardToGauge(uint256 amount) public {
        address voter = address(gauge.voter());
        address rewardToken = gauge.rewardToken();
        deal(rewardToken, voter, amount);
        vm.startPrank(voter);
        IERC20(rewardToken).safeIncreaseAllowance(address(gauge), amount);
        ICLGauge(gauge).notifyRewardAmount(amount);
        vm.stopPrank();
    }

    function logLpInfo(address user) public {
        VeloSugarHelper sugar = new VeloSugarHelper(address(veloFactory));
        VeloSugarHelper.Lp[] memory lps = sugar.full(user);
        for (uint256 i = 0; i < lps.length; i++) {
            VeloSugarHelper.Lp memory lp = lps[i];
            string memory logS = string(
                abi.encodePacked(
                    "amount0: ",
                    vm.toString(lp.amount0),
                    " amount1: ",
                    vm.toString(lp.amount1),
                    " lpAmount: ",
                    vm.toString(lp.lpAmount),
                    " stakedLpAmount: ",
                    vm.toString(lp.stakedLpAmount),
                    " almFarm: ",
                    vm.toString(lp.almFarm)
                )
            );
            logS = string(
                abi.encodePacked(
                    logS,
                    " almVault: ",
                    vm.toString(lp.almVault),
                    " almFeeD9: ",
                    vm.toString(lp.almFeeD9),
                    " rewardToken: ",
                    vm.toString(lp.rewardToken),
                    " rewards: ",
                    vm.toString(lp.rewards),
                    " nft: ",
                    vm.toString(lp.nft),
                    " pool: ",
                    vm.toString(lp.pool),
                    " token0: ",
                    vm.toString(lp.token0)
                )
            );
            logS = string(
                abi.encodePacked(
                    logS,
                    " token1: ",
                    vm.toString(lp.token1),
                    " reserve0: ",
                    vm.toString(lp.reserve0),
                    " reserve1: ",
                    vm.toString(lp.reserve1),
                    " tickSpacing: ",
                    vm.toString(lp.tickSpacing),
                    " tick: "
                )
            );
            logS = string(
                abi.encodePacked(
                    logS,
                    vm.toString(lp.tick),
                    " price: ",
                    vm.toString(lp.price),
                    " gauge: ",
                    vm.toString(lp.gauge),
                    " initialized: ",
                    vm.toString(lp.initialized)
                )
            );
            console2.log(logS);
        }
    }

    function testSynthetixFarm() external {
        vm.startPrank(Constants.DEPOSITOR);
        deal(Constants.OP, Constants.DEPOSITOR, 1e6 * 1e6);
        deal(Constants.WETH, Constants.DEPOSITOR, 500 ether);
        IERC20(Constants.OP).safeApprove(address(lpWrapper), type(uint256).max);
        IERC20(Constants.WETH).safeApprove(address(lpWrapper), type(uint256).max);
        {
            (,, uint256 lpAmount) =
                lpWrapper.deposit(500 ether, 1e6, 1e3, Constants.DEPOSITOR, type(uint256).max);
            logLpInfo(Constants.DEPOSITOR);

            require(lpAmount > 0, "Invalid lp amount");
            console2.log("Actual lp amount:", lpAmount);
            lpWrapper.approve(address(stakingRewards), type(uint256).max);
            stakingRewards.stake(lpWrapper.balanceOf(Constants.DEPOSITOR));
        }
        vm.stopPrank();

        addRewardToGauge(10 ether);

        skip(7 days);

        {
            uint256 treasuryBalanceBefore =
                IERC20(Constants.VELO).balanceOf(Constants.PROTOCOL_TREASURY);

            uint256 depositorBalanceBefore = IERC20(Constants.VELO).balanceOf(Constants.DEPOSITOR);

            vm.prank(Constants.OWNER);
            lpWrapper.emptyRebalance();

            uint256 addedRewards = IERC20(Constants.VELO).balanceOf(address(stakingRewards));

            vm.prank(Constants.FARM_OPERATOR);
            stakingRewards.notifyRewardAmount(addedRewards);

            skip(7 days);

            vm.stopPrank();
            vm.startPrank(Constants.DEPOSITOR);

            logLpInfo(Constants.DEPOSITOR);
            stakingRewards.getReward();

            uint256 depositorBalanceAfter = IERC20(Constants.VELO).balanceOf(Constants.DEPOSITOR);

            uint256 treasuryBalanceAfter =
                IERC20(Constants.VELO).balanceOf(Constants.PROTOCOL_TREASURY);

            uint256 userRewards = depositorBalanceAfter - depositorBalanceBefore;
            uint256 protocolRewards = treasuryBalanceAfter - treasuryBalanceBefore;

            uint256 totalRewards = userRewards + protocolRewards;
            console2.log(totalRewards, protocolRewards, userRewards);
            // assertTrue(totalRewards > 10 ether - 7 days); // max delta in weis = number of seconds in 1 day
            // assertApproxEqAbs(protocolRewards, 1 ether, 1 wei);
            // assertApproxEqAbs(userRewards, 9 ether, 7 days);

            vm.stopPrank();
            // logLpInfo(Constants.DEPOSITOR);
        }
    }
}
