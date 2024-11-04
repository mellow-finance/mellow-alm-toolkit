// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../scripts/deploy/Constants.sol";

contract MockVeloFarm is VeloFarm {
    constructor(address rewardToken_, string memory name_, string memory symbol_)
        initializer
        VeloFarm(address(this))
    {
        __VeloFarm_init(rewardToken_, name_, symbol_);
        collectRewards();
    }

    uint256 public newRewards = 0;
    uint256 public lastDistributionTimestamp;

    function setRewardsForDistribution(uint256 amount) external {
        newRewards = amount;
        lastDistributionTimestamp = block.timestamp;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function collectRewards() public override {
        uint256 rewards = 0;
        if (lastDistributionTimestamp < block.timestamp) {
            rewards = newRewards;
        }
        VeloFarm(address(this)).distribute(rewards);
    }
}

contract IntegrationTest is Test {
    using SafeERC20 for IERC20;

    address public constant rewardToken = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;

    function testVeloFarm() external {
        MockVeloFarm veloFarm = new MockVeloFarm(rewardToken, "VeloFarm", "VF");

        address user1 = vm.createWallet("user-1").addr;
        address user2 = vm.createWallet("user-2").addr;

        skip(1 hours);

        deal(rewardToken, address(veloFarm), 10000 ether);

        veloFarm.setRewardsForDistribution(10 gwei);

        veloFarm.mint(user1, 100 ether);
        veloFarm.mint(user2, 100 ether);
        skip(1 hours);

        vm.prank(user1);
        veloFarm.transfer(user1, 100 ether);

        console2.log(veloFarm.earned(user1), veloFarm.earned(user2));

        vm.prank(user1);
        veloFarm.getRewards(user1);

        console2.log(veloFarm.earned(user1), veloFarm.earned(user2));

        vm.prank(user2);
        veloFarm.getRewards(user2);
    }
}
