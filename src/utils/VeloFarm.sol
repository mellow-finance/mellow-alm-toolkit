// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IVeloFarm.sol";

abstract contract VeloFarm is IVeloFarm, ERC20Upgradeable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 public constant D18 = 1e18;

    address public immutable rewardSource;

    /// @inheritdoc IVeloFarm
    address public rewardToken;
    /// @inheritdoc IVeloFarm
    uint256 public initializationTimestamp;
    /// @inheritdoc IVeloFarm
    mapping(address account => uint256) public lastRewardsUpdate;
    /// @inheritdoc IVeloFarm
    mapping(address => uint256) public claimable;

    mapping(address account => CumulativeValue[]) private _cumulativeBalance;
    mapping(address account => mapping(uint256 timestamp => uint256)) private
        _cumulativeBalanceTimestampToIndex;
    CumulativeValue[] private _cumulativeRewardRate;
    mapping(uint256 timestamp => uint256) private _cumulativeRewardRateTimestampToIndex;

    constructor(address rewardSource_) {
        rewardSource = rewardSource_;
    }

    function __VeloFarm_init(address rewardToken_, string memory name_, string memory symbol_)
        internal
        onlyInitializing
    {
        __ERC20_init(name_, symbol_);
        __Context_init();
        rewardToken = rewardToken_;
        initializationTimestamp = block.timestamp;
    }

    function collectRewards() public virtual {}

    function getAccountCumulativeBalance(
        address account,
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) public view returns (uint256) {
        CumulativeValue[] storage balances = _cumulativeBalance[account];
        if (balances.length == 0) {
            return 0;
        }
        mapping(uint256 => uint256) storage timestampToIndex =
            _cumulativeBalanceTimestampToIndex[account];
        CumulativeValue memory from = balances[timestampToIndex[fromTimestamp]];
        CumulativeValue memory to = balances[timestampToIndex[toTimestamp]];
        return to.value - from.value;
    }

    function getCumulativeRateD18(uint256 fromTimestamp, uint256 toTimestamp)
        public
        view
        returns (uint256)
    {
        CumulativeValue[] storage rewardRate = _cumulativeRewardRate;
        CumulativeValue memory from =
            rewardRate[_cumulativeRewardRateTimestampToIndex[fromTimestamp]];
        CumulativeValue memory to = rewardRate[_cumulativeRewardRateTimestampToIndex[toTimestamp]];
        return to.value - from.value;
    }

    function distribute(uint256 amount) external {
        require(_msgSender() == rewardSource, "LpWrapper: Forbidden");
        _logBalances(address(0));
        CumulativeValue[] storage rewardRate = _cumulativeRewardRate;
        uint256 n = rewardRate.length;
        CumulativeValue memory last =
            n == 0 ? CumulativeValue(initializationTimestamp, 0) : rewardRate[n - 1];
        uint256 timestamp = block.timestamp;
        if (timestamp == last.timestamp) {
            return;
        }
        uint256 cumulativeTotalSupply =
            getAccountCumulativeBalance(address(0), last.timestamp, timestamp);
        uint256 cumulativeRewardRateD18 = last.value
            + amount.mulDiv(
                D18,
                cumulativeTotalSupply + 1 // to avoid division by zero (?)
            );
        rewardRate.push(CumulativeValue(timestamp, cumulativeRewardRateD18));
        _cumulativeRewardRateTimestampToIndex[timestamp] = n;
    }

    function _logBalances(address account) private {
        CumulativeValue[] storage balances = _cumulativeBalance[account];
        uint256 n = balances.length;
        uint256 timestamp = block.timestamp;
        CumulativeValue memory last =
            n == 0 ? CumulativeValue(initializationTimestamp, 0) : balances[n - 1];
        if (last.timestamp == timestamp) {
            return;
        }
        uint256 balance = account == address(0) ? totalSupply() : balanceOf(account);
        balances.push(
            CumulativeValue(timestamp, last.value + balance * (timestamp - last.timestamp))
        );
        _cumulativeBalanceTimestampToIndex[account][timestamp] = n;
        if (account == address(0)) {
            return;
        }
        uint256 lastRewardsUpdate_ = lastRewardsUpdate[account];
        lastRewardsUpdate[account] = timestamp;
        uint256 amount = getAccountCumulativeBalance(account, lastRewardsUpdate_, timestamp);
        if (amount == 0) {
            return;
        }
        uint256 cumulativeRateD18 = getCumulativeRateD18(lastRewardsUpdate_, timestamp);
        claimable[account] += amount.mulDiv(cumulativeRateD18, D18);
    }

    function earned(address account) external view returns (uint256) {
        return claimable[account]; // change logic to include rewards that are not yet collected
    }

    /// @inheritdoc IVeloFarm
    function getRewards(address recipient) public returns (uint256 amount) {
        address sender = _msgSender();
        collectRewards();
        _logBalances(sender);
        amount = claimable[sender];
        IERC20(rewardToken).safeTransfer(recipient, amount);
        delete claimable[sender];
    }

    function _update(address from, address to, uint256 amount) internal virtual override {
        collectRewards();
        if (from != address(0)) {
            _logBalances(from);
        }
        if (to != address(0)) {
            _logBalances(to);
        }
        super._update(from, to, amount);
    }
}
