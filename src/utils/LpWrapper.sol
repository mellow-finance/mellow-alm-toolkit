// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./StakingRewards.sol";

import "../interfaces/utils/ILpWrapper.sol";

import "../libraries/external/FullMath.sol";

import "./DefaultAccessControl.sol";

import "./VeloDeployFactory.sol";

contract LpWrapper is ILpWrapper, ERC20, DefaultAccessControl {
    using SafeERC20 for IERC20;

    /// @inheritdoc ILpWrapper
    address public immutable positionManager;

    /// @inheritdoc ILpWrapper
    IAmmDepositWithdrawModule public immutable ammDepositWithdrawModule;

    /// @inheritdoc ILpWrapper
    ICore public immutable core;

    /// @inheritdoc ILpWrapper
    IAmmModule public immutable ammModule;

    /// @inheritdoc ILpWrapper
    IOracle public immutable oracle;

    /// @inheritdoc ILpWrapper
    uint256 public positionId;

    address private immutable _weth;

    VeloDeployFactory private immutable _factory;
    address private immutable _pool;

    /**
     * @dev Constructor function for the LpWrapper contract.
     * @param core_ The address of the ICore contract.
     * @param ammDepositWithdrawModule_ The address of the IAmmDepositWithdrawModule contract.
     * @param name_ The name of the ERC20 token.
     * @param symbol_ The symbol of the ERC20 token.
     * @param admin The address of the admin.
     * @param weth_ The address of the WETH contract.
     */
    constructor(
        ICore core_,
        IAmmDepositWithdrawModule ammDepositWithdrawModule_,
        string memory name_,
        string memory symbol_,
        address admin,
        address weth_,
        address factory_,
        address pool_
    ) ERC20(name_, symbol_) DefaultAccessControl(admin) {
        core = core_;
        ammModule = core.ammModule();
        positionManager = ammModule.positionManager();
        oracle = core.oracle();
        ammDepositWithdrawModule = ammDepositWithdrawModule_;
        _weth = weth_;
        _factory = VeloDeployFactory(factory_);
        _pool = pool_;
    }

    /// @inheritdoc ILpWrapper
    function initialize(
        uint256 positionId_,
        uint256 initialTotalSupply
    ) external {
        if (positionId != 0) revert AlreadyInitialized();
        if (core.managedPositionAt(positionId_).owner != address(this))
            revert Forbidden();
        if (initialTotalSupply == 0) revert InsufficientLpAmount();
        positionId = positionId_;
        _mint(address(this), initialTotalSupply);
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
        returns (uint256 actualAmount0, uint256 actualAmount1, uint256 lpAmount)
    {
        (actualAmount0, actualAmount1, lpAmount) = _deposit(
            amount0,
            amount1,
            minLpAmount,
            deadline
        );
        _mint(to, lpAmount);
    }

    function getFarm() public view returns (address) {
        IVeloDeployFactory.PoolAddresses memory addresses = _factory
            .poolToAddresses(_pool);
        require(address(addresses.lpWrapper) == address(this));
        return addresses.synthetixFarm;
    }

    function depositAndStake(
        uint256 amount0,
        uint256 amount1,
        uint256 minLpAmount,
        address to,
        uint256 deadline
    )
        external
        returns (uint256 actualAmount0, uint256 actualAmount1, uint256 lpAmount)
    {
        (actualAmount0, actualAmount1, lpAmount) = _deposit(
            amount0,
            amount1,
            minLpAmount,
            deadline
        );
        _mint(address(this), lpAmount);
        address farm = getFarm();
        _approve(address(this), farm, lpAmount);
        StakingRewards(farm).stakeOnBehalf(lpAmount, to);
    }

    function _deposit(
        uint256 amount0,
        uint256 amount1,
        uint256 minLpAmount,
        uint256 deadline
    )
        private
        returns (uint256 actualAmount0, uint256 actualAmount1, uint256 lpAmount)
    {
        if (block.timestamp > deadline) revert Deadline();
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(
            positionId
        );
        core.withdraw(positionId, address(this));

        uint256 n = info.ammPositionIds.length;
        IAmmModule.AmmPosition[]
            memory positionsBefore = new IAmmModule.AmmPosition[](n);
        for (uint256 i = 0; i < n; i++) {
            positionsBefore[i] = ammModule.getAmmPosition(
                info.ammPositionIds[i]
            );
        }

        uint256[] memory amounts0 = new uint256[](n);
        uint256[] memory amounts1 = new uint256[](n);
        {
            {
                (uint160 sqrtPriceX96, ) = oracle.getOraclePrice(info.pool);
                for (uint256 i = 0; i < n; i++) {
                    if (positionsBefore[i].liquidity == 0) continue;
                    (amounts0[i], amounts1[i]) = ammModule
                        .getAmountsForLiquidity(
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
                    amounts0[i] = FullMath.mulDiv(
                        amount0,
                        amounts0[i],
                        actualAmount0
                    );
                }
                if (actualAmount1 != 0) {
                    amounts1[i] = FullMath.mulDiv(
                        amount1,
                        amounts1[i],
                        actualAmount1
                    );
                }
            }
            // used to avoid stack too deep error
            actualAmount0 = 0;
            actualAmount1 = 0;
        }
        if (amount0 > 0 || amount1 > 0) {
            for (uint256 i = 0; i < n; i++) {
                if (positionsBefore[i].liquidity == 0) continue;
                (bool success, bytes memory response) = address(
                    ammDepositWithdrawModule
                ).delegatecall(
                        abi.encodeWithSelector(
                            IAmmDepositWithdrawModule.deposit.selector,
                            info.ammPositionIds[i],
                            amounts0[i],
                            amounts1[i],
                            msg.sender
                        )
                    );
                if (!success) revert DepositCallFailed();
                (uint256 amount0_, uint256 amount1_) = abi.decode(
                    response,
                    (uint256, uint256)
                );

                actualAmount0 += amount0_;
                actualAmount1 += amount1_;
            }
        }

        IAmmModule.AmmPosition[]
            memory positionsAfter = new IAmmModule.AmmPosition[](n);
        for (uint256 i = 0; i < n; i++) {
            positionsAfter[i] = ammModule.getAmmPosition(
                info.ammPositionIds[i]
            );
        }

        uint256 totalSupply_ = totalSupply();
        for (uint256 i = 0; i < n; i++) {
            IERC721(positionManager).approve(
                address(core),
                info.ammPositionIds[i]
            );
        }

        lpAmount = type(uint256).max;
        for (uint256 i = 0; i < n; i++) {
            if (positionsBefore[i].liquidity == 0) continue;
            uint256 currentLpAmount = FullMath.mulDiv(
                positionsAfter[i].liquidity - positionsBefore[i].liquidity,
                totalSupply_,
                positionsBefore[i].liquidity
            );
            if (lpAmount > currentLpAmount) {
                lpAmount = currentLpAmount;
            }
        }

        if (lpAmount < minLpAmount) revert InsufficientLpAmount();
        positionId = core.deposit(
            ICore.DepositParams({
                ammPositionIds: info.ammPositionIds,
                owner: info.owner,
                slippageD9: info.slippageD9,
                callbackParams: info.callbackParams,
                strategyParams: info.strategyParams,
                securityParams: info.securityParams
            })
        );
    }

    /// @inheritdoc ILpWrapper
    function withdraw(
        uint256 lpAmount,
        uint256 minAmount0,
        uint256 minAmount1,
        address to,
        uint256 deadline
    )
        external
        returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount)
    {
        return _withdraw(lpAmount, minAmount0, minAmount1, to, deadline);
    }

    function unstakeAndWithdraw(
        uint256 lpAmount,
        uint256 minAmount0,
        uint256 minAmount1,
        address to,
        uint256 deadline
    )
        external
        returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount)
    {
        address farm = getFarm();
        StakingRewards(farm).withdrawOnBehalf(lpAmount, msg.sender);
        return _withdraw(lpAmount, minAmount0, minAmount1, to, deadline);
    }

    function _withdraw(
        uint256 lpAmount,
        uint256 minAmount0,
        uint256 minAmount1,
        address to,
        uint256 deadline
    )
        private
        returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount)
    {
        if (block.timestamp > deadline) revert Deadline();
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(
            positionId
        );
        core.withdraw(positionId, address(this));

        actualLpAmount = balanceOf(msg.sender);
        if (actualLpAmount > lpAmount) {
            actualLpAmount = lpAmount;
        }

        uint256 totalSupply_ = totalSupply();
        _burn(msg.sender, actualLpAmount);

        {
            for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
                IERC721(positionManager).approve(
                    address(core),
                    info.ammPositionIds[i]
                );
                IAmmModule.AmmPosition memory position = ammModule
                    .getAmmPosition(info.ammPositionIds[i]);
                uint256 liquidity = FullMath.mulDiv(
                    position.liquidity,
                    actualLpAmount,
                    totalSupply_
                );
                if (liquidity == 0) continue;
                (bool success, bytes memory response) = address(
                    ammDepositWithdrawModule
                ).delegatecall(
                        abi.encodeWithSelector(
                            IAmmDepositWithdrawModule.withdraw.selector,
                            info.ammPositionIds[i],
                            liquidity,
                            to
                        )
                    );
                if (!success) revert WithdrawCallFailed();
                (uint256 actualAmount0, uint256 actualAmount1) = abi.decode(
                    response,
                    (uint256, uint256)
                );

                amount0 += actualAmount0;
                amount1 += actualAmount1;
            }
        }

        if (amount0 < minAmount0 || amount1 < minAmount1) {
            revert InsufficientAmounts();
        }

        positionId = core.deposit(
            ICore.DepositParams({
                ammPositionIds: info.ammPositionIds,
                owner: info.owner,
                slippageD9: info.slippageD9,
                callbackParams: info.callbackParams,
                strategyParams: info.strategyParams,
                securityParams: info.securityParams
            })
        );
    }

    function getReward() external {
        address farm = getFarm();
        StakingRewards(farm).getRewardOnBehalf(msg.sender);
    }

    function earned(address user) external view returns (uint256 amount) {
        address farm = getFarm();
        return StakingRewards(farm).earned(user);
    }

    function protocolParams()
        external
        view
        returns (IVeloAmmModule.ProtocolParams memory params)
    {
        return
            abi.decode(core.protocolParams(), (IVeloAmmModule.ProtocolParams));
    }

    function tvl()
        external
        view
        returns (uint256 totalAmount0, uint256 totalAmount1)
    {
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(
            positionId
        );
        (uint160 sqrtPriceX96, ) = oracle.getOraclePrice(info.pool);
        bytes memory protocolParams_ = core.protocolParams();
        for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
            uint256 tokenId = info.ammPositionIds[i];
            (uint256 amount0, uint256 amount1) = ammModule.tvl(
                tokenId,
                sqrtPriceX96,
                info.callbackParams,
                protocolParams_
            );
            totalAmount0 += amount0;
            totalAmount1 += amount1;
        }
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
            positionId,
            slippageD9,
            callbackParams,
            strategyParams,
            securityParams
        );
    }

    /// @inheritdoc ILpWrapper
    function emptyRebalance() external {
        core.emptyRebalance(positionId);
    }

    receive() external payable {
        uint256 amount = msg.value;
        IWETH9(_weth).deposit{value: amount}();
        IERC20(_weth).safeTransfer(tx.origin, amount);
    }
}
