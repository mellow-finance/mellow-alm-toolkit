// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/utils/ILpWrapper.sol";

import "../libraries/external/FullMath.sol";

import "./DefaultAccessControl.sol";

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
        address weth_
    ) ERC20(name_, symbol_) DefaultAccessControl(admin) {
        core = core_;
        ammModule = core.ammModule();
        positionManager = ammModule.positionManager();
        oracle = core.oracle();
        ammDepositWithdrawModule = ammDepositWithdrawModule_;
        _weth = weth_;
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
        if (block.timestamp > deadline) revert Deadline();
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(
            positionId
        );
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
            if (amount0 > 0) {
                IERC20(positionsBefore[0].token0).safeTransferFrom(
                    msg.sender,
                    address(this),
                    amount0
                );
                IERC20(positionsBefore[0].token0).safeIncreaseAllowance(
                    address(core),
                    amount0
                );
            }
            if (amount1 > 0) {
                IERC20(positionsBefore[0].token1).safeTransferFrom(
                    msg.sender,
                    address(this),
                    amount1
                );
                IERC20(positionsBefore[0].token1).safeIncreaseAllowance(
                    address(core),
                    amount1
                );
            }

            for (uint256 i = 0; i < n; i++) {
                if (positionsBefore[i].liquidity == 0) continue;
                (uint256 amount0_, uint256 amount1_) = core.directDeposit(
                    positionId,
                    info.ammPositionIds[i],
                    amounts0[i],
                    amounts1[i],
                    true
                );
                actualAmount0 += amount0_;
                actualAmount1 += amount1_;
            }

            if (actualAmount0 != amount0) {
                IERC20(positionsBefore[0].token0).safeTransfer(
                    msg.sender,
                    amount0 - actualAmount0
                );
                IERC20(positionsBefore[0].token0).safeApprove(address(core), 0);
            }

            if (actualAmount1 != amount1) {
                IERC20(positionsBefore[0].token1).safeTransfer(
                    msg.sender,
                    amount1 - actualAmount1
                );
                IERC20(positionsBefore[0].token1).safeApprove(address(core), 0);
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
        _mint(to, lpAmount);
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
        if (block.timestamp > deadline) revert Deadline();
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(
            positionId
        );

        actualLpAmount = balanceOf(msg.sender);
        if (actualLpAmount > lpAmount) {
            actualLpAmount = lpAmount;
        }

        uint256 totalSupply_ = totalSupply();
        _burn(msg.sender, actualLpAmount);

        {
            for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
                IAmmModule.AmmPosition memory position = ammModule
                    .getAmmPosition(info.ammPositionIds[i]);
                uint256 liquidity = FullMath.mulDiv(
                    position.liquidity,
                    actualLpAmount,
                    totalSupply_
                );
                if (liquidity == 0) continue;

                (uint256 actualAmount0, uint256 actualAmount1) = core
                    .directWithdraw(
                        positionId,
                        info.ammPositionIds[i],
                        liquidity,
                        msg.sender,
                        true
                    );

                amount0 += actualAmount0;
                amount1 += actualAmount1;
            }
        }

        if (amount0 < minAmount0 || amount1 < minAmount1) {
            revert InsufficientAmounts();
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
