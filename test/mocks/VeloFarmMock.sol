// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./Mock.sol";
import "src/utils/VeloFarm.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/Vm.sol";

contract VeloFarmMock is VeloFarm, Test, Mock {
    using SafeERC20 for IERC20;

    address public immutable user = address(bytes20(keccak256("user-1")));
    uint256 public totalDistributed = 0;

    constructor(address rewardToken_, string memory name_, string memory symbol_, address core_)
        initializer
        VeloFarm(core_ == address(0) ? address(this) : core_)
    {
        __VeloFarm_init(rewardToken_, name_, symbol_);
    }

    uint256 public newRewards = 0;
    uint256 public lastDistributionTimestamp;

    function setRewardsForDistribution(uint256 amount) external {
        newRewards = amount;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function _collectRewardsImplementation() internal override {
        uint256 rewards = 0;
        if (lastDistributionTimestamp < block.timestamp) {
            rewards = newRewards;
            lastDistributionTimestamp = block.timestamp;
        }
        if (rewards != 0) {
            IERC20(rewardToken).safeTransferFrom(user, address(this), rewards);
            totalDistributed += rewards;
        }
        vm.prank(rewardDistributor);
        VeloFarm(address(this)).distribute(rewards, rewardToken);
    }

    function doAndDone(address account) external returns (uint256) {
        _collectRewards();
        uint256 amount = VeloFarm(address(this)).earned(account);
        revert(string(abi.encodePacked("actual earned: ", Strings.toString(amount), "\n")));
    }

    function logEarned(address account) external {
        try VeloFarmMock(address(this)).doAndDone(account) returns (uint256 /* earned */ ) {}
        catch Error(string memory log_) {
            console2.log(string(log_));
        }
    }
}
