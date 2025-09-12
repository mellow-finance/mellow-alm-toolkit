// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IDepositBalancer.sol";
import "./AccessControlCalls.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "src/libraries/PositionMath.sol";

contract DepositBalancer is IDepositBalancer, ReentrancyGuard, AccessControlCalls {
    using Math for uint256;
    using SafeERC20 for IERC20;

    ICore public immutable core;
    IAmmModule public immutable ammModule;
    IVeloDeployFactory public immutable factory;

    constructor(address factory_, address core_) {
        core = ICore(core_);
        ammModule = core.ammModule();
        factory = IVeloDeployFactory(factory_);
    }

    ///  @inheritdoc IDepositBalancer
    function initialize(address admin_) external initializer {
        __AccessControlCalls_init(admin_);
    }

    /// @dev Fallback to redirect incoming swap callbacks into the AMM module.
    fallback() external {
        address pool = _msgSender();
        if (!ammModule.isPool(pool)) {
            revert Forbidden();
        }

        Address.functionDelegateCall(
            address(ammModule),
            abi.encodeWithSelector(IAmmModule.poolCallback.selector, pool, msg.sig, msg.data[4:])
        );
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
        SwapData memory swapData
    ) external nonReentrant returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount) {
        if (amount == 0) {
            revert ZeroAmount();
        }

        address pool = ILpWrapper(lpWrapper).pool();
        (address token0, address token1) = ammModule.getPoolTokens(pool);

        IERC20(tokenIn).safeTransferFrom(_msgSender(), address(this), amount);

        if (token0 != tokenIn && token1 != tokenIn) {
            revert Forbidden();
        }

        bool zeroForOne = tokenIn == token0 ? true : false;
        address tokenOut = zeroForOne ? token1 : token0;

        /// @dev first optimistic estimation of amounts distribution among tokens
        (actualLpAmount, amount0, amount1) =
            previewDepositAmounts(lpWrapper, zeroForOne ? amount : 0, zeroForOne ? 0 : amount);

        if (actualLpAmount == 0) {
            revert ZeroLpAmount();
        }

        if ((zeroForOne && amount1 != 0) || (!zeroForOne && amount0 != 0)) {
            _swapOnTarget(tokenIn, tokenOut, amount, swapData);
        }

        /// @dev directly returns actual deposited amounts
        (amount0, amount1, actualLpAmount) = _mint(lpWrapper, token0, token1, recipient, deadline);

        /// @dev swaps any remaining tokens back to the deposit token and sweeps remaining funds in favor of the sender
        Address.functionDelegateCall(
            address(ammModule),
            abi.encodeWithSelector(
                IAmmModule.swapOnPool.selector,
                pool,
                !zeroForOne,
                IERC20(tokenOut).balanceOf(address(this))
            )
        );

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
        SwapData memory swapData
    ) external nonReentrant returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount) {
        address pool = ILpWrapper(lpWrapper).pool();

        if (token == address(0)) {
            /// @dev directly sends assets to recipient in case of token = address(0), nothing remains in the contract
            return _burn(lpWrapper, lpAmount, recipient, deadline);
        } else {
            (address token0, address token1) = ammModule.getPoolTokens(pool);

            if (token != token0 && token != token1) {
                revert Forbidden();
            }

            (amount0, amount1, actualLpAmount) = _burn(lpWrapper, lpAmount, address(this), deadline);
            address tokenIn = token == token0 ? token1 : token0;
            uint256 amountIn = IERC20(tokenIn).balanceOf(address(this));

            if (amountIn > 0) {
                _swapOnTarget(tokenIn, token, amountIn, swapData);
            }
            /// @dev sweep any remaining tokens in favor of the recipient: all assets on the contract are actually received while withdrawn
            (amount0, amount1) = _emptyBalances(token0, token1, recipient);
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
        uint160 sqrtPriceX96 = ammModule.getSqrtPriceX96(ILpWrapper(lpWrapper).pool());

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
        returns (uint256 amount0, uint256 amount1)
    {
        return ILpWrapper(lpWrapper).previewBurn(lpAmount);
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

    function _swapOnTarget(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        SwapData memory swapData
    ) internal {
        _requireAllowedCall(swapData.target, swapData.data);

        if (swapData.target == address(0)) {
            revert AddressZero();
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
