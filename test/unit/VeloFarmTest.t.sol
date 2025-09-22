// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../../scripts/deploy/velo/Constants.sol";

contract IntegrationTest is Test {
    using SafeERC20 for IERC20;

    address public constant rewardToken = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;

    uint256 seed_ = 123;

    function rand() internal returns (uint256) {
        seed_ = uint256(keccak256(abi.encodePacked(seed_)));
        return seed_;
    }

    function testVeloFarm() external {
        VeloFarmMock veloFarm = new VeloFarmMock(rewardToken, "VeloFarmMock", "VFM", address(0));
        address user = address(bytes20(keccak256("user-1")));
        vm.startPrank(user);
        deal(rewardToken, user, 1000 ether);
        IERC20(rewardToken).approve(address(veloFarm), type(uint256).max);
        vm.stopPrank();
        veloFarm.collectRewards();

        veloFarm.mint(user, 1 ether);

        seed_ = 15;
        uint256 iterations = 100;

        uint256 totalClaimed = 0;

        for (uint256 i = 0; i < iterations; i++) {
            uint256 index = rand() % 11;
            if (index == 0) {
                veloFarm.setRewardsForDistribution(10 gwei);
            } else if (index == 1) {
                veloFarm.setRewardsForDistribution(0 gwei);
            } else if (index == 2) {
                veloFarm.collectRewards();
            } else if (index == 3) {
                vm.prank(user);
                totalClaimed += veloFarm.getRewards(user);
            } else if (index < 10) {
                skip(1 hours);
            } else if (index == 10) {
                skip(10 days);
            }
            console2.log("       earned:", veloFarm.earned(user));
            veloFarm.logEarned(user);
        }
        vm.prank(user);
        totalClaimed += veloFarm.getRewards(user);

        console2.log(
            veloFarm.totalDistributed(),
            totalClaimed,
            IERC20(rewardToken).balanceOf(address(veloFarm)),
            veloFarm.totalDistributed() - totalClaimed
        );
    }
}
