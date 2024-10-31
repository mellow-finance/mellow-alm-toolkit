// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../interfaces/external/velo/INonfungiblePositionManager.sol";
import "../interfaces/utils/ILpWrapper.sol";

import "./DefaultAccessControl.sol";
import "./StakingRewards.sol";
import "./VeloDeployFactory.sol";

contract LpWrapper is ILpWrapper, ERC20, DefaultAccessControl {
    using SafeERC20 for IERC20;

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
    uint256 public totalSupplyLimit;

    address public immutable weth;
    address public immutable pool;
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    VeloDeployFactory public immutable factory;

    uint56 immutable D9 = 10 ** 9;

    /**
     * @dev Constructor function for the LpWrapper contract.
     * @param name_ The name of the ERC20 token.
     * @param symbol_ The symbol of the ERC20 token.
     * @param admin The address of the admin.
     * @param weth_ The address of the WETH contract.
     * @param factory_ The address of the ALM deploy factory.
     * @param pool_ The address of the Pool.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address admin,
        address weth_,
        address factory_,
        address pool_
    ) ERC20(name_, symbol_) DefaultAccessControl(admin) {
        if (weth_ == address(0) || factory_ == address(0) || pool_ == address(0)) {
            revert AddressZero();
        }

        factory = VeloDeployFactory(factory_);
        VeloDeployFactory.ImmutableParams memory immutableParams = factory.getImmutableParams();
        core = immutableParams.core;
        ammModule = core.ammModule();
        positionManager = ammModule.positionManager();
        oracle = core.oracle();
        weth = weth_;
        pool = pool_;
        token0 = IERC20(ICLPool(pool).token0());
        token1 = IERC20(ICLPool(pool).token1());
    }

    /// @inheritdoc ILpWrapper
    function initialize(uint256 positionId_, uint256 initialTotalSupply, uint256 totalSupplyLimit_)
        external
    {
        if (positionId != 0) {
            revert AlreadyInitialized();
        }
        if (core.managedPositionAt(positionId_).owner != address(this)) {
            revert Forbidden();
        }

        positionId = positionId_;
        totalSupplyLimit = totalSupplyLimit_;

        _mintLiquidity(address(this), initialTotalSupply);

        emit TotalSupplyLimitUpdated(totalSupplyLimit, 0, totalSupply());
    }

    /// @inheritdoc ILpWrapper
    function ammDepositWithdrawModule() external view returns (IAmmDepositWithdrawModule) {
        return core.ammDepositWithdrawModule();
    }

    /// @inheritdoc ILpWrapper
    function deposit(
        uint256 amount0,
        uint256 amount1,
        uint256 minLpAmount,
        address to,
        uint256 deadline
    ) external returns (uint256 actualAmount0, uint256 actualAmount1, uint256 lpAmount) {
        return _deposit(amount0, amount1, minLpAmount, to, to, deadline);
    }

    /// @inheritdoc ILpWrapper
    function getFarm() public view returns (address) {
        IVeloDeployFactory.PoolAddresses memory addresses = factory.poolToAddresses(pool);
        require(address(addresses.lpWrapper) == address(this));
        return addresses.synthetixFarm;
    }

    /// @inheritdoc ILpWrapper
    function depositAndStake(
        uint256 amount0,
        uint256 amount1,
        uint256 minLpAmount,
        address to,
        uint256 deadline
    ) external returns (uint256 actualAmount0, uint256 actualAmount1, uint256 lpAmount) {
        (actualAmount0, actualAmount1, lpAmount) =
            _deposit(amount0, amount1, minLpAmount, address(this), to, deadline);
        address farm = getFarm();
        _approve(address(this), farm, lpAmount);
        StakingRewards(farm).stakeOnBehalf(lpAmount, to);
    }

    function _mintLiquidity(address account, uint256 amount) private {
        if (totalSupply() + amount > totalSupplyLimit) {
            revert TotalSupplyLimitReached();
        }
        _mint(account, amount);
    }

    function _deposit(
        uint256 amount0,
        uint256 amount1,
        uint256 minLpAmount,
        address lpRecipient,
        address to,
        uint256 deadline
    ) private returns (uint256 actualAmount0, uint256 actualAmount1, uint256 lpAmount) {
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
        if (amount0 > 0 || amount1 > 0) {
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
            uint256 currentLpAmount = Math.mulDiv(
                positionsAfter.liquidity - positionsBefore[i].liquidity,
                totalSupply_,
                positionsBefore[i].liquidity
            );
            if (lpAmount > currentLpAmount) {
                lpAmount = currentLpAmount;
            }
        }

        if (lpAmount < minLpAmount) {
            revert InsufficientLpAmount();
        }

        _mintLiquidity(lpRecipient, lpAmount);

        emit Deposit(msg.sender, to, pool, actualAmount0, actualAmount1, lpAmount, totalSupply());
    }

    function _directDeposit(
        uint256 amount0,
        uint256 amount1,
        uint256[] memory amounts0,
        uint256[] memory amounts1,
        IAmmModule.AmmPosition[] memory positionsBefore,
        ICore.ManagedPositionInfo memory info
    ) private returns (uint256 actualAmount0, uint256 actualAmount1) {
        address sender = msg.sender;

        if (amount0 > 0) {
            if (token0.balanceOf(sender) < amount0) {
                revert InsufficientAmounts();
            }
            if (token0.allowance(sender, address(this)) < amount0) {
                revert InsufficientAllowance();
            }
            token0.safeTransferFrom(sender, address(this), amount0);
            token0.safeIncreaseAllowance(address(core), amount0);
        }
        if (amount1 > 0) {
            if (token1.balanceOf(sender) < amount1) {
                revert InsufficientAmounts();
            }
            if (token1.allowance(sender, address(this)) < amount1) {
                revert InsufficientAllowance();
            }
            token1.safeTransferFrom(sender, address(this), amount1);
            token1.safeIncreaseAllowance(address(core), amount1);
        }

        for (uint256 i = 0; i < positionsBefore.length; i++) {
            if (positionsBefore[i].liquidity == 0) {
                continue;
            }
            (uint256 amount0_, uint256 amount1_) = core.directDeposit(
                positionId, info.ammPositionIds[i], amounts0[i], amounts1[i], true
            );
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
    ) external returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount) {
        return _withdraw(lpAmount, minAmount0, minAmount1, to, deadline);
    }

    /// @inheritdoc ILpWrapper
    function unstakeAndWithdraw(
        uint256 lpAmount,
        uint256 minAmount0,
        uint256 minAmount1,
        address to,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount) {
        address farm = getFarm();
        actualLpAmount = StakingRewards(farm).balanceOf(msg.sender);
        if (actualLpAmount > lpAmount) {
            actualLpAmount = lpAmount;
        }
        StakingRewards(farm).withdrawOnBehalf(actualLpAmount, msg.sender);

        (amount0, amount1, actualLpAmount) =
            _withdraw(actualLpAmount, minAmount0, minAmount1, to, deadline);
    }

    function _withdraw(
        uint256 lpAmount,
        uint256 minAmount0,
        uint256 minAmount1,
        address to,
        uint256 deadline
    ) private returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount) {
        if (block.timestamp > deadline) {
            revert Deadline();
        }
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);

        actualLpAmount = balanceOf(msg.sender);
        if (actualLpAmount > lpAmount) {
            actualLpAmount = lpAmount;
        }

        uint256 totalSupply_ = totalSupply();
        _burn(msg.sender, actualLpAmount);

        (amount0, amount1) = _directWithdraw(actualLpAmount, totalSupply_, to, info.ammPositionIds);

        if (amount0 < minAmount0 || amount1 < minAmount1) {
            revert InsufficientAmounts();
        }

        _getReward();

        emit Withdraw(msg.sender, to, pool, amount0, amount1, lpAmount, totalSupply());
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
                core.directWithdraw(positionId, ammPositionIds[i], liquidity, to, true);

            amount0 += actualAmount0;
            amount1 += actualAmount1;
        }
    }

    /// @inheritdoc ILpWrapper
    function getReward() external {
        _getReward();
    }

    function _getReward() internal {
        address farm = getFarm();
        StakingRewards(farm).getRewardOnBehalf(msg.sender);
    }

    /// @inheritdoc ILpWrapper
    function earned(address user) external view returns (uint256 amount) {
        address farm = getFarm();
        return StakingRewards(farm).earned(user);
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
    function getInfo() external view returns (uint256 tokenId, PositionData memory data) {
        {
            ICore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);
            if (info.ammPositionIds.length != 1) {
                revert InvalidPositionsCount();
            }
            tokenId = info.ammPositionIds[0];
        }
        (
            uint96 nonce,
            address operator,
            ,
            ,
            int24 tickSpacing,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = INonfungiblePositionManager(positionManager).positions(tokenId);
        data.nonce = nonce;
        data.operator = operator;
        data.token0 = address(token0);
        data.token1 = address(token1);
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
        IVeloAmmModule.CallbackParams memory callbackParams,
        IPulseStrategyModule.StrategyParams memory strategyParams,
        IVeloOracle.SecurityParams memory securityParams
    ) external {
        _requireAdmin();
        core.setPositionParams(
            positionId,
            slippageD9,
            abi.encode(callbackParams),
            abi.encode(strategyParams),
            abi.encode(securityParams)
        );

        emit PositionParamsSet(slippageD9, callbackParams, strategyParams, securityParams);
    }

    /// @inheritdoc ILpWrapper
    function setPositionParams(
        uint32 slippageD9,
        bytes memory callbackParams,
        bytes memory strategyParams,
        bytes memory securityParams
    ) external {
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
    function setTotalSupplyLimit(uint256 totalSupplyLimitNew) external {
        _requireAdmin();

        uint256 totalSupplyLimitOld = totalSupplyLimit;
        totalSupplyLimit = totalSupplyLimitNew;

        emit TotalSupplyLimitUpdated(totalSupplyLimitNew, totalSupplyLimitOld, totalSupply());
    }

    /// @inheritdoc ILpWrapper
    function emptyRebalance() external {
        core.emptyRebalance(positionId);
    }

    receive() external payable {
        uint256 amount = msg.value;
        IWETH9(weth).deposit{value: amount}();
        IERC20(weth).safeTransfer(tx.origin, amount);
    }
}
