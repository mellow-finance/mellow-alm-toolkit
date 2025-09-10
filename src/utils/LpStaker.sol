// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/ILpStaker.sol";
import "./AccessControlCalls.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

contract LpStaker is ILpStaker, ERC20Upgradeable, ReentrancyGuard, AccessControlCalls {
    using Checkpoints for Checkpoints.Trace224;
    using SafeERC20 for IERC20;
    using Math for uint256;

    /// @inheritdoc ILpStaker
    uint32 public constant MIN_TIMELOCK_DURATION = 4 hours;
    /// @inheritdoc ILpStaker
    uint32 public constant MAX_TIMELOCK_DURATION = 7 days;
    /// @inheritdoc ILpStaker
    uint32 public constant MAX_ACTIVE_LOCKS = 20;

    /// @inheritdoc ILpStaker
    ICore public immutable core;
    /// @inheritdoc ILpStaker
    IAmmModule public immutable ammModule;
    /// @inheritdoc ILpStaker
    IOracle public immutable oracle;

    /// @inheritdoc ILpStaker
    ILpWrapper public lpWrapper;
    /// @inheritdoc ILpStaker
    address public rewardToken;
    /// @inheritdoc ILpStaker
    uint32 public timeLock;
    /// @inheritdoc ILpStaker
    uint256 public lpPrice;
    /// @inheritdoc ILpStaker
    address public token0;
    /// @inheritdoc ILpStaker
    address public token1;

    /// @dev A record of locked amounts for each account
    mapping(address => Checkpoints.Trace224) private lockedCheckpoints;

    constructor(address core_) {
        if (core_ == address(0)) {
            revert AddressZero();
        }
        core = ICore(core_);
        oracle = core.oracle();
        ammModule = core.ammModule();
    }

    /* -------------------------------------------------------------------------------
     *                     External mutable functions
     * ------------------------------------------------------------------------------- */

    /// @inheritdoc ILpStaker
    function initialize(
        ILpWrapper lpWrapper_,
        address admin_,
        address manager_,
        address operator_,
        uint32 timeLock_
    ) external initializer {
        if (address(lpWrapper_) == address(0)) {
            revert AddressZero();
        }

        if (
            lpWrapper_.core() != core || lpWrapper_.oracle() != oracle
                || lpWrapper_.ammModule() != ammModule
        ) {
            revert InvalidLpWrapper();
        }

        rewardToken = ammModule.getRewardToken(lpWrapper_.pool());

        lpPrice = 1 ether;
        lpWrapper = lpWrapper_;

        __AccessControlCalls_init(admin_);

        if (manager_ != address(0)) {
            _grantRole(ADMIN_ROLE, manager_);
        }

        if (operator_ != address(0)) {
            _grantRole(OPERATOR_ROLE, operator_);
        }

        __ERC20_init(
            string(abi.encodePacked(IERC20Metadata(address(lpWrapper_)).name(), "Stake")),
            string(abi.encodePacked("S", IERC20Metadata(address(lpWrapper_)).symbol()))
        );

        __Context_init();

        token0 = address(lpWrapper_.token0());
        token1 = address(lpWrapper_.token1());

        /// @dev give infinite approvals to lpWrapper for token0 and token1
        IERC20(token0).safeIncreaseAllowance(address(lpWrapper_), type(uint256).max);
        IERC20(token1).safeIncreaseAllowance(address(lpWrapper_), type(uint256).max);

        _setTimeLock(timeLock_);
    }

    /// @inheritdoc ILpStaker
    function stake(uint256 lpAmount, address recipient)
        external
        nonReentrant
        returns (uint256 shares)
    {
        if (recipient == address(0)) {
            revert AddressZero();
        }
        if (lpAmount == 0) {
            revert ZeroAmount();
        }

        /// @dev rewards are collected on behalf of the sender before transfer, because of LpWrapper logic
        IERC20(address(lpWrapper)).safeTransferFrom(msg.sender, address(this), lpAmount);

        shares = _mintShares(recipient, lpAmount);
    }

    /// @inheritdoc ILpStaker
    function unstake(uint256 shares, address recipient)
        external
        nonReentrant
        returns (uint256 lpAmount)
    {
        if (recipient == address(0)) {
            revert AddressZero();
        }
        if (shares == 0) {
            revert ZeroAmount();
        }

        lpAmount = _burnShares(msg.sender, shares);

        IERC20(address(lpWrapper)).safeTransfer(recipient, lpAmount);
    }

    /// @inheritdoc ILpStaker
    function mintAndStake(uint256 amount0, uint256 amount1, address recipient)
        external
        nonReentrant
        returns (
            uint256 actualAmount0,
            uint256 actualAmount1,
            uint256 actualLpAmount,
            uint256 shares
        )
    {
        address _this = address(this);
        address _sender = msg.sender;
        if (recipient == address(0)) {
            revert AddressZero();
        }

        uint256 lpAmount = lpWrapper.previewDeposit(amount0, amount1);
        if (lpAmount == 0) {
            revert ZeroAmount();
        }
        (amount0, amount1) = lpWrapper.previewMint(lpAmount);

        /// @dev pull tokens from the sender in precise amounts
        IERC20(token0).safeTransferFrom(_sender, _this, amount0);
        IERC20(token1).safeTransferFrom(_sender, _this, amount1);

        (actualAmount0, actualAmount1, actualLpAmount) = lpWrapper.mint(
            ILpWrapper.MintParams({
                lpAmount: lpAmount,
                amount0Max: amount0,
                amount1Max: amount1,
                recipient: _this,
                deadline: type(uint256).max
            })
        );

        shares = _mintShares(recipient, actualLpAmount);
    }

    /// @inheritdoc ILpStaker
    function unstakeAndWithdraw(
        uint256 shares,
        uint256 amount0Min,
        uint256 amount1Min,
        address recipient
    )
        external
        nonReentrant
        returns (uint256 actualAmount0, uint256 actualAmount1, uint256 actualLpAmount)
    {
        address _this = address(this);
        address _sender = msg.sender;
        ILpWrapper _lpWrapper = lpWrapper;
        if (shares == 0) {
            revert ZeroAmount();
        }

        actualLpAmount = _burnShares(_sender, shares);

        (actualAmount0, actualAmount1, actualLpAmount) =
            _lpWrapper.withdraw(actualLpAmount, amount0Min, amount1Min, _this, type(uint256).max);

        if (actualAmount0 > 0) {
            IERC20(token0).safeTransfer(recipient, actualAmount0);
        }

        if (actualAmount1 > 0) {
            IERC20(token1).safeTransfer(recipient, actualAmount1);
        }
    }

    /// @inheritdoc ILpStaker
    function compoundRewards(SwapParams[2] memory swapParams) external nonReentrant {
        _requireAtLeastOperator();

        address _this = address(this);
        ILpWrapper lpWrapper_ = lpWrapper;

        lpWrapper_.getRewards(_this);

        uint256 rewardBalance = IERC20(rewardToken).balanceOf(_this);
        if (rewardBalance == 0) {
            return;
        }

        if (swapParams[0].amountIn + swapParams[1].amountIn > rewardBalance) {
            revert SlippageExceeded();
        }

        _swapRewards(swapParams);

        uint256 balance0 = IERC20(token0).balanceOf(_this);
        uint256 balance1 = IERC20(token1).balanceOf(_this);

        uint256 lpAmount = IERC20(address(lpWrapper_)).balanceOf(_this);

        (,, uint256 deltaLpAmount) = lpWrapper_.mint(
            ILpWrapper.MintParams({
                lpAmount: lpWrapper_.previewDeposit(balance0, balance1),
                amount0Max: balance0,
                amount1Max: balance1,
                recipient: _this,
                deadline: block.timestamp + 1
            })
        );

        lpPrice = lpPrice.mulDiv(lpAmount + deltaLpAmount, lpAmount);
        uint256 rewardBalanceAfter = IERC20(rewardToken).balanceOf(_this);

        emit RewardsCompounded(rewardBalance - rewardBalanceAfter, deltaLpAmount, lpPrice);
    }

    /// @inheritdoc ILpStaker
    function setTimeLock(uint32 newTimeLock) external onlyRole(ADMIN_ROLE) {
        _setTimeLock(newTimeLock);
    }

    /* -------------------------------------------------------------------------------
     *                     External view functions
     * ------------------------------------------------------------------------------- */

    /// @inheritdoc ILpStaker
    function quoteSwapAmounts() public view returns (QuoteParams[2] memory quoteParams) {
        address _this = address(this);
        address _rewardToken = rewardToken;

        /// @dev get total rewards (already hold on _this + not yet claimed from lpWrapper)
        uint256 rewardBalance = lpWrapper.earned(_this) + IERC20(_rewardToken).balanceOf(_this);

        (uint256 rewardAmount0, uint256 rewardAmount1) = _splitRewards(rewardBalance);

        quoteParams[0] =
            QuoteParams({tokenIn: _rewardToken, tokenOut: token0, amountIn: rewardAmount0});

        quoteParams[1] =
            QuoteParams({tokenIn: _rewardToken, tokenOut: token1, amountIn: rewardAmount1});
    }

    /// @inheritdoc ILpStaker
    function sharesOf(address account) external view returns (uint256) {
        return balanceOf(account);
    }

    /// @inheritdoc ILpStaker
    function lpAmountOf(address account) external view returns (uint256) {
        return balanceOf(account).mulDiv(lpPrice, 1 ether);
    }

    /// @inheritdoc ILpStaker
    function assetsOf(address account) external view returns (uint256, uint256) {
        return lpWrapper.previewBurn(balanceOf(account).mulDiv(lpPrice, 1 ether));
    }

    /// @inheritdoc ILpStaker
    function getLockedShares(address account, uint32 timestamp)
        public
        view
        returns (uint256 lockedShares, uint32 activeCheckpoints, uint32 length)
    {
        length = uint32(lockedCheckpoints[account].length());
        uint32 count = length;
        while (count > 0) {
            count--;
            Checkpoints.Checkpoint224 memory checkpoint = lockedCheckpoints[account].at(count);
            if (checkpoint._key <= timestamp) {
                break;
            }
            lockedShares += checkpoint._value;
            activeCheckpoints++;
        }
    }

    /* -------------------------------------------------------------------------------
     *                     Internal mutable functions
     * ------------------------------------------------------------------------------- */

    function _mintShares(address to, uint256 lpAmount) internal returns (uint256 shares) {
        uint256 lpPrice_ = lpPrice;

        shares = lpAmount.mulDiv(1 ether, lpPrice_);
        _mint(to, shares);

        emit Staked(to, lpAmount, shares, lpPrice_);
    }

    function _burnShares(address from, uint256 shares) internal returns (uint256 lpAmount) {
        uint256 lpPrice_ = lpPrice;

        lpAmount = shares.mulDiv(lpPrice_, 1 ether);
        _burn(from, shares);

        emit Unstaked(from, lpAmount, shares, lpPrice_);
    }

    /// @dev Override the _update function to enforce locked shares during transfers and burns
    function _update(address from, address to, uint256 value) internal override {
        /// @dev make optimistic transfer first, then check the locked shares
        super._update(from, to, value);

        if (from != address(0)) {
            /// @dev when not mint (burn or transfer): check available shares (not locked)
            (uint256 lockedShares,,) = getLockedShares(from, uint32(block.timestamp));
            uint256 remainBalance = balanceOf(from);
            if (remainBalance < lockedShares) {
                revert InsufficientUnlockedShares(from, lockedShares, value);
            }
        } else {
            _pushCheckpoint(to, uint224(value));
        }
    }

    /// @dev Pushes a new checkpoint for the locked shares of an account.
    /// If the last checkpoint has the same timestamp, it merges the values.
    /// @param account The address of the account to push the checkpoint for.
    /// @param value The value of the checkpoint.
    function _pushCheckpoint(address account, uint224 value) internal {
        uint32 timestamp_ = uint32(block.timestamp);
        /// @dev get current number of active locks at now
        (, uint32 activeCheckpoints, uint32 length) = getLockedShares(account, timestamp_);

        /// @dev limit the number of active locks to prevent OOG
        if (activeCheckpoints >= MAX_ACTIVE_LOCKS) {
            revert TooManyActiveLocks(account, activeCheckpoints);
        }

        /// @dev calculate the timestamp of new checkpoint in the future
        uint32 timestampLock = timestamp_ + timeLock;

        /// @dev check if there is existing a checkpoint with the same timestamp
        if (length > 0) {
            Checkpoints.Checkpoint224 memory lastCheckpoint =
                lockedCheckpoints[account].at(length - 1);
            if (lastCheckpoint._key == timestampLock) {
                /// @dev merge with the last checkpoint if the timestamp is the same
                /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/69c8def5f222ff96f2b5beff05dfba996368aa79/contracts/utils/structs/Checkpoints.sol#L152
                value += lastCheckpoint._value;
            }
        }
        /// @dev push with the same key just will rewrite the checkpoint value
        lockedCheckpoints[account].push(timestampLock, value);
    }

    /**
     * @dev Swaps the rewards on the specified target address provided in `swapParams`.
     * @param swapParams An array of SwapParams structs containing the parameters for each swap.
     */
    function _swapRewards(SwapParams[2] memory swapParams) internal {
        address _this = address(this);

        for (uint256 index = 0; index < swapParams.length; index++) {
            address tokenOut = swapParams[index].tokenOut;
            uint256 amountIn = swapParams[index].amountIn;

            IERC20(rewardToken).safeIncreaseAllowance(swapParams[index].target, amountIn);

            uint256 balanceBefore = IERC20(tokenOut).balanceOf(_this);
            Address.functionCall(swapParams[index].target, swapParams[index].data);
            uint256 balanceAfter = IERC20(tokenOut).balanceOf(_this);

            if (
                balanceAfter < balanceBefore
                    || balanceAfter - balanceBefore < swapParams[index].minAmountOut
            ) {
                revert RewardSwapFailed(swapParams[index].target, amountIn, tokenOut);
            }
        }
    }

    /**
     * @dev Updates the duration of the timeLock for unstaking. Updating does not affect already locked amounts.
     * This function allows to change the duration of the timeLock within the allowed range.
     * Emits a `TimeLockUpdated` event upon successful completion.
     * @param newTimeLock The new duration for the timeLock, in seconds.
     */
    function _setTimeLock(uint32 newTimeLock) internal {
        if (newTimeLock < MIN_TIMELOCK_DURATION || newTimeLock > MAX_TIMELOCK_DURATION) {
            revert InvalidTimeLock(newTimeLock);
        }

        uint32 oldTimeLock = timeLock;
        timeLock = newTimeLock;

        emit TimeLockUpdated(oldTimeLock, newTimeLock);
    }

    /* -------------------------------------------------------------------------------
     *                     Internal view functions
     * ------------------------------------------------------------------------------- */

    /**
     * @dev Splits the rewards into two parts: rewardAmount0 and rewardAmount1 regarding capital amounts of token0 and token1 in the LP.
     * @param rewardAmount The total amount of rewards to split.
     * @return rewardAmount0 The amount of rewards should be swapped into token0.
     * @return rewardAmount1 The amount of rewards should be swapped into token1.
     */
    function _splitRewards(uint256 rewardAmount)
        internal
        view
        returns (uint256 rewardAmount0, uint256 rewardAmount1)
    {
        (uint256 amount0, uint256 amount1) = lpWrapper.previewMint(1 ether);
        uint256 sqrtPriceX96 = ammModule.getSqrtPriceX96(lpWrapper.pool());

        uint256 capitalTotal = PositionMath.calculateCapital(amount0, amount1, sqrtPriceX96);
        uint256 capitalTotal0 = PositionMath.calculateCapital(amount0, 0, sqrtPriceX96);
        uint256 capitalTotal1 = PositionMath.calculateCapital(0, amount1, sqrtPriceX96);

        rewardAmount0 = rewardAmount.mulDiv(capitalTotal0, capitalTotal);
        rewardAmount1 = rewardAmount.mulDiv(capitalTotal1, capitalTotal);

        if (rewardAmount0 + rewardAmount1 != rewardAmount) {
            rewardAmount0 = rewardAmount - rewardAmount1;
        }
    }
}
