// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../Imports.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "src/interfaces/utils/IVeloDeployFactory.sol";
import "src/utils/DepositBalancer.sol";

contract DepositBalancerTest is Test {
    ICore immutable core = ICore(0x0000000cE42D4981513060aB7E50B9e5e2D19AF1);
    address immutable factory = 0xE46EC96906fc6dEC53De25F013639969Fe10180d;
    address immutable poolFactory = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F;
    address depositor = 0xf89d7b9c864f589bbF53a82105107622B35EaA40; // Bybit HW
    address USDC_WETH = 0x478946BcD4a5a22b316470F5486fAfb928C0bA25;
    address WETH_OP = 0x84a67CD00EB244edCa2288346ADD251A783243c8;
    address USDC_USDC = 0x2FA71491F8070FA644d97b4782dB5734854c0f6F;
    address USDC_USDT = 0x84Ce89B4f6F67E523A81A82f9f2F14D84B726F6B;
    DepositBalancer depositBalancer;

    function setUp() public {
        depositBalancer = new DepositBalancer(factory, poolFactory);
    }

    function testDepositBalancerOneSide() public {
        testDepositBalancer1(USDC_WETH);
        testDepositBalancer2(USDC_WETH);
    }

    function testDepositBalancerTwoSide() public {
        testDepositBalancer1(WETH_OP);
        testDepositBalancer2(WETH_OP);
    }

    function testDepositBalancerTamper1() public {
        testDepositBalancer1(USDC_USDC);
        testDepositBalancer2(USDC_USDC);
    }

    function testDepositBalancerTamper2() public {
        testDepositBalancer1(USDC_USDT);
        testDepositBalancer2(USDC_USDT);
    }

    function testWithdrawRegular() public {
        testDepositBalancerWithdraw(USDC_WETH);
        testDepositBalancerWithdraw(WETH_OP);
        testDepositBalancerWithdraw(USDC_USDC);
        testDepositBalancerWithdraw(USDC_USDT);
    }

    function testDepositBalancer1(address poolAddress) internal {
        ICLPool pool = ICLPool(poolAddress);
        address lpWrapper = IVeloDeployFactory(factory).poolToWrapper(address(pool));

        {
            address recipient = address(0xfedcba987654321);
            address token = pool.token0();

            uint256 lpBalanceRecipientBefore = IERC20(lpWrapper).balanceOf(recipient);
            uint256 lpBalanceDepositorBefore = IERC20(lpWrapper).balanceOf(depositor);

            (,, uint256 actualLpAmount) =
                _deposit(pool, recipient, token, 10 ** ERC20(token).decimals());

            uint256 lpBalanceRecipientAfter = IERC20(lpWrapper).balanceOf(recipient);
            uint256 lpBalanceDepositorAfter = IERC20(lpWrapper).balanceOf(depositor);

            require(
                lpBalanceRecipientAfter - lpBalanceRecipientBefore == actualLpAmount,
                "depositor lp balance"
            );
            require(lpBalanceDepositorAfter == lpBalanceDepositorBefore, "depositor lp balance");
        }
        {
            address recipient = address(0xfedcba987654321);
            address token = pool.token1();

            uint256 lpBalanceRecipientBefore = IERC20(lpWrapper).balanceOf(recipient);
            uint256 lpBalanceDepositorBefore = IERC20(lpWrapper).balanceOf(depositor);

            (,, uint256 actualLpAmount) =
                _deposit(pool, recipient, token, 10 ** ERC20(token).decimals());

            uint256 lpBalanceRecipientAfter = IERC20(lpWrapper).balanceOf(recipient);
            uint256 lpBalanceDepositorAfter = IERC20(lpWrapper).balanceOf(depositor);

            require(
                lpBalanceRecipientAfter - lpBalanceRecipientBefore == actualLpAmount,
                "depositor lp balance"
            );
            require(lpBalanceDepositorAfter == lpBalanceDepositorBefore, "depositor lp balance");
        }
    }

    function testDepositBalancer2(address poolAddress) internal {
        ICLPool pool = ICLPool(poolAddress);
        address lpWrapper = IVeloDeployFactory(factory).poolToWrapper(address(pool));
        {
            uint256 lpBalanceRecipientBefore = IERC20(lpWrapper).balanceOf(depositor);
            address token = pool.token0();

            (,, uint256 actualLpAmount) =
                _deposit(pool, depositor, token, 10 ** ERC20(token).decimals());

            uint256 lpBalanceRecipientAfter = IERC20(lpWrapper).balanceOf(depositor);

            require(
                lpBalanceRecipientAfter - lpBalanceRecipientBefore == actualLpAmount,
                "depositor lp balance"
            );
        }
        {
            uint256 lpBalanceRecipientBefore = IERC20(lpWrapper).balanceOf(depositor);
            address token = pool.token1();

            (,, uint256 actualLpAmount) =
                _deposit(pool, depositor, token, 10 ** ERC20(token).decimals());

            uint256 lpBalanceRecipientAfter = IERC20(lpWrapper).balanceOf(depositor);

            require(
                lpBalanceRecipientAfter - lpBalanceRecipientBefore == actualLpAmount,
                "depositor lp balance"
            );
        }
    }

    function testDepositBalancerWithdraw(address poolAddress) internal {
        ICLPool pool = ICLPool(poolAddress);
        address lpWrapper = IVeloDeployFactory(factory).poolToWrapper(address(pool));

        address token = pool.token0();

        _deposit(pool, depositor, token, 10 ** ERC20(token).decimals());

        uint256 lpAmount = IERC20(lpWrapper).balanceOf(depositor);
        uint256 amount0;
        uint256 amount1;
        {
            uint256 lpAmountWithdraw = lpAmount / 3;
            uint256 lpBalanceRecipientBefore = IERC20(lpWrapper).balanceOf(depositor);
            (amount0, amount1,) = _withdraw(pool, depositor, lpAmount / 3, address(0), false);
            uint256 lpBalanceRecipientAfter = IERC20(lpWrapper).balanceOf(depositor);
            require(
                lpBalanceRecipientBefore - lpBalanceRecipientAfter == lpAmountWithdraw,
                "depositor lp balance"
            );
        }
        {
            uint256 lpAmountWithdraw = lpAmount / 3;
            uint256 lpBalanceRecipientBefore = IERC20(lpWrapper).balanceOf(depositor);
            uint256 amount1Before = IERC20(pool.token1()).balanceOf(depositor);
            _withdraw(pool, depositor, lpAmountWithdraw, pool.token0(), amount1 > 0);
            uint256 lpBalanceRecipientAfter = IERC20(lpWrapper).balanceOf(depositor);
            uint256 amount1After = IERC20(pool.token1()).balanceOf(depositor);
            require(
                lpBalanceRecipientBefore - lpBalanceRecipientAfter == lpAmountWithdraw,
                "depositor lp balance"
            );
            require(amount1After == amount1Before, "amount1");
        }
        {
            uint256 lpAmountWithdraw = IERC20(lpWrapper).balanceOf(depositor);
            uint256 lpBalanceRecipientBefore = IERC20(lpWrapper).balanceOf(depositor);
            uint256 amount0Before = IERC20(pool.token0()).balanceOf(depositor);
            _withdraw(pool, depositor, lpAmountWithdraw, pool.token1(), amount0 > 0);
            uint256 lpBalanceRecipientAfter = ERC20(lpWrapper).balanceOf(depositor);
            uint256 amount0After = IERC20(pool.token0()).balanceOf(depositor);
            require(
                lpBalanceRecipientBefore - lpBalanceRecipientAfter == lpAmountWithdraw,
                "depositor lp balance"
            );
            require(amount0After == amount0Before, "amount0");
        }

        require(IERC20(lpWrapper).balanceOf(depositor) == 0, "non zero LP");
    }

    function _deposit(ICLPool pool, address recipient, address token, uint256 amount)
        internal
        returns (uint256 actualAmount0, uint256 actualAmount1, uint256 actualLpAmount)
    {
        if (IERC20(token).balanceOf(depositor) < amount) {
            console2.log("balance", depositor, IERC20(token).balanceOf(depositor));
            console2.log("   deal", ERC20(token).symbol(), amount);
            deal(token, depositor, amount);
        }

        vm.startPrank(depositor);
        IERC20(token).approve(address(depositBalancer), amount);

        uint256 balanceBefore = IERC20(token).balanceOf(depositor);
        (actualAmount0, actualAmount1, actualLpAmount) =
            depositBalancer.deposit(address(pool), token, amount, recipient, type(uint256).max);
        uint256 balanceAfter = IERC20(token).balanceOf(depositor);

        console2.log("deposited", actualAmount0, actualAmount1);

        require(balanceBefore > balanceAfter, "no deposit");
        require(balanceBefore - balanceAfter <= amount, "too much");
        //assertApproxEqRel(balanceBefore - balanceAfter, amount, 5e16, "slippage"); // 5% slippage
        _checkZeroRemaining(address(depositBalancer), pool.token0(), pool.token1());
    }

    function _withdraw(
        ICLPool pool,
        address recipient,
        uint256 lpAmount,
        address tokenTarget,
        bool expectSwap
    ) internal returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount) {
        address lpWrapper = IVeloDeployFactory(factory).poolToWrapper(address(pool));

        vm.startPrank(depositor);
        IERC20(lpWrapper).approve(address(depositBalancer), lpAmount);

        vm.recordLogs();
        (amount0, amount1, actualLpAmount) = depositBalancer.withdraw(
            address(pool), lpAmount, tokenTarget, recipient, type(uint256).max
        );
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bool swapEmitted = false;
        bytes32 swapTopic = 0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == swapTopic) {
                swapEmitted = true;
                break;
            }
        }

        require(expectSwap == swapEmitted, "Unexpected swap event");
        _checkZeroRemaining(address(depositBalancer), pool.token0(), pool.token1());
    }

    function _checkZeroRemaining(address account, address token0, address token1) internal view {
        require(IERC20(token0).balanceOf(account) == 0, "non zero balance of token0");
        require(IERC20(token1).balanceOf(account) == 0, "non zero balance of token1");
    }
}
