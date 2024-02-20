// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Integration is Fixture {
    using SafeERC20 for IERC20;

    ICLGauge public gauge = ICLGauge(Constants.GAUGE);

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
        ICore.DepositParams memory depositParams;
        depositParams.tokenIds = new uint256[](1);
        depositParams.tokenIds[0] = mint(
            Constants.USDC,
            Constants.WETH,
            TICK_SPACING,
            pool.tickSpacing() * 8,
            1e9
        );
        depositParams.owner = Constants.OWNER;
        depositParams.strategyParams = abi.encode(
            IPulseStrategyModule.StrategyParams({
                tickNeighborhood: pool.tickSpacing() * 2,
                tickSpacing: pool.tickSpacing(),
                strategyType: IPulseStrategyModule.StrategyType.Original
            })
        );
        depositParams.securityParams = new bytes(0);
        depositParams.slippageD4 = 100;

        vm.startPrank(Constants.OWNER);
        positionManager.approve(address(core), depositParams.tokenIds[0]);
        {
            uint256 nftId = core.deposit(depositParams);
            core.withdraw(nftId, Constants.OWNER);
        }

        positionManager.approve(address(core), depositParams.tokenIds[0]);
        depositParams.owner = address(lpWrapper);
        depositParams.farm = address(Constants.GAUGE);
        depositParams.vault = address(stakingRewards);

        uint256 nftId2 = core.deposit(depositParams);

        lpWrapper.initialize(nftId2, 5e5);
        vm.stopPrank();

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
                500 ether,
                1e6,
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

        addRewardToGauge(10 ether);

        skip(7 days);

        {
            uint256 treasuryBalanceBefore = IERC20(Constants.VELO).balanceOf(
                Constants.PROTOCOL_TREASURY
            );

            uint256 depositorBalanceBefore = IERC20(Constants.VELO).balanceOf(
                Constants.DEPOSITOR
            );

            vm.startPrank(Constants.OWNER);
            lpWrapper.emptyRebalance();
            stakingRewards.notifyRewardAmount(
                IERC20(Constants.VELO).balanceOf(address(stakingRewards))
            );

            skip(1 days);

            vm.stopPrank();
            vm.startPrank(Constants.DEPOSITOR);

            stakingRewards.getReward();

            uint256 depositorBalanceAfter = IERC20(Constants.VELO).balanceOf(
                Constants.DEPOSITOR
            );

            uint256 treasuryBalanceAfter = IERC20(Constants.VELO).balanceOf(
                Constants.PROTOCOL_TREASURY
            );

            uint256 userRewards = depositorBalanceAfter -
                depositorBalanceBefore;
            uint256 protocolRewards = treasuryBalanceAfter -
                treasuryBalanceBefore;

            uint256 totalRewards = userRewards + protocolRewards;
            assertTrue(totalRewards > 10 ether - 1 days); // max delta in weis = number of seconds in 1 day
            assertApproxEqAbs(protocolRewards, 1 ether, 1 wei);
            assertApproxEqAbs(userRewards, 9 ether, 1 days);

            vm.stopPrank();
        }
    }
}
