// SPDX-License-Identifier: BUSL-1.1
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

    function testSynthetixFarm() external {
        vm.startPrank(Constants.DEPOSITOR);
        deal(Constants.OP, Constants.DEPOSITOR, 1e6 * 1e6);
        deal(Constants.WETH, Constants.DEPOSITOR, 500 ether);
        IERC20(Constants.OP).safeApprove(address(lpWrapper), type(uint256).max);
        IERC20(Constants.WETH).safeApprove(address(lpWrapper), type(uint256).max);
        {
            (,, uint256 lpAmount) =
                lpWrapper.deposit(500 ether, 1e6, 1e3, Constants.DEPOSITOR, type(uint256).max);
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

            uint256 rewards = IERC20(Constants.VELO).balanceOf(address(stakingRewards));

            vm.prank(Constants.FARM_OPERATOR);
            stakingRewards.notifyRewardAmount(rewards);

            skip(7 days);

            vm.startPrank(Constants.DEPOSITOR);

            stakingRewards.getReward();

            uint256 depositorBalanceAfter = IERC20(Constants.VELO).balanceOf(Constants.DEPOSITOR);

            uint256 treasuryBalanceAfter =
                IERC20(Constants.VELO).balanceOf(Constants.PROTOCOL_TREASURY);

            uint256 userRewards = depositorBalanceAfter - depositorBalanceBefore;
            uint256 protocolRewards = treasuryBalanceAfter - treasuryBalanceBefore;

            uint256 totalRewards = userRewards + protocolRewards;
            console2.log(userRewards, protocolRewards, totalRewards);
            assertApproxEqAbs((protocolRewards * 1e9) / totalRewards, 1e8, 1e6);
            vm.stopPrank();
        }
    }
}
