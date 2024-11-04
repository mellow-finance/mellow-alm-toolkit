// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../scripts/deploy/Constants.sol";

contract MockVeloFarm is VeloFarm {
    constructor(address rewardToken_, string memory name_, string memory symbol_)
        initializer
        VeloFarm(address(this))
    {
        __VeloFarm_init(rewardToken_, name_, symbol_);
    }

    uint256 public newRewards = 0;
    uint256 public lastDistributionTimestamp;

    function setRewardsForDistribution(uint256 amount) external {
        newRewards = amount;
        delete lastDistributionTimestamp;
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
            lastDistributionTimestamp = block.timestamp;
        }
        VeloFarm(address(this)).distribute(rewards);
    }

    function doAndDone(address account) external returns (uint256) {
        collectRewards();
        uint256 amount = VeloFarm(address(this)).earned(account);
        revert(
            string(abi.encodePacked(Strings.toHexString(account), ": ", Strings.toString(amount)))
        );
    }

    function logEarned(address account) external {
        try MockVeloFarm(address(this)).doAndDone(account) returns (uint256 /* earned */ ) {}
        catch (bytes memory reason) {
            console2.log(string(reason));
        }
    }
}

contract IntegrationTest is Test {
    using SafeERC20 for IERC20;

    address public constant rewardToken = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;

    function testVeloFarm() external {
        MockVeloFarm veloFarm = new MockVeloFarm(rewardToken, "VeloFarm", "VF");
        veloFarm.collectRewards();
        address user1 = vm.createWallet("user-1").addr;
        address user2 = vm.createWallet("user-2").addr;

        uint256 skip_ = 30 days;

        skip(skip_);

        deal(rewardToken, address(veloFarm), 10000 ether);
        veloFarm.mint(address(veloFarm), 1 wei);

        veloFarm.setRewardsForDistribution(10 gwei);

        veloFarm.mint(user1, 1000 ether);
        veloFarm.mint(user2, 100 ether);
        console2.log("earned 0:", veloFarm.earned(user1), veloFarm.earned(user2));

        skip(skip_);
        console2.log("earned 1:", veloFarm.earned(user1), veloFarm.earned(user2));
        veloFarm.collectRewards();
        console2.log("earned 2:", veloFarm.earned(user1), veloFarm.earned(user2));

        vm.prank(user1);
        veloFarm.transfer(user2, 100 ether);
        console2.log("earned 3:", veloFarm.earned(user1), veloFarm.earned(user2));

        vm.prank(user2);
        veloFarm.transfer(user1, 100 ether);
        console2.log("earned 4:", veloFarm.earned(user1), veloFarm.earned(user2));

        skip(skip_);
        console2.log("earned 5:", veloFarm.earned(user1), veloFarm.earned(user2));
        veloFarm.logEarned(user1);
        veloFarm.logEarned(user2);

        veloFarm.collectRewards();
        console2.log("earned 6:", veloFarm.earned(user1), veloFarm.earned(user2));

        vm.prank(user1);
        veloFarm.getRewards(user1);
        console2.log("earned 7:", veloFarm.earned(user1), veloFarm.earned(user2));

        vm.prank(user2);
        veloFarm.getRewards(user2);
        console2.log("earned 8:", veloFarm.earned(user1), veloFarm.earned(user2));

        skip(skip_);

        vm.prank(user1);
        veloFarm.getRewards(user1);
        console2.log("earned 9:", veloFarm.earned(user1), veloFarm.earned(user2));

        vm.prank(user2);
        veloFarm.getRewards(user2);
        console2.log("earned 10:", veloFarm.earned(user1), veloFarm.earned(user2));

        veloFarm.burn(user1, 900 ether);

        skip(skip_);
        veloFarm.collectRewards();
        console2.log("earned 11:", veloFarm.earned(user1), veloFarm.earned(user2));

        vm.prank(user1);
        veloFarm.getRewards(user1);
        console2.log("earned 12:", veloFarm.earned(user1), veloFarm.earned(user2));

        vm.prank(user2);
        veloFarm.getRewards(user2);
        console2.log("earned 13:", veloFarm.earned(user1), veloFarm.earned(user2));

        skip(skip_);
        console2.log("earned 14:", veloFarm.earned(user1), veloFarm.earned(user2));

        veloFarm.setRewardsForDistribution(0);

        console2.log("earned 15:", veloFarm.earned(user1), veloFarm.earned(user2));
        veloFarm.logEarned(user1);
        veloFarm.logEarned(user2);

        skip(skip_);

        console2.log("earned 16:", veloFarm.earned(user1), veloFarm.earned(user2));
        veloFarm.logEarned(user1);
        veloFarm.logEarned(user2);

        veloFarm.setRewardsForDistribution(100 ether);
        veloFarm.collectRewards();
        skip(skip_);

        console2.log("earned 17:", veloFarm.earned(user1), veloFarm.earned(user2));
        veloFarm.logEarned(user1);
        veloFarm.logEarned(user2);

        vm.prank(user1);
        veloFarm.getRewards(user1);
        console2.log("earned 18:", veloFarm.earned(user1), veloFarm.earned(user2));

        vm.prank(user2);
        veloFarm.getRewards(user2);
        console2.log("earned 19:", veloFarm.earned(user1), veloFarm.earned(user2));

        skip(skip_);
        veloFarm.collectRewards();
        console2.log("earned 20:", veloFarm.earned(user1), veloFarm.earned(user2));
    }
}
