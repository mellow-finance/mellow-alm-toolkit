// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/ILpWrapper.sol";
import "./DefaultAccessControl.sol";
import "./VeloFarm.sol";

contract LpWrapper is ILpWrapper, VeloFarm, DefaultAccessControl {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 public constant D9 = 1e9;

    /// @inheritdoc ILpWrapper
    address public immutable positionManager;
    /// @inheritdoc ILpWrapper
    ICore public immutable core;
    /// @inheritdoc ILpWrapper
    IVeloAmmModule public immutable ammModule;
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

    /// @inheritdoc ILpWrapper
    uint256 public totalSupplyLimit;

    /// ---------------------- INITIALIZER FUNCTIONS ----------------------

    constructor(address core_) VeloFarm(core_) {
        if (core_ == address(0)) {
            revert AddressZero();
        }
        core = ICore(core_);
        oracle = core.oracle();
        ammModule = IVeloAmmModule(address(core.ammModule()));
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
        __DefaultAccessControl_init(admin_);
        if (manager_ != address(0)) {
            _grantRole(ADMIN_ROLE, manager_);
        }

        address this_ = address(this);
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId_);
        if (info.owner != this_) {
            revert Forbidden();
        }
        ICLPool pool_ = ICLPool(info.pool);

        __VeloFarm_init(ICLGauge(pool_.gauge()).rewardToken(), name_, symbol_);

        positionId = positionId_;
        totalSupplyLimit = totalSupplyLimit_;

        pool = address(pool_);
        token0 = IERC20(pool_.token0());
        token1 = IERC20(pool_.token1());

        _mint(this_, initialTotalSupply);
        emit TotalSupplyLimitUpdated(totalSupplyLimit, 0, totalSupply());
    }

    /// ---------------------- EXTERNAL MUTATING FUNCTIONS ----------------------

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
        uint256 liquidity = 0;
        for (uint256 i = 0; i < n; i++) {
            positionsBefore[i] = ammModule.getAmmPosition(info.ammPositionIds[i]);
            liquidity =
                liquidity < positionsBefore[i].liquidity ? positionsBefore[i].liquidity : liquidity;
        }
        if (liquidity == 0 || amount0 == 0 && amount1 == 0) {
            revert InsufficientAmounts();
        }
        {
            uint256[] memory amounts0 = new uint256[](n);
            uint256[] memory amounts1 = new uint256[](n);
            {
                uint128 liquidityMultiplier = uint128(type(uint128).max / liquidity);
                (uint160 sqrtPriceX96,) = oracle.getOraclePrice(info.pool);
                for (uint256 i = 0; i < n; i++) {
                    if (positionsBefore[i].liquidity == 0) {
                        continue;
                    }
                    (amounts0[i], amounts1[i]) = ammModule.getAmountsForLiquidity(
                        positionsBefore[i].liquidity * liquidityMultiplier,
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
                    amounts0[i] = amounts0[i].mulDiv(amount0, actualAmount0);
                }
                if (actualAmount1 != 0) {
                    amounts1[i] = amounts1[i].mulDiv(amount1, actualAmount1);
                }
            }
            (actualAmount0, actualAmount1) =
                _directDeposit(amount0, amount1, amounts0, amounts1, positionsBefore, info);
        }

        uint256 totalSupply_ = totalSupply();
        IAmmModule.AmmPosition memory positionsAfter;
        lpAmount = type(uint256).max;
        for (uint256 i = 0; i < n; i++) {
            positionsAfter = ammModule.getAmmPosition(info.ammPositionIds[i]);
            if (positionsBefore[i].liquidity == 0) {
                continue;
            }
            uint256 lpAmount_ = totalSupply_.mulDiv(
                positionsAfter.liquidity - positionsBefore[i].liquidity,
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
        actualLpAmount = lpAmount.min(balanceOf(sender));
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
        _getRewards(to);
        emit Withdraw(sender, to, pool, amount0, amount1, lpAmount, totalSupply());
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
    function setSlippageD9(uint32 slippageD9) external {
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);
        setPositionParams(slippageD9, info.callbackParams, info.strategyParams, info.securityParams);
    }

    /// @inheritdoc ILpWrapper
    function setCallbackParams(IVeloAmmModule.CallbackParams calldata callbackParams) external {
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);
        setPositionParams(
            info.slippageD9, abi.encode(callbackParams), info.strategyParams, info.securityParams
        );
    }

    /// @inheritdoc ILpWrapper
    function setStrategyParams(IPulseStrategyModule.StrategyParams calldata strategyParams)
        external
    {
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);
        setPositionParams(
            info.slippageD9, info.callbackParams, abi.encode(strategyParams), info.securityParams
        );
    }

    /// @inheritdoc ILpWrapper
    function setSecurityParams(IVeloOracle.SecurityParams calldata securityParams) external {
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);
        setPositionParams(
            info.slippageD9, info.callbackParams, info.strategyParams, abi.encode(securityParams)
        );
    }

    /// @inheritdoc ILpWrapper
    function setTotalSupplyLimit(uint256 newTotalSupplyLimit) external {
        _requireAdmin();
        emit TotalSupplyLimitUpdated(newTotalSupplyLimit, totalSupplyLimit, totalSupply());
        totalSupplyLimit = newTotalSupplyLimit;
    }

    /// @inheritdoc ILpWrapper
    function emptyRebalance() external nonReentrant {
        core.emptyRebalance(positionId);
    }

    /// ---------------------- EXTERNAL VIEW FUNCTIONS ----------------------

    /// @inheritdoc ILpWrapper
    function protocolParams()
        external
        view
        returns (IVeloAmmModule.ProtocolParams memory params, uint256 d9)
    {
        return (abi.decode(core.protocolParams(), (IVeloAmmModule.ProtocolParams)), D9);
    }

    /// @inheritdoc ILpWrapper
    function getInfo() external view returns (PositionLibrary.Position[] memory data) {
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);
        data = new PositionLibrary.Position[](info.ammPositionIds.length);
        for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
            data[i] = PositionLibrary.getPosition(positionManager, info.ammPositionIds[i]);
        }
    }

    /// ---------------------- INTERNAL MUTABLE FUNCTIONS ----------------------

    function _collectRewardsImplementation() internal override {
        core.collectRewards(positionId);
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

    function _directWithdraw(
        uint256 actualLpAmount,
        uint256 totalSupply,
        address to,
        uint256[] memory ammPositionIds
    ) private returns (uint256 amount0, uint256 amount1) {
        for (uint256 i = 0; i < ammPositionIds.length; i++) {
            IAmmModule.AmmPosition memory position = ammModule.getAmmPosition(ammPositionIds[i]);
            uint256 liquidity = actualLpAmount.mulDiv(position.liquidity, totalSupply);
            if (liquidity == 0) {
                continue;
            }

            (uint256 actualAmount0, uint256 actualAmount1) =
                core.directWithdraw(positionId, ammPositionIds[i], liquidity, to);

            amount0 += actualAmount0;
            amount1 += actualAmount1;
        }
    }
}
