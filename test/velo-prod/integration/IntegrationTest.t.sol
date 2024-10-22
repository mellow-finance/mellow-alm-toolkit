// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Integration is Fixture {
    using SafeERC20 for IERC20;

    // parameters:
    int24[1] public fees = [int24(200)];

    function addRewards(ICLPool pool, uint256 amount) public {
        ICLGauge gauge = ICLGauge(pool.gauge());
        address voter = address(gauge.voter());
        address rewardToken = gauge.rewardToken();
        deal(rewardToken, voter, amount);
        vm.startPrank(voter);
        IERC20(rewardToken).safeIncreaseAllowance(address(gauge), amount);
        ICLGauge(gauge).notifyRewardAmount(amount);
        vm.stopPrank();
    }

    function testMultiplePools() external {
        IVeloDeployFactory.PoolAddresses[]
            memory addresses = new IVeloDeployFactory.PoolAddresses[](
                fees.length
            );

        uint256 totalEarned = 0;
        uint256 totalFees = 0;

        for (uint256 i = 0; i < fees.length; i++) {
            ICLPool pool = ICLPool(
                factory.getPool(Constants.WETH, Constants.OP, fees[i])
            );
            addresses[i] = createStrategy(pool);
            vm.prank(Constants.OWNER);
            veloFactory.removeAddressesForPool(address(pool));
            addresses[i] = createStrategy(pool);
            vm.startPrank(Constants.DEPOSITOR);
            deal(pool.token0(), Constants.DEPOSITOR, 1 ether);
            deal(pool.token1(), Constants.DEPOSITOR, 1 ether);
            IERC20(pool.token0()).approve(addresses[i].lpWrapper, 1 ether);
            IERC20(pool.token1()).approve(addresses[i].lpWrapper, 1 ether);
            ILpWrapper(addresses[i].lpWrapper).deposit(
                1 ether,
                1 ether,
                0 ether,
                Constants.DEPOSITOR,
                type(uint256).max
            );

            uint256 balance = IERC20(addresses[i].lpWrapper).balanceOf(
                Constants.DEPOSITOR
            );

            IERC20(addresses[i].lpWrapper).approve(
                addresses[i].synthetixFarm,
                balance
            );
            StakingRewards(addresses[i].synthetixFarm).stake(balance);
            assertEq(
                IERC20(addresses[i].synthetixFarm).balanceOf(
                    Constants.DEPOSITOR
                ),
                balance
            );
            vm.stopPrank();

            addRewards(pool, 10 ether);
            skip(7 days);

            vm.prank(Constants.ADMIN);
            ILpWrapper(addresses[i].lpWrapper).emptyRebalance();

            uint256 addedRewards = IERC20(Constants.VELO).balanceOf(
                addresses[i].synthetixFarm
            );

            vm.prank(Constants.FARM_OPERATOR);
            StakingRewards(addresses[i].synthetixFarm).notifyRewardAmount(
                addedRewards
            );

            skip(7 days);

            totalEarned += StakingRewards(addresses[i].synthetixFarm).earned(
                Constants.DEPOSITOR
            );
            totalFees = IERC20(Constants.VELO).balanceOf(
                Constants.PROTOCOL_TREASURY
            );

            uint256 currentRatio = (1e9 * totalFees) /
                (totalFees + totalEarned);
            uint256 expectedRatio = 1e8;
            assertApproxEqAbs(currentRatio, expectedRatio, 1);
        }
    }

    function testMultipleUsersMultiplePools() external {
        IVeloDeployFactory.PoolAddresses[]
            memory addresses = new IVeloDeployFactory.PoolAddresses[](
                fees.length
            );

        uint256 totalEarned = 0;
        uint256 totalFees = 0;

        for (uint256 i = 0; i < fees.length; i++) {
            address depositor = address(
                bytes20(
                    abi.encodePacked(
                        keccak256("Constants.DEPOSITOR"),
                        vm.toString(i)
                    )
                )
            );
            ICLPool pool = ICLPool(
                factory.getPool(Constants.WETH, Constants.OP, fees[i])
            );
            addresses[i] = createStrategy(pool);
            vm.prank(Constants.OWNER);
            veloFactory.removeAddressesForPool(address(pool));
            addresses[i] = createStrategy(pool);

            vm.startPrank(depositor);
            deal(pool.token0(), depositor, 1 ether);
            deal(pool.token1(), depositor, 1 ether);
            IERC20(pool.token0()).approve(addresses[i].lpWrapper, 1 ether);
            IERC20(pool.token1()).approve(addresses[i].lpWrapper, 1 ether);
            ILpWrapper(addresses[i].lpWrapper).deposit(
                1 ether,
                1 ether,
                0 ether,
                depositor,
                type(uint256).max
            );

            uint256 balance = IERC20(addresses[i].lpWrapper).balanceOf(
                depositor
            );

            IERC20(addresses[i].lpWrapper).approve(
                addresses[i].synthetixFarm,
                balance
            );
            StakingRewards(addresses[i].synthetixFarm).stake(balance);
            assertEq(
                IERC20(addresses[i].synthetixFarm).balanceOf(depositor),
                balance
            );
            vm.stopPrank();

            addRewards(pool, 10 ether);
            skip(7 days);

            vm.startPrank(Constants.FARM_OPERATOR);
            ILpWrapper(addresses[i].lpWrapper).emptyRebalance();
            uint256 addedRewards = IERC20(Constants.VELO).balanceOf(
                addresses[i].synthetixFarm
            );
            StakingRewards(addresses[i].synthetixFarm).notifyRewardAmount(
                addedRewards
            );
            vm.stopPrank();

            skip(7 days);

            totalEarned += StakingRewards(addresses[i].synthetixFarm).earned(
                depositor
            );
            totalFees = IERC20(Constants.VELO).balanceOf(
                Constants.PROTOCOL_TREASURY
            );

            uint256 currentRatio = (1e9 * totalFees) /
                (totalFees + totalEarned);
            uint256 expectedRatio = 1e8;
            assertApproxEqAbs(currentRatio, expectedRatio, 1);
        }
    }
}
