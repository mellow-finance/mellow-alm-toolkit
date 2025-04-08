// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IDepositBalancer.sol";
import "../interfaces/utils/ILpWrapper.sol";
import "../interfaces/utils/IVeloDeployFactory.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

/**
 * @title DepositBalancer
 * @dev Handles deposits and withdrawals into Mellow ALM.
 * This contract abstracts the complexity of splitting assets, computing target amounts,
 * performing necessary swaps, and minting LP tokens with optimal capital efficiency.
 *
 * It integrates with LpWrapper contracts and pool factories to ensure consistent interaction with
 * managed liquidity positions, while enforcing safety checks and rebalancing logic.
 *
 * Key Features:
 * - Converts single-token deposits into dual-token liquidity for LP minting.
 * - Rebalances token proportions via internal swaps before minting.
 * - Supports withdrawals with optional single-token output via internal swapping.
 * - Enforces safety via non-reentrancy and authorization checks.
 *
 * Requirements:
 * - Only valid pools and wrappers should be used.
 * - Token balances and approvals must be properly handled by the caller.
 * - Tokens must conform to the ERC20 standard.
 */
contract DepositBalancer is IDepositBalancer, Context, ReentrancyGuard {
    using Math for uint256;
    using SafeERC20 for IERC20;

    IVeloDeployFactory public immutable factory;
    ICLFactory public immutable poolFactory;

    uint256 private immutable Q64 = 2 ** 64;
    uint256 private immutable Q128 = 2 ** 128;
    uint256 private immutable Q192 = 2 ** 192;

    constructor(address factory_, address poolFactory_) {
        factory = IVeloDeployFactory(factory_);
        poolFactory = ICLFactory(poolFactory_);
    }

    ///  @inheritdoc IDepositBalancer
    function deposit(
        address pool,
        address tokenIn,
        uint256 amountIn,
        address recipient,
        uint256 deadline
    )
        external
        nonReentrant
        returns (uint256 actualAmount0, uint256 actualAmount1, uint256 actualLpAmount)
    {
        address depositor = _msgSender();
        require(amountIn > 0, "Zero amountIn");
        address token0 = ICLPool(pool).token0();
        address token1 = ICLPool(pool).token1();
        uint256 tokenIdIn = tokenIn == token0 ? 0 : 1;
        IERC20(tokenIn).safeTransferFrom(depositor, address(this), amountIn);

        address lpWrapper = _lpWrapper(pool);

        (actualLpAmount, actualAmount0, actualAmount1) =
            _targetAmounts(lpWrapper, pool, tokenIdIn, amountIn);

        require(actualLpAmount > 0, "Zero lpAmount");

        if ((tokenIdIn == 0 && actualAmount1 > 0) || (tokenIdIn == 1 && actualAmount0 > 0)) {
            _swapAmounts(pool, tokenIn, tokenIdIn, tokenIdIn == 0 ? actualAmount0 : actualAmount1);
        }

        (actualAmount0, actualAmount1, actualLpAmount) =
            _mint(pool, actualLpAmount, token0, token1, recipient, deadline);

        _swapBackAndTransferRemaining(pool, token0, token1, tokenIdIn ^ 1, depositor);
    }

    ///  @inheritdoc IDepositBalancer
    function withdraw(
        address pool,
        uint256 lpAmount,
        address tokenTarget,
        address recipient,
        uint256 deadline
    ) external nonReentrant returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount) {
        address[2] memory token = [ICLPool(pool).token0(), ICLPool(pool).token1()];

        (amount0, amount1, actualLpAmount) =
            _burn(pool, lpAmount, tokenTarget == address(0) ? recipient : address(this), deadline);

        if (tokenTarget != address(0)) {
            require(tokenTarget == token[0] || tokenTarget == token[1], "Forbidden token");
            _swapBackAndTransferRemaining(
                pool, token[0], token[1], tokenTarget == token[0] ? 1 : 0, recipient
            );
        }
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata)
        external
    {
        ICLPool pool = ICLPool(msg.sender);
        address token0 = pool.token0();
        address token1 = pool.token1();

        require(
            msg.sender == poolFactory.getPool(token0, token1, pool.tickSpacing()), "forbidden pool"
        );

        if (amount0Delta > 0) {
            IERC20(token0).transfer(address(pool), uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            IERC20(token1).transfer(address(pool), uint256(amount1Delta));
        }
    }

    function _mint(
        address pool,
        uint256 lpAmount,
        address token0,
        address token1,
        address recipient,
        uint256 deadline
    ) internal returns (uint256 actualAmount0, uint256 actualAmount1, uint256 actualLpAmount) {
        address lpWrapper = _lpWrapper(pool);
        uint256 amount0 = IERC20(token0).balanceOf(address(this));
        uint256 amount1 = IERC20(token1).balanceOf(address(this));

        lpAmount = _fitLpAmount(lpWrapper, amount0, amount1, lpAmount);

        if (amount0 > 0) {
            IERC20(token0).safeIncreaseAllowance(address(lpWrapper), amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).safeIncreaseAllowance(address(lpWrapper), amount1);
        }

        return ILpWrapper(lpWrapper).mint(
            ILpWrapper.MintParams({
                lpAmount: lpAmount,
                amount0Max: amount0,
                amount1Max: amount1,
                recipient: recipient,
                deadline: deadline
            })
        );
    }

    function _burn(address pool, uint256 lpAmount, address recipient, uint256 deadline)
        internal
        returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount)
    {
        address lpWrapper = _lpWrapper(pool);
        address withdrawer = _msgSender();
        lpAmount = Math.min(IERC20(lpWrapper).balanceOf(withdrawer), lpAmount);
        IERC20(lpWrapper).safeTransferFrom(withdrawer, address(this), lpAmount);

        return ILpWrapper(lpWrapper).withdraw(lpAmount, 0, 0, recipient, deadline);
    }

    function _lpWrapper(address pool) internal view returns (address lpWrapper) {
        lpWrapper = factory.poolToWrapper(pool);
        require(lpWrapper != address(0), "No LpWrapper for pool");
    }

    function _targetAmounts(address lpWrapper, address pool, uint256 tokenIdIn, uint256 amountIn)
        internal
        view
        returns (uint256 lpAmount, uint256 targetAmount0, uint256 targetAmount1)
    {
        (uint160 sqrtPriceX96,,,,,) = ICLPool(pool).slot0();
        lpAmount = 1 ether;
        uint256[2] memory amounts = tokenIdIn == 0 ? [amountIn, 0] : [0, amountIn];
        (targetAmount0, targetAmount1) = ILpWrapper(lpWrapper).previewMint(lpAmount);
        uint256 capital = _calculateCapital(amounts[0], amounts[1], sqrtPriceX96);
        uint256 capitalTarget = _calculateCapital(targetAmount0, targetAmount1, sqrtPriceX96);

        lpAmount = lpAmount.mulDiv(capital, capitalTarget, Math.Rounding.Floor);
        targetAmount0 = targetAmount0.mulDiv(capital, capitalTarget, Math.Rounding.Floor);
        targetAmount1 = targetAmount1.mulDiv(capital, capitalTarget, Math.Rounding.Floor);
    }

    function _swapAmounts(address pool, address tokenIn, uint256 tokenIdIn, uint256 targetAmountIn)
        internal
    {
        uint256 amountIn = IERC20(tokenIn).balanceOf(address(this));
        require(targetAmountIn < amountIn, "Insufficient amount");

        amountIn = amountIn - targetAmountIn;
        IERC20(tokenIn).safeIncreaseAllowance(pool, amountIn);
        ICLPool(pool).swap(
            address(this),
            tokenIdIn == 0 ? true : false,
            int256(amountIn),
            tokenIdIn == 0 ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            abi.encode("")
        );
    }

    function _fitLpAmount(address lpWrapper, uint256 amount0, uint256 amount1, uint256 lpAmount)
        internal
        view
        returns (uint256)
    {
        (uint256 targetAmount0, uint256 targetAmount1) = ILpWrapper(lpWrapper).previewMint(lpAmount);

        bool lpAmountUpdated;
        do {
            lpAmountUpdated = false;
            if (targetAmount0 > amount0) {
                lpAmount = lpAmount.mulDiv(amount0, targetAmount0, Math.Rounding.Floor);
                lpAmountUpdated = true;
            }
            if (targetAmount1 > amount1) {
                lpAmount = lpAmount.mulDiv(amount1, targetAmount1, Math.Rounding.Floor);
                lpAmountUpdated = true;
            }
            if (lpAmountUpdated) {
                (targetAmount0, targetAmount1) = ILpWrapper(lpWrapper).previewMint(lpAmount);
            }
        } while (lpAmountUpdated);

        return lpAmount;
    }

    function _swapBackAndTransferRemaining(
        address pool,
        address token0,
        address token1,
        uint256 tokenIdIn,
        address recipient
    ) internal {
        address tokenIn = tokenIdIn == 0 ? token0 : token1;
        uint256 amountIn = IERC20(tokenIn).balanceOf(address(this));

        if (amountIn > 0) {
            _swapAmounts(pool, tokenIn, tokenIdIn, 0);
        }

        uint256 amount0 = IERC20(token0).balanceOf(address(this));
        uint256 amount1 = IERC20(token1).balanceOf(address(this));

        if (amount0 > 0) {
            IERC20(token0).safeTransfer(recipient, amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).safeTransfer(recipient, amount1);
        }
    }

    function _calculateCapital(uint256 amount0, uint256 amount1, uint256 sqrtPriceX96)
        internal
        pure
        returns (uint256)
    {
        if (sqrtPriceX96 < Q128) {
            return Math.mulDiv(amount0, sqrtPriceX96 * sqrtPriceX96, Q192) + amount1;
        } else {
            uint256 priceX128 = Math.mulDiv(sqrtPriceX96, sqrtPriceX96, Q64);
            return Math.mulDiv(amount0, priceX128, Q128) + amount1;
        }
    }
}
