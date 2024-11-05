// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IVeloFarm.sol";

abstract contract VeloFarm is IVeloFarm, ERC20Upgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 public constant Q96 = 2 ** 96;

    /// @inheritdoc IVeloFarm
    address public immutable rewardDistributor;

    /// @inheritdoc IVeloFarm
    address public rewardToken;
    /// @inheritdoc IVeloFarm
    uint256 public initializationTimestamp;
    /// @inheritdoc IVeloFarm
    mapping(address account => uint256) public lastRewardsUpdate;
    /// @inheritdoc IVeloFarm
    mapping(address account => uint256) public claimable;
    /// @inheritdoc IVeloFarm
    mapping(address account => TimestampValue) public weightedBalance;
    /// @inheritdoc IVeloFarm
    TimestampValue[] public rewardRate;
    /// @inheritdoc IVeloFarm
    mapping(uint256 timestamp => uint256) public timestampToRewardRateIndex;

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
        rewardRate.push(TimestampValue(initializationTimestamp, 0));
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

        _updateBalances(address(0));
        uint256 length = rewardRate.length;
        TimestampValue memory prevRate = rewardRate[length - 1];
        uint256 timestamp = block.timestamp;
        if (timestamp == prevRate.timestamp) {
            if (amount > 0) {
                revert InvalidState();
            }
            return;
        }

        uint256 incrementX96 =
            amount == 0 ? 0 : amount.mulDiv(Q96, weightedBalance[address(0)].value);
        rewardRate.push(TimestampValue(timestamp, prevRate.value + incrementX96));
        timestampToRewardRateIndex[timestamp] = length;
    }

    /// @inheritdoc IVeloFarm
    function getRewards(address recipient) external nonReentrant returns (uint256 amount) {
        return _getRewards(recipient);
    }

    /// ---------------------- EXTERNAL VIEW FUNCTIONS ----------------------

    /// @inheritdoc IVeloFarm
    function earned(address account) external view returns (uint256 earned_) {
        earned_ = claimable[account];
        uint256 prevTimestamp = weightedBalance[account].timestamp;
        if (prevTimestamp == 0) {
            prevTimestamp = initializationTimestamp;
        }

        uint256 timestamp = block.timestamp;
        if (timestamp == prevTimestamp) {
            return earned_;
        }

        uint256 timespan = timestamp - prevTimestamp;
        uint256 balance = balanceOf(account);
        if (balance == 0) {
            return earned_;
        }

        uint256 balanceIncrement = balance * timespan;
        uint256 length = rewardRate.length;
        if (length < 2) {
            return earned_;
        }

        uint256 prevValue = rewardRate[timestampToRewardRateIndex[prevTimestamp]].value;
        uint256 lastValue = rewardRate[length - 1].value;
        if (prevValue < lastValue) {
            earned_ += balanceIncrement.mulDiv(lastValue - prevValue, Q96);
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
        uint256 prevTimestamp = weightedBalance[account].timestamp;
        if (prevTimestamp == 0) {
            prevTimestamp = initializationTimestamp;
        }

        uint256 timestamp = block.timestamp;
        if (timestamp == prevTimestamp) {
            return;
        }

        uint256 timespan = timestamp - prevTimestamp;
        if (account == address(0)) {
            weightedBalance[account] = TimestampValue(timestamp, totalSupply() * timespan);
            return;
        }

        uint256 newBalance = balanceOf(account) * timespan;
        weightedBalance[account] = TimestampValue(timestamp, newBalance);
        uint256 lastRewardsUpdate_ = lastRewardsUpdate[account];
        lastRewardsUpdate[account] = timestamp;
        if (newBalance == 0) {
            return;
        }

        uint256 length = rewardRate.length;
        if (length < 2) {
            return;
        }

        uint256 prevValue = rewardRate[timestampToRewardRateIndex[lastRewardsUpdate_]].value;
        uint256 lastValue = rewardRate[length - 1].value;
        if (prevValue < lastValue) {
            claimable[account] += newBalance.mulDiv(lastValue - prevValue, Q96);
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
