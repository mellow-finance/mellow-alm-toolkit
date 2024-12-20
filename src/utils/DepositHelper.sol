// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./LpWrapper.sol";

contract DepositHelper {
    using SafeERC20 for IERC20;

    uint256 public constant SCALE = 1000 ether;
    uint256 public constant ALLOWED_ERROR = 100 wei;

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

        if (amount0 > actualAmount0 + ALLOWED_ERROR) {
            IERC20(depositParams.token0).safeTransfer(msg.sender, amount0 - actualAmount0);
        }

        if (amount1 > actualAmount1 + ALLOWED_ERROR) {
            IERC20(depositParams.token1).safeTransfer(msg.sender, amount1 - actualAmount1);
        }
    }

    function previewDeposit(ILpWrapper wrapper, uint256 amount0, uint256 amount1)
        public
        view
        returns (uint256 actualAmount0, uint256 actualAmount1, uint256 actualLpAmount)
    {
        (uint256 target0, uint256 target1) = wrapper.previewMint(SCALE);
        actualLpAmount = Math.min(
            target0 == 0 ? type(uint256).max : Math.mulDiv(amount0, SCALE, target0),
            target1 == 0 ? type(uint256).max : Math.mulDiv(amount1, SCALE, target1)
        );
        actualAmount0 =
            target0 == 0 ? 0 : Math.mulDiv(target0, actualLpAmount, SCALE, Math.Rounding.Ceil);
        actualAmount1 =
            target1 == 0 ? 0 : Math.mulDiv(target1, actualLpAmount, SCALE, Math.Rounding.Ceil);
    }
}
