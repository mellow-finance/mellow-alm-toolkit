// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/ILpStaker.sol";
import "./DefaultAccessControl.sol";

contract LpStaker is ILpStaker, ERC20Upgradeable, ReentrancyGuard, DefaultAccessControl {
    using SafeERC20 for IERC20;
    using Math for uint256;

    ICore public immutable core;

    IVeloAmmModule public immutable ammModule;

    IOracle public immutable oracle;

    ILpWrapper public lpWrapper;

    address public rewardToken;

    /// @dev Pool address with pair [reward token, token0]
    address public rewardPool0;

    /// @dev Pool address with pair [reward token, token1]
    address public rewardPool1;

    address public pool;

    address public token0;

    address public token1;

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
    function initialize(
        ILpWrapper lpWrapper_,
        address pool0_,
        address pool1_,
        address admin_,
        address manager_
    ) external initializer {
        if (address(lpWrapper_) == address(0) || pool0_ == address(0) || pool1_ == address(0)) {
            revert AddressZero();
        }

        if (
            lpWrapper_.core() != core || lpWrapper_.oracle() != oracle
                || lpWrapper_.ammModule() != ammModule
        ) {
            revert InvalidLpWrapper();
        }

        pool = lpWrapper_.pool();
        (token0, token1) = ammModule.getPoolTokens(pool);
        rewardToken = ammModule.getRewardToken(pool);

        _checkPoolIsValid(pool0_, rewardToken);
        _checkPoolIsValid(pool1_, rewardToken);
        rewardPool0 = pool0_;
        rewardPool1 = pool1_;

        _lpPrice = 1 ether;

        __DefaultAccessControl_init(admin_);
        if (manager_ != address(0)) {
            _grantRole(ADMIN_ROLE, manager_);
        }

        __ERC20_init(
            string(abi.encodePacked(IERC20Metadata(address(lpWrapper_)).name(), "Stake")),
            string(abi.encodePacked("S", IERC20Metadata(address(lpWrapper_)).symbol()))
        );
        __Context_init();

        lpWrapper = lpWrapper_;

        if (!ammModule.isPool(pool)) {
            revert InvalidPool();
        }

        /// @dev give infinite approval to lpWrapper for token0 and token1
        IERC20(address(token0)).safeIncreaseAllowance(address(lpWrapper_), type(uint256).max);
        IERC20(address(token1)).safeIncreaseAllowance(address(lpWrapper_), type(uint256).max);
    }

    /// @inheritdoc ILpStaker
    function stake(uint256 amount) external nonReentrant returns (uint256 shares) {
        if (amount == 0) {
            revert ZeroAmount();
        }
        IERC20(address(lpWrapper)).safeTransferFrom(msg.sender, address(this), amount);

        shares = amount.mulDiv(1 ether, _lpPrice);

        _mint(msg.sender, shares);

        emit Staked(msg.sender, amount, shares, _lpPrice);
    }

    function unstake(uint256 shares) external nonReentrant returns (uint256 amount) {
        if (shares == 0) {
            revert ZeroAmount();
        }
        amount = shares.mulDiv(_lpPrice, 1 ether);

        _burn(msg.sender, shares);
        IERC20(address(lpWrapper)).safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount, shares, _lpPrice);
    }

    /// @inheritdoc ILpStaker
    function updateRewards() external nonReentrant {
        /// @dev permissionless, just check mev while swap

        address _this = address(this);
        ILpWrapper lpWrapper_ = lpWrapper;

        lpWrapper_.getRewards(_this);

        uint256 rewardBalance = IERC20(rewardToken).balanceOf(_this);
        if (rewardBalance == 0) {
            return;
        }

        /// @dev split rewards between two pools according to their weights in the LP
        splitRewards(rewardBalance);

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

        _lpPrice = _lpPrice.mulDiv(lpAmount + deltaLpAmount, lpAmount);

        emit RewardsUpdated(rewardBalance, deltaLpAmount, _lpPrice);
    }

    /* -------------------------------------------------------------------------------
     *                     Internal mutable functions
     * ------------------------------------------------------------------------------- */

    function splitRewards(uint256 rewardAmount) internal {
        (uint256 amount0, uint256 amount1) = lpWrapper.previewMint(1 ether);

        address rewardPool0_ = rewardPool0;
        address rewardPool1_ = rewardPool1;

        bool zeroForOne0 = ammModule.getToken0(rewardPool0_) == token0;
        uint256 rewardAmount0 = PositionMath.convertAmount(
            amount0, zeroForOne0, ammModule.getSqrtPriceX96(rewardPool0_)
        );

        bool zeroForOne1 = ammModule.getToken0(rewardPool1_) == token1;
        uint256 rewardAmount1 = PositionMath.convertAmount(
            amount1, zeroForOne1, ammModule.getSqrtPriceX96(rewardPool1_)
        );

        uint256 totalRewards = rewardAmount0 + rewardAmount1;

        rewardAmount0 = rewardAmount0.mulDiv(rewardAmount, totalRewards);
        rewardAmount1 = rewardAmount1.mulDiv(rewardAmount, totalRewards);

        if (rewardAmount0 + rewardAmount1 != rewardAmount) {
            rewardAmount0 = rewardAmount - rewardAmount1;
        }

        /// @dev swap rewards to token0 and token1 accordingly
        swapOnRewardPool(rewardPool0_, zeroForOne0, rewardAmount0);
        swapOnRewardPool(rewardPool1_, zeroForOne1, rewardAmount1);
    }

    function swapOnRewardPool(address rewardPool, bool zeroForOne, uint256 rewardAmount) internal {
        _ensureNoMEV(rewardPool);

        bytes memory result = Address.functionDelegateCall(
            address(ammModule),
            abi.encodeWithSelector(
                IAmmModule.swapOnPool.selector, rewardPool, zeroForOne, rewardAmount
            )
        );

        if (result.length != 64) {
            revert RewardSwapFailed(rewardPool, zeroForOne, rewardAmount);
        }

        (int256 amount0, int256 amount1) = abi.decode(result, (int256, int256));
        uint256 amountOut = uint256(-(zeroForOne ? amount1 : amount0));

        emit RewardsSwapped(
            rewardPool,
            rewardToken,
            rewardPool == rewardPool0 ? token0 : token1,
            rewardAmount,
            amountOut
        );
    }

    /* -------------------------------------------------------------------------------
     *                     Internal view functions
     * ------------------------------------------------------------------------------- */

    function _checkPoolIsValid(address rewardPool, address rewardToken) internal view {
        if (!ammModule.isPool(rewardPool)) {
            revert InvalidPool();
        }
        (address token0Reward, address token1Reward) = ammModule.getPoolTokens(rewardPool);

        if (token0Reward != rewardToken && token1Reward != rewardToken) {
            revert InvalidPool();
        }

        if (
            token0Reward != token0 && token1Reward != token0 && token0Reward != token1
                && token1Reward != token1
        ) {
            revert InvalidPool();
        }
    }

    function _ensureNoMEV(address pool) internal view {
        ICore.ManagedPositionInfo memory position =
            core.managedPositionAt(ILpWrapper(lpWrapper).positionId());
        oracle.ensureNoMEV(pool, position.securityParams);
    }
}
