// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/ILpStaker.sol";
import "./AccessControlCalls.sol";

contract LpStaker is ILpStaker, ERC20Upgradeable, ReentrancyGuard, AccessControlCalls {
    using SafeERC20 for IERC20;
    using Math for uint256;

    ICore public immutable core;

    IVeloAmmModule public immutable ammModule;

    IOracle public immutable oracle;

    ILpWrapper public lpWrapper;

    address public rewardToken;

    /// @dev Price of 1 LP token in shares, multiplied by 1 ether
    uint256 private _lpPrice;

    constructor(address core_) {
        if (core_ == address(0)) {
            revert AddressZero();
        }
        core = ICore(core_);
        oracle = core.oracle();
        ammModule = IVeloAmmModule(address(core.ammModule()));
    }

    /* -------------------------------------------------------------------------------
     *                     External mutable functions
     * ------------------------------------------------------------------------------- */

    /// @inheritdoc ILpStaker
    function initialize(ILpWrapper lpWrapper_, address admin_, address manager_, address operator_)
        external
        initializer
    {
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

        _lpPrice = 1 ether;
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

        /// @dev give infinite approvals to lpWrapper for token0 and token1
        IERC20(address(lpWrapper.token0())).safeIncreaseAllowance(
            address(lpWrapper_), type(uint256).max
        );
        IERC20(address(lpWrapper.token1())).safeIncreaseAllowance(
            address(lpWrapper_), type(uint256).max
        );
    }

    /// @inheritdoc ILpStaker
    function stake(uint256 amount) external nonReentrant returns (uint256 shares) {
        address _sender = msg.sender;
        if (amount == 0) {
            revert ZeroAmount();
        }

        IERC20(address(lpWrapper)).safeTransferFrom(_sender, address(this), amount);
        shares = amount.mulDiv(1 ether, _lpPrice);
        _mint(_sender, shares);

        emit Staked(_sender, amount, shares, _lpPrice);
    }

    /// @inheritdoc ILpStaker
    function unstake(uint256 shares) external nonReentrant returns (uint256 amount) {
        address _sender = msg.sender;

        if (shares == 0) {
            revert ZeroAmount();
        }

        _burn(_sender, shares);
        amount = shares.mulDiv(_lpPrice, 1 ether);
        IERC20(address(lpWrapper)).safeTransfer(_sender, amount);

        emit Unstaked(_sender, amount, shares, _lpPrice);
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

        swapRewards(swapParams);

        uint256 balance0 = IERC20(lpWrapper_.token0()).balanceOf(_this);
        uint256 balance1 = IERC20(lpWrapper_.token1()).balanceOf(_this);

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

        _lpPrice = _lpPrice.mulDiv(lpAmount + deltaLpAmount, lpAmount);
        uint256 rewardBalanceAfter = IERC20(rewardToken).balanceOf(_this);

        emit RewardsCompounded(rewardBalance - rewardBalanceAfter, deltaLpAmount, _lpPrice);
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

        (uint256 rewardAmount0, uint256 rewardAmount1) = splitRewards(rewardBalance);

        quoteParams[0] = QuoteParams({
            tokenIn: _rewardToken,
            tokenOut: lpWrapper.token0(),
            amountIn: rewardAmount0
        });

        quoteParams[1] = QuoteParams({
            tokenIn: _rewardToken,
            tokenOut: lpWrapper.token1(),
            amountIn: rewardAmount1
        });
    }

    /// @inheritdoc ILpStaker
    function lpPrice() external view returns (uint256) {
        return _lpPrice;
    }

    /// @inheritdoc ILpStaker
    function sharesOf(address account) external view returns (uint256) {
        return balanceOf(account);
    }

    /// @inheritdoc ILpStaker
    function assetsOf(address account) external view returns (uint256) {
        return balanceOf(account).mulDiv(_lpPrice, 1 ether);
    }

    /* -------------------------------------------------------------------------------
     *                     Internal mutable functions
     * ------------------------------------------------------------------------------- */

    /**
     * @dev Swaps the rewards on the specified target address provided in `swapParams`.
     * @param swapParams An array of SwapParams structs containing the parameters for each swap.
     */
    function swapRewards(SwapParams[2] memory swapParams) internal {
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

    /* -------------------------------------------------------------------------------
     *                     Internal view functions
     * ------------------------------------------------------------------------------- */

    /**
     * @dev Splits the rewards into two parts: rewardAmount0 and rewardAmount1 regarding capital amounts of token0 and token1 in the LP.
     * @param rewardAmount The total amount of rewards to split.
     * @return rewardAmount0 The amount of rewards should be swapped into token0.
     * @return rewardAmount1 The amount of rewards should be swapped into token1.
     */
    function splitRewards(uint256 rewardAmount)
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
