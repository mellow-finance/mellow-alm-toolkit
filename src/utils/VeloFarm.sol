// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IVeloFarm.sol";

abstract contract VeloFarm is IVeloFarm, ERC20Upgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 public constant Q96 = 2 ** 96;

    address public immutable rewardDistributor;
    address public rewardToken;
    uint256 public initializationTimestamp;

    mapping(address account => uint256 timestamp) public lastBalancesUpdate;
    mapping(address account => uint256 amount) public claimable;
    mapping(uint256 timestamp => uint256 index) public timestampToRewardRatesIndex;
    RewardRates[] public rewardRates;
    bool private _isDistributeFunctionCalled;

    /// ---------------------- INITIALIZER FUNCTIONS ----------------------

    constructor(address rewardDistributor_) {
        rewardDistributor = rewardDistributor_;
    }

    function __VeloFarm_init(address rewardToken_, string memory name_, string memory symbol_)
        internal
        onlyInitializing
    {
        __ERC20_init(name_, symbol_);
        __Context_init();
        rewardToken = rewardToken_;
        uint256 timestamp = block.timestamp;
        initializationTimestamp = timestamp;
        rewardRates.push(RewardRates(timestamp, 0));
    }

    /// ---------------------- EXTERNAL MUTATING FUNCTIONS ----------------------

    /// @inheritdoc IVeloFarm
    function collectRewards() external nonReentrant {
        _collectRewards();
    }

    /// @inheritdoc IVeloFarm
    function distribute(uint256 amount) external {
        if (_msgSender() != rewardDistributor) {
            revert InvalidDistributor();
        }

        _isDistributeFunctionCalled = true;
        uint256 timestamp = block.timestamp;
        uint256 length = rewardRates.length;
        RewardRates memory prevRate = rewardRates[length - 1];
        uint256 incrementX96 = amount == 0 ? 0 : amount.mulDiv(Q96, totalSupply());
        uint256 rewardRateX96 = prevRate.rewardRateX96 + incrementX96;
        if (timestamp == prevRate.timestamp) {
            if (amount > 0) {
                rewardRates[length - 1].rewardRateX96 = rewardRateX96;
            }
        } else {
            rewardRates.push(RewardRates(timestamp, rewardRateX96));
            timestampToRewardRatesIndex[timestamp] = length;
        }
    }

    /// @inheritdoc IVeloFarm
    function getRewards(address recipient) external nonReentrant returns (uint256 amount) {
        return _getRewards(recipient);
    }

    /// ---------------------- EXTERNAL VIEW FUNCTIONS ----------------------

    /// @inheritdoc IVeloFarm
    function earned(address account) external view returns (uint256 earned_) {
        return claimable[account] + calculateEarnedRewards(account);
    }

    /// @inheritdoc IVeloFarm
    function calculateEarnedRewards(address account) public view returns (uint256 rewardsEarned) {
        uint256 lastTimestamp = lastBalancesUpdate[account];
        if (lastTimestamp == 0 || lastTimestamp == block.timestamp) {
            return 0;
        }

        uint256 balance = balanceOf(account);
        if (balance == 0) {
            return 0;
        }

        uint256 length = rewardRates.length;
        if (length < 2) {
            return 0;
        }

        uint256 ratioX96 = rewardRates[timestampToRewardRatesIndex[lastTimestamp]].rewardRateX96;
        uint256 latestRatioX96 = rewardRates[length - 1].rewardRateX96;
        if (ratioX96 == latestRatioX96) {
            return 0;
        }
        rewardsEarned = balance.mulDiv(latestRatioX96 - ratioX96, Q96);
    }

    /// ---------------------- INTERNAL MUTABLE FUNCTIONS ----------------------

    function _collectRewards() internal {
        _isDistributeFunctionCalled = false;
        _collectRewardsImplementation();
        if (!_isDistributeFunctionCalled) {
            revert InvalidState();
        }
    }

    function _collectRewardsImplementation() internal virtual {}

    function _getRewards(address recipient) internal returns (uint256 amount) {
        address sender = _msgSender();
        _collectRewards();
        _modifyRewards(sender);
        amount = claimable[sender];
        if (amount != 0) {
            IERC20(rewardToken).safeTransfer(recipient, amount);
            delete claimable[sender];
        }
    }

    function _modifyRewards(address account) private {
        uint256 amount = calculateEarnedRewards(account);
        lastBalancesUpdate[account] = block.timestamp;
        if (amount > 0) {
            claimable[account] += amount;
        }
    }

    function _update(address from, address to, uint256 amount) internal virtual override {
        _collectRewards();
        if (from != address(0)) {
            _modifyRewards(from);
        }
        if (to != address(0)) {
            _modifyRewards(to);
        }
        super._update(from, to, amount);
    }
}
