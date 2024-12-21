// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./LpWrapper.sol";

contract DepositHelper {
    using SafeERC20 for IERC20;

    uint256 private constant D9 = 1000000000;
    uint256 private constant Q64 = 0x10000000000000000;
    uint256 private constant Q128 = 0x100000000000000000000000000000000;

    struct DepositParams {
        address token0;
        address token1;
        ILpWrapper wrapper;
        address recipient;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    function deposit(DepositParams calldata depositParams)
        external
        returns (uint256 actualAmount0, uint256 actualAmount1, uint256 actualLpAmount)
    {
        (uint256 amount0, uint256 amount1, uint256 lpAmount) = previewDeposit(
            depositParams.wrapper, depositParams.amount0Desired, depositParams.amount1Desired
        );

        IERC20(depositParams.token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(depositParams.token1).safeTransferFrom(msg.sender, address(this), amount1);
        IERC20(depositParams.token0).safeIncreaseAllowance(address(depositParams.wrapper), amount0);
        IERC20(depositParams.token1).safeIncreaseAllowance(address(depositParams.wrapper), amount1);

        (actualAmount0, actualAmount1, actualLpAmount) = depositParams.wrapper.mint(
            ILpWrapper.MintParams({
                lpAmount: lpAmount,
                amount0Max: amount0,
                amount1Max: amount1,
                recipient: depositParams.recipient,
                deadline: depositParams.deadline
            })
        );

        if (actualAmount0 < depositParams.amount0Min || actualAmount1 < depositParams.amount1Min) {
            revert ILpWrapper.InsufficientAmounts();
        }

        if (amount0 > actualAmount0) {
            IERC20(depositParams.token0).safeTransfer(msg.sender, amount0 - actualAmount0);
        }

        if (amount1 > actualAmount1) {
            IERC20(depositParams.token1).safeTransfer(msg.sender, amount1 - actualAmount1);
        }
    }

    function previewDeposit(ILpWrapper wrapper, uint256 amount0, uint256 amount1)
        public
        view
        returns (uint256 actualAmount0, uint256 actualAmount1, uint256 actualLpAmount)
    {
        ICore.ManagedPositionInfo memory info =
            wrapper.core().managedPositionAt(wrapper.positionId());
        uint256 n = info.ammPositionIds.length;
        uint256 totalSupply = wrapper.totalSupply();
        (uint160 sqrtPriceX96,) = wrapper.oracle().getOraclePrice(info.pool);
        IAmmModule.AmmPosition[] memory positions = new IAmmModule.AmmPosition[](n);
        IAmmModule ammModule = wrapper.ammModule();
        uint256 scale = type(uint256).max;
        for (uint256 i = 0; i < n; i++) {
            positions[i] = ammModule.getAmmPosition(info.ammPositionIds[i]);
            scale =
                Math.min(scale, Math.mulDiv(type(uint128).max, totalSupply, positions[i].liquidity));
        }
        (uint256 target0, uint256 target1) =
            _previewMint(wrapper, scale, totalSupply, positions, sqrtPriceX96);
        actualLpAmount = Math.min(
            target0 == 0
                ? type(uint256).max
                : Math.mulDiv(amount0, scale, target0, Math.Rounding.Ceil),
            target1 == 0
                ? type(uint256).max
                : Math.mulDiv(amount1, scale, target1, Math.Rounding.Ceil)
        );
        (actualAmount0, actualAmount1) =
            _previewMint(wrapper, actualLpAmount, totalSupply, positions, sqrtPriceX96);
        while (actualAmount0 > amount0 || actualAmount1 > amount1) {
            actualLpAmount -= 1;
            (actualAmount0, actualAmount1) =
                _previewMint(wrapper, actualLpAmount, totalSupply, positions, sqrtPriceX96);
        }
    }

    function _previewMint(
        ILpWrapper wrapper,
        uint256 lpAmount,
        uint256 totalSupply,
        IAmmModule.AmmPosition[] memory positions,
        uint160 sqrtPriceX96
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        for (uint256 i = 0; i < positions.length; i++) {
            (uint256 amount0_, uint256 amount1_) = LpWrapper(address(wrapper)).calculateAmountsForLp(
                lpAmount, totalSupply, positions[i], sqrtPriceX96
            );
            amount0 += amount0_;
            amount1 += amount1_;
        }
    }

    function previewDeposit(
        ILpWrapper wrapper,
        uint256 amount0,
        uint256 amount1,
        uint256 slippageD9
    )
        public
        view
        returns (
            uint256 actualAmount0,
            uint256 actualAmount1,
            uint256 actualLpAmount,
            uint256 amount0Min,
            uint256 amount1Min
        )
    {
        (actualAmount0, actualAmount1, actualLpAmount) = previewDeposit(wrapper, amount0, amount1);
        (uint160 sqrtPriceX96,,,,,) = ICLPool(wrapper.pool()).slot0();
        uint256 priceX128 = Math.mulDiv(sqrtPriceX96, sqrtPriceX96, Q64);
        amount0Min =
            Math.mulDiv(actualAmount0 + Math.mulDiv(actualAmount1, Q128, priceX128), slippageD9, D9);
        amount1Min =
            Math.mulDiv(actualAmount1 + Math.mulDiv(actualAmount0, priceX128, Q128), slippageD9, D9);
        amount0Min = amount0Min >= actualAmount0 ? 0 : actualAmount0 - amount0Min;
        amount1Min = amount1Min >= actualAmount1 ? 0 : actualAmount1 - amount1Min;
    }
}
