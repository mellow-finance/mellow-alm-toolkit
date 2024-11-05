// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IVeloFarm.sol";

/*
    VeloFarm - Manages the distribution of rewards to token holders in a farming system.
    Tracks cumulative reward rates over time, with functionality for time-weighted balance adjustments
    and reward accumulation.
*/
abstract contract VeloFarm is IVeloFarm, ERC20Upgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 public constant Q96 = 2 ** 96; // Precision factor used in reward calculations

    address public immutable rewardDistributor; // Address authorized to call `distribute`
    address public rewardToken; // Address of the ERC20 token used for rewards
    uint256 public initializationTimestamp; // Timestamp when the contract was initialized
    uint256 public lastWeightedTotalSupply; // Last recorded weighted total supply for the farm

    mapping(address account => uint256 timestamp) public lastBalancesUpdate; // Last update time for each account's balance
    mapping(address account => uint256 amount) public claimable; // Claimable rewards for each account
    mapping(uint256 timestamp => uint256 index) public timestampToRewardRatesIndex; // Maps timestamps to `rewardRates` indexes

    RewardRates[] public rewardRates; // Array of cumulative reward rates
    bool private _isDistributeFunctionCalled; // Flag to verify that `distribute` was called during reward collection

    /// ---------------------- INITIALIZER FUNCTIONS ----------------------

    /**
     * @dev Sets the `rewardDistributor` address. Only this address is authorized to call the `distribute` function.
     * @param rewardDistributor_ Address authorized to distribute rewards.
     */
    constructor(address rewardDistributor_) {
        rewardDistributor = rewardDistributor_;
    }

    /**
     * @dev Initializes the farm contract with `rewardToken`, token name, and symbol. Records the current
     *      block timestamp as `initializationTimestamp` and initializes `rewardRates` with an initial zero entry.
     * @param rewardToken_ Address of the ERC20 reward token.
     * @param name_ Name of the ERC20 token.
     * @param symbol_ Symbol of the ERC20 token.
     */
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

    /**
     * @dev Allows a user to collect rewards. Calls the internal `_collectRewards` function, which checks
     *      that `distribute` was called during the reward collection process. Protected by `nonReentrant`.
     */
    function collectRewards() external nonReentrant {
        _collectRewards();
    }

    /**
     * @dev Distributes a specified `amount` of rewards across the farm, updating the cumulative reward rate.
     *      Can only be called by `rewardDistributor`. Ensures that `distribute` is only called once per block
     *      by preventing duplicate timestamp entries.
     * @param amount Amount of reward tokens to be distributed.
     */
    function distribute(uint256 amount) external {
        if (_msgSender() != rewardDistributor) {
            revert InvalidDistributor();
        }

        _updateBalances(address(0)); // Updates the farm-wide weighted balance
        _isDistributeFunctionCalled = true; // Sets flag to ensure `_collectRewards` validation
        uint256 length = rewardRates.length;
        RewardRates memory prevRate = rewardRates[length - 1];
        uint256 timestamp = block.timestamp;

        // Avoid duplicate entries for the same timestamp
        if (timestamp == prevRate.timestamp) {
            if (amount > 0) {
                revert InvalidState();
            }
            return;
        }

        // Calculate reward rate increment and update the cumulative reward rate
        uint256 incrementX96 = amount == 0 ? 0 : amount.mulDiv(Q96, lastWeightedTotalSupply);
        rewardRates.push(RewardRates(timestamp, prevRate.rewardRateX96 + incrementX96));
        timestampToRewardRatesIndex[timestamp] = length;
    }

    /**
     * @dev Transfers the caller’s claimable rewards to the specified `recipient`.
     *      Updates balances and clears claimable rewards after transfer.
     *      Protected by `nonReentrant`.
     * @param recipient Address to receive the rewards.
     * @return amount Amount of rewards transferred.
     */
    function getRewards(address recipient) external nonReentrant returns (uint256 amount) {
        return _getRewards(recipient);
    }

    /// ---------------------- EXTERNAL VIEW FUNCTIONS ----------------------

    /**
     * @dev Calculates and returns the total rewards earned by an account, including claimable rewards.
     * @param account Address of the account to calculate rewards for.
     * @return earned_ Total rewards earned by the account.
     */
    function earned(address account) external view returns (uint256 earned_) {
        (,, earned_) = calculateIncrements(account);
        return claimable[account] + earned_;
    }

    /**
     * @dev Calculates incremental balance and reward earnings for an account since the last update.
     * @param account Address for which increments are calculated.
     * @return isDuplicate Indicates if there is no time difference since the last update.
     * @return balanceIncrement Increment in balance based on time elapsed.
     * @return rewardsEarned Incremental rewards earned based on the cumulative reward rate.
     */
    function calculateIncrements(address account)
        public
        view
        returns (bool isDuplicate, uint256 balanceIncrement, uint256 rewardsEarned)
    {
        uint256 prevTimestamp = lastBalancesUpdate[account];
        if (prevTimestamp == 0) {
            prevTimestamp = initializationTimestamp;
        }

        uint256 timestamp = block.timestamp;
        if (timestamp == prevTimestamp) {
            return (true, 0, 0); // No increment if no time difference
        }

        uint256 timespan = timestamp - prevTimestamp;
        if (account == address(0)) {
            return (false, totalSupply() * timespan, 0); // Farm-wide balance increment
        }

        balanceIncrement = balanceOf(account) * timespan;
        if (balanceIncrement == 0) {
            return (false, balanceIncrement, 0); // No rewards if balance increment is zero
        }

        uint256 length = rewardRates.length;
        if (length < 2) {
            return (false, balanceIncrement, 0); // Insufficient reward rate history
        }

        uint256 prevValue = rewardRates[timestampToRewardRatesIndex[prevTimestamp]].rewardRateX96;
        uint256 lastValue = rewardRates[length - 1].rewardRateX96;
        if (prevValue < lastValue) {
            rewardsEarned = balanceIncrement.mulDiv(lastValue - prevValue, Q96);
        }
    }

    /// ---------------------- INTERNAL MUTABLE FUNCTIONS ----------------------

    /**
     * @dev Internal function to collect rewards. Verifies that `distribute` was called during the process.
     *      Reverts if `_isDistributeFunctionCalled` is not set to true by `distribute`.
     */
    function _collectRewards() internal {
        _isDistributeFunctionCalled = false; // Reset distribute call flag
        _collectRewardsImplementation();
        if (!_isDistributeFunctionCalled) {
            revert InvalidState();
        }
    }

    /**
     * @dev Internal function intended to implement specific reward collection logic in inheriting contracts.
     *      This function should call `distribute` to ensure rewards are properly distributed.
     */
    function _collectRewardsImplementation() internal virtual {}

    /**
     * @dev Internal function to handle reward transfer to a recipient. Updates the sender’s balance,
     *      transfers rewards, and clears claimable rewards for the sender.
     * @param recipient Address receiving the rewards.
     * @return amount Total rewards transferred.
     */
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

    /**
     * @dev Updates the weighted balance and claimable rewards for a given account based on the
     *      elapsed time since the last update. If `account` is `address(0)`, it updates the farm’s
     *      total weighted balance.
     * @param account Address of the account to update, or `address(0)` to update farm-wide balance.
     */
    function _updateBalances(address account) private {
        (bool isDuplicate, uint256 balanceIncrement, uint256 rewardIncrement) =
            calculateIncrements(account);
        if (isDuplicate) {
            return; // Skip if no time has passed since the last update
        }
        lastBalancesUpdate[account] = block.timestamp;

        if (account == address(0)) {
            lastWeightedTotalSupply = balanceIncrement; // Update farm-wide balance
        } else {
            claimable[account] += rewardIncrement; // Update individual claimable rewards
        }
    }

    /**
     * @dev Internal function to handle balance updates during token transfers. Calls `_collectRewards`
     *      and `_updateBalances` for both `from` and `to` addresses involved in the transfer.
     * @param from Address of the sender.
     * @param to Address of the recipient.
     * @param amount Amount of tokens transferred.
     */
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
