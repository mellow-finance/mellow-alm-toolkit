// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/ILpWrapper.sol";

import "./DefaultAccessControl.sol";
import "./VeloDeployFactory.sol";

contract LpWrapper is ILpWrapper, ERC20Upgradeable, DefaultAccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 public constant D9 = 1e9;
    uint256 public constant D18 = 1e18;

    /// @inheritdoc ILpWrapper
    address public immutable positionManager;
    /// @inheritdoc ILpWrapper
    ICore public immutable core;
    /// @inheritdoc ILpWrapper
    IAmmModule public immutable ammModule;
    /// @inheritdoc ILpWrapper
    IOracle public immutable oracle;

    /// @inheritdoc ILpWrapper
    uint256 public positionId;
    /// @inheritdoc ILpWrapper
    address public pool;
    /// @inheritdoc ILpWrapper
    IERC20 public token0;
    /// @inheritdoc ILpWrapper
    IERC20 public token1;
    /// @inheritdoc IVeloFarm
    address public rewardToken;
    /// @inheritdoc IVeloFarm
    uint256 public initializationTimestamp;

    /// @inheritdoc ILpWrapper
    uint256 public totalSupplyLimit;
    /// @inheritdoc IVeloFarm
    mapping(address account => uint256) public lastClaimTimestamp;
    /// @inheritdoc IVeloFarm
    mapping(address => uint256) public claimable;

    mapping(address account => CumulativeValue[]) private _cumulativeBalance;
    mapping(address account => mapping(uint256 timestamp => uint256)) private
        _cumulativeBalanceTimestampToIndex;
    CumulativeValue[] private _cumulativeRewardRate;
    mapping(uint256 timestamp => uint256) private _cumulativeRewardRateTimestampToIndex;

    constructor(address core_) {
        if (core_ == address(0)) {
            revert AddressZero();
        }
        core = ICore(core_);
        oracle = core.oracle();
        ammModule = core.ammModule();
        positionManager = ammModule.positionManager();
    }

    /// @inheritdoc ILpWrapper
    function initialize(
        uint256 positionId_,
        uint256 initialTotalSupply,
        uint256 totalSupplyLimit_,
        address admin_,
        address manager_,
        string memory name_,
        string memory symbol_
    ) external initializer {
        __ERC20_init(name_, symbol_);
        __Context_init();
        __DefaultAccessControl_init(admin_);
        if (manager_ != address(0)) {
            _grantRole(ADMIN_ROLE, manager_);
        }

        address this_ = address(this);
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId_);
        if (info.owner != this_) {
            revert Forbidden();
        }

        positionId = positionId_;
        totalSupplyLimit = totalSupplyLimit_;
        rewardToken = ICLGauge(ICLPool(info.pool).gauge()).rewardToken();

        _mint(this_, initialTotalSupply);

        initializationTimestamp = block.timestamp;
        collectRewards();
        _logBalances(address(0));

        emit TotalSupplyLimitUpdated(totalSupplyLimit, 0, totalSupply());
    }

    /// @inheritdoc ILpWrapper
    function deposit(
        uint256 amount0,
        uint256 amount1,
        uint256 minLpAmount,
        address to,
        uint256 deadline
    )
        external
        nonReentrant
        returns (uint256 actualAmount0, uint256 actualAmount1, uint256 lpAmount)
    {
        if (block.timestamp > deadline) {
            revert Deadline();
        }
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);

        uint256 n = info.ammPositionIds.length;
        IAmmModule.AmmPosition[] memory positionsBefore = new IAmmModule.AmmPosition[](n);
        for (uint256 i = 0; i < n; i++) {
            positionsBefore[i] = ammModule.getAmmPosition(info.ammPositionIds[i]);
        }

        uint256[] memory amounts0 = new uint256[](n);
        uint256[] memory amounts1 = new uint256[](n);
        {
            {
                (uint160 sqrtPriceX96,) = oracle.getOraclePrice(info.pool);
                for (uint256 i = 0; i < n; i++) {
                    if (positionsBefore[i].liquidity == 0) {
                        continue;
                    }
                    (amounts0[i], amounts1[i]) = ammModule.getAmountsForLiquidity(
                        positionsBefore[i].liquidity,
                        sqrtPriceX96,
                        positionsBefore[i].tickLower,
                        positionsBefore[i].tickUpper
                    );
                    actualAmount0 += amounts0[i];
                    actualAmount1 += amounts1[i];
                }
            }
            for (uint256 i = 0; i < n; i++) {
                if (actualAmount0 != 0) {
                    amounts0[i] = Math.mulDiv(amount0, amounts0[i], actualAmount0);
                }
                if (actualAmount1 != 0) {
                    amounts1[i] = Math.mulDiv(amount1, amounts1[i], actualAmount1);
                }
            }
            // used to avoid stack too deep error
            actualAmount0 = 0;
            actualAmount1 = 0;
        }
        if (amount0 == 0 && amount1 == 0) {
            revert InsufficientAmounts();
        }
        (actualAmount0, actualAmount1) =
            _directDeposit(amount0, amount1, amounts0, amounts1, positionsBefore, info);

        uint256 totalSupply_ = totalSupply();
        IAmmModule.AmmPosition memory positionsAfter;
        lpAmount = type(uint256).max;
        for (uint256 i = 0; i < n; i++) {
            positionsAfter = ammModule.getAmmPosition(info.ammPositionIds[i]);
            if (positionsBefore[i].liquidity == 0) {
                continue;
            }
            uint256 lpAmount_ = Math.mulDiv(
                positionsAfter.liquidity - positionsBefore[i].liquidity,
                totalSupply_,
                positionsBefore[i].liquidity
            );
            lpAmount = lpAmount < lpAmount_ ? lpAmount : lpAmount_;
        }

        if (lpAmount == 0 || lpAmount < minLpAmount) {
            revert InsufficientLpAmount();
        }
        if (totalSupply_ + lpAmount > totalSupplyLimit) {
            revert TotalSupplyLimitReached();
        }
        _mint(to, lpAmount);

        emit Deposit(_msgSender(), to, pool, actualAmount0, actualAmount1, lpAmount, totalSupply());
    }

    function _directDeposit(
        uint256 amount0,
        uint256 amount1,
        uint256[] memory amounts0,
        uint256[] memory amounts1,
        IAmmModule.AmmPosition[] memory positionsBefore,
        ICore.ManagedPositionInfo memory info
    ) private returns (uint256 actualAmount0, uint256 actualAmount1) {
        address sender = _msgSender();
        if (amount0 > 0) {
            token0.safeTransferFrom(sender, address(this), amount0);
            token0.safeIncreaseAllowance(address(core), amount0);
        }
        if (amount1 > 0) {
            token1.safeTransferFrom(sender, address(this), amount1);
            token1.safeIncreaseAllowance(address(core), amount1);
        }

        for (uint256 i = 0; i < positionsBefore.length; i++) {
            if (positionsBefore[i].liquidity == 0) {
                continue;
            }
            (uint256 amount0_, uint256 amount1_) =
                core.directDeposit(positionId, info.ammPositionIds[i], amounts0[i], amounts1[i]);
            actualAmount0 += amount0_;
            actualAmount1 += amount1_;
        }

        if (actualAmount0 != amount0) {
            token0.safeTransfer(sender, amount0 - actualAmount0);
        }

        if (actualAmount1 != amount1) {
            token1.safeTransfer(sender, amount1 - actualAmount1);
        }
    }

    /// @inheritdoc ILpWrapper
    function withdraw(
        uint256 lpAmount,
        uint256 minAmount0,
        uint256 minAmount1,
        address to,
        uint256 deadline
    ) external nonReentrant returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount) {
        if (block.timestamp > deadline) {
            revert Deadline();
        }

        address sender = _msgSender();
        actualLpAmount = Math.min(lpAmount, balanceOf(sender));
        if (actualLpAmount == 0) {
            revert InsufficientLpAmount();
        }

        uint256 totalSupply_ = totalSupply();
        _burn(sender, actualLpAmount);
        (amount0, amount1) = _directWithdraw(
            actualLpAmount, totalSupply_, to, core.managedPositionAt(positionId).ammPositionIds
        );
        if (amount0 < minAmount0 || amount1 < minAmount1) {
            revert InsufficientAmounts();
        }
        getRewards(to);
        emit Withdraw(sender, to, pool, amount0, amount1, lpAmount, totalSupply());
    }

    function _directWithdraw(
        uint256 actualLpAmount,
        uint256 totalSupply,
        address to,
        uint256[] memory ammPositionIds
    ) private returns (uint256 amount0, uint256 amount1) {
        for (uint256 i = 0; i < ammPositionIds.length; i++) {
            IAmmModule.AmmPosition memory position = ammModule.getAmmPosition(ammPositionIds[i]);
            uint256 liquidity = Math.mulDiv(position.liquidity, actualLpAmount, totalSupply);
            if (liquidity == 0) {
                continue;
            }

            (uint256 actualAmount0, uint256 actualAmount1) =
                core.directWithdraw(positionId, ammPositionIds[i], liquidity, to);

            amount0 += actualAmount0;
            amount1 += actualAmount1;
        }
    }

    /// @inheritdoc ILpWrapper
    function protocolParams()
        external
        view
        returns (IVeloAmmModule.ProtocolParams memory params, uint256 d9)
    {
        return (abi.decode(core.protocolParams(), (IVeloAmmModule.ProtocolParams)), D9);
    }

    /// @inheritdoc ILpWrapper
    function getInfo() external view returns (PositionData[] memory data) {
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);
        data = new PositionData[](info.ammPositionIds.length);
        for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
            data[i] = _getInfo(info.ammPositionIds[i]);
        }
    }

    function _getInfo(uint256 tokenId) internal view returns (PositionData memory data) {
        (
            uint96 nonce,
            address operator,
            address token0_,
            address token1_,
            int24 tickSpacing,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = INonfungiblePositionManager(positionManager).positions(tokenId);
        data.tokenId = tokenId;
        data.nonce = nonce;
        data.operator = operator;
        data.token0 = token0_;
        data.token1 = token1_;
        data.tickSpacing = tickSpacing;
        data.tickLower = tickLower;
        data.tickUpper = tickUpper;
        data.liquidity = liquidity;
        data.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        data.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        data.tokensOwed0 = tokensOwed0;
        data.tokensOwed1 = tokensOwed1;
    }

    /// @inheritdoc ILpWrapper
    function setPositionParams(
        uint32 slippageD9,
        IVeloAmmModule.CallbackParams calldata callbackParams,
        IPulseStrategyModule.StrategyParams calldata strategyParams,
        IVeloOracle.SecurityParams calldata securityParams
    ) external {
        setPositionParams(
            slippageD9,
            abi.encode(callbackParams),
            abi.encode(strategyParams),
            abi.encode(securityParams)
        );
    }

    function setPositionSlippageD9(uint32 slippageD9) external {
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);
        setPositionParams(slippageD9, info.callbackParams, info.strategyParams, info.securityParams);
    }

    function setPositionCallbackParams(IVeloAmmModule.CallbackParams calldata callbackParams)
        external
    {
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);
        setPositionParams(
            info.slippageD9, abi.encode(callbackParams), info.strategyParams, info.securityParams
        );
    }

    function setPositionStrategyParams(IPulseStrategyModule.StrategyParams calldata strategyParams)
        external
    {
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);
        setPositionParams(
            info.slippageD9, info.callbackParams, abi.encode(strategyParams), info.securityParams
        );
    }

    function setPositionSecurityParams(IVeloOracle.SecurityParams calldata securityParams)
        external
    {
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);
        setPositionParams(
            info.slippageD9, info.callbackParams, info.strategyParams, abi.encode(securityParams)
        );
    }

    /// @inheritdoc ILpWrapper
    function setPositionParams(
        uint32 slippageD9,
        bytes memory callbackParams,
        bytes memory strategyParams,
        bytes memory securityParams
    ) public {
        _requireAdmin();
        core.setPositionParams(
            positionId, slippageD9, callbackParams, strategyParams, securityParams
        );

        emit PositionParamsSet(
            slippageD9,
            abi.decode(callbackParams, (IVeloAmmModule.CallbackParams)),
            abi.decode(strategyParams, (IPulseStrategyModule.StrategyParams)),
            abi.decode(securityParams, (IVeloOracle.SecurityParams))
        );
    }

    /// @inheritdoc ILpWrapper
    function setTotalSupplyLimit(uint256 newTotalSupplyLimit) external {
        _requireAdmin();
        emit TotalSupplyLimitUpdated(newTotalSupplyLimit, totalSupplyLimit, totalSupply());
        totalSupplyLimit = newTotalSupplyLimit;
    }

    /// @inheritdoc ILpWrapper
    function emptyRebalance() external {
        core.emptyRebalance(positionId);
    }

    // assumption: lpWrapper == farm

    function collectRewards() public {
        core.collectRewards(positionId);
    }

    function getAccountCumulativeBalance(
        address account,
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) public view returns (uint256) {
        CumulativeValue[] storage balances = _cumulativeBalance[account];
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
        require(_msgSender() == address(core), "LpWrapper: Forbidden");
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

    function _modifyRewards(address account) private {
        if (account == address(0)) {
            return;
        }
        uint256 lastClaimTimestamp_ = lastClaimTimestamp[account];
        uint256 timestamp = block.timestamp;
        if (lastClaimTimestamp_ == timestamp) {
            return;
        }
        lastClaimTimestamp[account] = timestamp;
        uint256 amount = getAccountCumulativeBalance(account, lastClaimTimestamp_, timestamp);
        if (amount == 0) {
            return;
        }
        uint256 cumulativeRateD18 = getCumulativeRateD18(lastClaimTimestamp_, timestamp);
        claimable[account] += amount.mulDiv(cumulativeRateD18, D18);
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
    }

    function earned(address account) external view returns (uint256) {
        return claimable[account]; // change logic to include rewards that are not yet collected
    }

    /// @inheritdoc IVeloFarm
    function getRewards(address recipient) public returns (uint256 amount) {
        address sender = _msgSender();
        collectRewards();
        _logBalances(address(0));
        _logBalances(sender);
        _modifyRewards(sender);
        amount = claimable[sender];
        IERC20(rewardToken).safeTransfer(recipient, amount);
        delete claimable[sender];
    }

    function _update(address from, address to, uint256 amount) internal virtual override {
        collectRewards();
        _logBalances(address(0));
        if (from != address(0)) {
            _logBalances(from);
            _modifyRewards(from);
        }
        if (to != address(0)) {
            _logBalances(to);
            _modifyRewards(to);
        }
        super._update(from, to, amount);
    }
}
