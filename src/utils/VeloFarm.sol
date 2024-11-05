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
    uint256 public lastWeightedTotalSupply;
    mapping(address account => uint256) public lastRewardsUpdate;
    mapping(address account => uint256) public claimable;
    mapping(uint256 timestamp => uint256) public timestampToRewardRatesIndex;
    RewardRates[] public rewardRates;

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
        initializationTimestamp = block.timestamp;
        rewardRates.push(RewardRates(initializationTimestamp, 0));
    }

    /// ---------------------- EXTERNAL MUTATING FUNCTIONS ----------------------

    function collectRewards() external nonReentrant {
        _collectRewards();
    }

    function distribute(uint256 amount) external {
        if (_msgSender() != rewardDistributor) {
            revert InvalidDistributor();
        }

        _updateBalances(address(0));
        uint256 length = rewardRates.length;
        RewardRates memory prevRate = rewardRates[length - 1];
        uint256 timestamp = block.timestamp;
        if (timestamp == prevRate.timestamp) {
            if (amount > 0) {
                revert InvalidState();
            }
            return;
        }

        uint256 incrementX96 = amount == 0 ? 0 : amount.mulDiv(Q96, lastWeightedTotalSupply);
        rewardRates.push(RewardRates(timestamp, prevRate.rewardRateX96 + incrementX96));
        timestampToRewardRatesIndex[timestamp] = length;
    }

    function getRewards(address recipient) external nonReentrant returns (uint256 amount) {
        return _getRewards(recipient);
    }

    /// ---------------------- EXTERNAL VIEW FUNCTIONS ----------------------

    function earned(address account) external view returns (uint256 earned_) {
        (,, earned_) = calculateIncrements(account);
        return claimable[account] + earned_;
    }

    function calculateIncrements(address account)
        public
        view
        returns (bool isDublicate, uint256 balanceIncrement, uint256 rewardsEarned)
    {
        uint256 prevTimestamp = lastRewardsUpdate[account];
        if (prevTimestamp == 0) {
            prevTimestamp = initializationTimestamp;
        }

        uint256 timestamp = block.timestamp;
        if (timestamp == prevTimestamp) {
            return (true, 0, 0);
        }

        uint256 timespan = timestamp - prevTimestamp;
        if (account == address(0)) {
            return (false, totalSupply() * timespan, 0);
        }

        balanceIncrement = balanceOf(account) * timespan;
        if (balanceIncrement == 0) {
            return (false, balanceIncrement, 0);
        }

        uint256 length = rewardRates.length;
        if (length < 2) {
            return (false, balanceIncrement, 0);
        }

        uint256 prevValue = rewardRates[timestampToRewardRatesIndex[prevTimestamp]].rewardRateX96;
        uint256 lastValue = rewardRates[length - 1].rewardRateX96;
        if (prevValue < lastValue) {
            rewardsEarned = balanceIncrement.mulDiv(lastValue - prevValue, Q96);
        }
    }

    /// ---------------------- INTERNAL MUTABLE FUNCTIONS ----------------------

    function _collectRewards() internal virtual {}

    function _getRewards(address recipient) internal returns (uint256 amount) {
        address sender = _msgSender();
        _collectRewards();
        _updateBalances(sender);
        amount = claimable[sender];
        if (amount != 0) {
            IERC20(rewardToken).safeTransfer(recipient, amount);
            delete claimable[sender];
        }
    }

    function _updateBalances(address account) private {
        (bool isDublicate, uint256 balanceIncrement, uint256 rewardIncrement) =
            calculateIncrements(account);
        if (isDublicate) {
            return;
        }
        lastRewardsUpdate[account] = block.timestamp;
        if (account == address(0)) {
            lastWeightedTotalSupply = balanceIncrement;
        } else {
            claimable[account] += rewardIncrement;
        }
    }

    function _update(address from, address to, uint256 amount) internal virtual override {
        _collectRewards();
        if (from != address(0)) {
            _updateBalances(from);
        }
        if (to != address(0)) {
            _updateBalances(to);
        }
        super._update(from, to, amount);
    }
}
