// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../interfaces/modules/velo/IDepositBalancer.sol";
import "../../interfaces/utils/ILpWrapper.sol";
import "../../interfaces/utils/IVeloDeployFactory.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

contract DepositBalancer is IDepositBalancer, Context, ReentrancyGuard {
    using Math for uint256;
    using SafeERC20 for IERC20;

    ICore public immutable core;
    IOracle public immutable oracle;
    ICLFactory public immutable poolFactory;
    IVeloDeployFactory public immutable factory;

    uint256 public constant D9 = 10 ** 9;

    constructor(address factory_, address poolFactory_, address core_) {
        core = ICore(core_);
        oracle = core.oracle();
        factory = IVeloDeployFactory(factory_);
        poolFactory = ICLFactory(poolFactory_);
    }

    /* ----------------------------------------------------------------------------------
    *                                   External mutable functions
    ---------------------------------------------------------------------------------- */

    ///  @inheritdoc IDepositBalancer
    function deposit(
        address lpWrapper,
        address tokenIn,
        uint256 amount,
        address recipient,
        uint256 deadline,
        bytes memory data
    ) external nonReentrant returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount) {
        _ensureNoMEV(lpWrapper);

        if (amount == 0) {
            revert ZeroAmount();
        }

        address pool = ILpWrapper(lpWrapper).pool();
        address token0 = ICLPool(pool).token0();
        address token1 = ICLPool(pool).token1();

        if (token0 != tokenIn && token1 != tokenIn) {
            revert Forbidden();
        }

        bool zeroForOne = tokenIn == token0 ? true : false;

        /// @dev first optimistic estimation of amounts distribution among tokens
        (actualLpAmount, amount0, amount1) =
            previewDepositAmounts(lpWrapper, zeroForOne ? amount : 0, zeroForOne ? 0 : amount);

        if (actualLpAmount == 0) {
            revert ZeroLpAmount();
        }

        IERC20(tokenIn).safeTransferFrom(_msgSender(), address(this), amount);

        address tokenOut = zeroForOne ? token1 : token0;
        if (data.length > 0x60) {
            _swapOnTarget(tokenIn, tokenOut, amount, data);
        } else {
            if ((zeroForOne && amount1 > 0) || (!zeroForOne && amount0 > 0)) {
                uint256 balance = IERC20(tokenIn).balanceOf(address(this));
                uint256 amountDesired = zeroForOne ? amount0 : amount1;
                if (balance < amountDesired) {
                    revert InsufficientAmount();
                }
                _swapOnPool(pool, zeroForOne, balance - amountDesired);
            }
        }

        /// @dev directly returns actual deposited amounts
        (amount0, amount1, actualLpAmount) = _mint(lpWrapper, token0, token1, recipient, deadline);

        /// @dev swaps any remaining tokens back to the deposit token and sweeps remaining funds in favor of the sender
        _swapOnPool(pool, !zeroForOne, IERC20(tokenOut).balanceOf(address(this)));

        /// @dev sweep any remaining tokens in favor of the recipient
        _emptyBalances(token0, token1, recipient);
    }

    ///  @inheritdoc IDepositBalancer
    function withdraw(
        address lpWrapper,
        address token,
        uint256 lpAmount,
        address recipient,
        uint256 deadline,
        bytes memory data
    ) external nonReentrant returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount) {
        address pool = ILpWrapper(lpWrapper).pool();

        if (token == address(0)) {
            /// @dev directly sends assets to recipient in case of token = address(0), nothing remains in the contract
            return _burn(lpWrapper, lpAmount, recipient, deadline);
        } else {
            _ensureNoMEV(lpWrapper);

            address token0 = ICLPool(pool).token0();
            address token1 = ICLPool(pool).token1();

            if (token != token0 && token != token1) {
                revert Forbidden();
            }

            (amount0, amount1, actualLpAmount) = _burn(lpWrapper, lpAmount, address(this), deadline);
            address tokenIn = token == token0 ? token1 : token0;
            uint256 amountIn = IERC20(tokenIn).balanceOf(address(this));

            if (IERC20(tokenIn).balanceOf(address(this)) > 0) {
                if (data.length > 0x60) {
                    //uint256 amountIn = token == token0 ? amount1 : amount0;
                    _swapOnTarget(tokenIn, token, amountIn, data);
                } else {
                    /// @dev swaps any amount of counterpart token
                    _swapOnPool(pool, tokenIn == token0, amountIn);
                }
            }
            /// @dev sweep any remaining tokens in favor of the recipient: all assets on the contract are actually received while withdrawn
            (amount0, amount1) = _emptyBalances(token0, token1, recipient);
        }
    }

    ///  @inheritdoc ICLSwapCallback
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata)
        external
    {
        address pool = _msgSender();
        address token0 = ICLPool(pool).token0();
        address token1 = ICLPool(pool).token1();

        if (pool != poolFactory.getPool(token0, token1, ICLPool(pool).tickSpacing())) {
            revert Forbidden();
        }

        if (amount0Delta > 0) {
            IERC20(token0).transfer(pool, uint256(amount0Delta));
        }

        if (amount1Delta > 0) {
            IERC20(token1).transfer(pool, uint256(amount1Delta));
        }
    }

    /* ----------------------------------------------------------------------------------
    *                                   Public view functions
    ---------------------------------------------------------------------------------- */

    ///  @inheritdoc IDepositBalancer
    function previewDepositAmounts(address lpWrapper, uint256 amount0, uint256 amount1)
        public
        view
        returns (uint256 lpAmount, uint256 targetAmount0, uint256 targetAmount1)
    {
        (targetAmount0, targetAmount1) = ILpWrapper(lpWrapper).previewMint(1 ether);
        (uint160 sqrtPriceX96,) =
            ILpWrapper(lpWrapper).oracle().getOraclePrice(ILpWrapper(lpWrapper).pool());

        uint256 capital = PositionMath.calculateCapital(amount0, amount1, sqrtPriceX96);
        uint256 capitalTarget =
            PositionMath.calculateCapital(targetAmount0, targetAmount1, sqrtPriceX96);
        targetAmount0 = targetAmount0.mulDiv(capital, capitalTarget);
        targetAmount1 = targetAmount1.mulDiv(capital, capitalTarget);

        lpAmount = ILpWrapper(lpWrapper).previewDeposit(targetAmount0, targetAmount1);
        (targetAmount0, targetAmount1) = ILpWrapper(lpWrapper).previewMint(lpAmount);
    }

    ///  @inheritdoc IDepositBalancer
    function previewWithdrawAmounts(address lpWrapper, uint256 lpAmount)
        public
        view
        returns (uint256, uint256)
    {
        return ILpWrapper(lpWrapper).previewBurn(lpAmount);
    }

    /* ----------------------------------------------------------------------------------
    *                                   Internal view functions
    ---------------------------------------------------------------------------------- */

    function _ensureNoMEV(address lpWrapper) internal view {
        address pool = ILpWrapper(lpWrapper).pool();
        ICore.ManagedPositionInfo memory position =
            core.managedPositionAt(ILpWrapper(lpWrapper).positionId());
        oracle.ensureNoMEV(pool, position.securityParams);
    }

    /* ----------------------------------------------------------------------------------
    *                                   Internal mutable functions
    ---------------------------------------------------------------------------------- */

    function _mint(
        address lpWrapper,
        address token0,
        address token1,
        address recipient,
        uint256 deadline
    ) internal returns (uint256 actualAmount0, uint256 actualAmount1, uint256 actualLpAmount) {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        actualLpAmount = ILpWrapper(lpWrapper).previewDeposit(balance0, balance1);

        if (actualLpAmount == 0) {
            revert ZeroLpAmount();
        }

        if (balance0 > 0) {
            IERC20(token0).safeIncreaseAllowance(lpWrapper, balance0);
        }
        if (balance1 > 0) {
            IERC20(token1).safeIncreaseAllowance(lpWrapper, balance1);
        }

        return ILpWrapper(lpWrapper).mint(
            ILpWrapper.MintParams({
                lpAmount: actualLpAmount,
                amount0Max: balance0,
                amount1Max: balance1,
                recipient: recipient,
                deadline: deadline
            })
        );
    }

    function _burn(address lpWrapper, uint256 lpAmount, address recipient, uint256 deadline)
        internal
        returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount)
    {
        address withdrawer = _msgSender();

        if (IERC20(lpWrapper).balanceOf(withdrawer) < lpAmount) {
            revert InsufficientLpAmount();
        }

        IERC20(lpWrapper).safeTransferFrom(withdrawer, address(this), lpAmount);

        return ILpWrapper(lpWrapper).withdraw(lpAmount, 0, 0, recipient, deadline);
    }

    function _swapOnPool(address pool, bool zeroForOne, uint256 amountIn) internal {
        if (amountIn == 0) {
            return;
        }
        ICLPool(pool).swap(
            address(this),
            zeroForOne,
            int256(amountIn),
            zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            ""
        );
    }

    function _swapOnTarget(address tokenIn, address tokenOut, uint256 amountIn, bytes memory data)
        internal
    {
        SwapData memory swapData = abi.decode(data, (SwapData));

        if (swapData.target == address(0)) {
            revert ZeroAddress();
        }

        if (swapData.data.length < 4) {
            revert ZeroSwapData();
        }

        if (amountIn == 0) {
            revert ZeroAmount();
        }

        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));

        IERC20(tokenIn).safeIncreaseAllowance(swapData.target, amountIn);

        (bool success, bytes memory result) = swapData.target.call(swapData.data);
        if (!success) {
            revert SwapFailed(swapData.target, swapData.data, result);
        }

        uint256 balanceAfter = IERC20(tokenOut).balanceOf(address(this));
        if (balanceAfter < balanceBefore && balanceAfter - balanceBefore < swapData.minReturn) {
            revert InsufficientAmount();
        }
    }

    function _emptyBalances(address token0, address token1, address recipient)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = IERC20(token0).balanceOf(address(this));
        amount1 = IERC20(token1).balanceOf(address(this));

        if (amount0 > 0) {
            IERC20(token0).safeTransfer(recipient, amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).safeTransfer(recipient, amount1);
        }
    }
}
