// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Fixture.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "src/interfaces/utils/IVeloDeployFactory.sol";
import "src/utils/DepositBalancer.sol";

contract DepositBalancerTest is Fixture {
    using Math for uint256;

    DeployScript.CoreDeployment contracts;

    ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));

    address admin = vm.addr(uint256(keccak256("admin")));

    address depositor = vm.addr(uint256(keccak256("depositor")));
    address recipient = vm.addr(uint256(keccak256("recipient")));

    ICore core;
    address lpWrapperFactory;
    DepositBalancer depositBalancer;

    function setUp() public {
        deal(Constants.OPTIMISM_WETH, address(this), type(uint256).max);
        deal(Constants.OPTIMISM_OP, address(this), type(uint256).max);

        deal(Constants.OPTIMISM_WETH, depositor, 1e20 ether);
        deal(Constants.OPTIMISM_OP, depositor, 1e20 ether);

        contracts = deployContracts();
        core = ICore(contracts.core);
        lpWrapperFactory = address(contracts.deployFactory);

        int24 ts = pool.tickSpacing();
        (, int24 tick,,,,) = pool.slot0();
        int24 spot = (tick / ts) * ts;

        /// @dev Mint huge liquidity around +-100k ticks
        mint(
            Constants.OPTIMISM_WETH,
            Constants.OPTIMISM_OP,
            ts,
            spot - 10 * ts,
            spot + 10 * ts,
            1e32,
            pool,
            address(this)
        );

        depositBalancer = new DepositBalancer(lpWrapperFactory, address(core));
        depositBalancer.initialize(admin);

        vm.prank(admin);
        AccessControlCalls(address(depositBalancer)).allowTargetCall(
            address(pool), ICLPoolActions.swap.selector
        );
    }

    function testDepositLazy(bool isToken0, uint96 amount) public {
        vm.assume(amount > 1e12 && amount < 1e6 ether);
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.LazySyncing, contracts);

        vm.startPrank(params.lpWrapperManager);
        lpWrapper.setTotalSupplyLimit(type(uint256).max);
        vm.stopPrank();

        address token = isToken0 ? Constants.OPTIMISM_WETH : Constants.OPTIMISM_OP;
        _deposit(recipient, token, amount);
    }

    function testDepositTamper(bool isToken0, uint96 amount) public {
        vm.assume(amount > 1e12 && amount < 1e6 ether);
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.Tamper, contracts);

        vm.startPrank(params.lpWrapperManager);
        lpWrapper.setTotalSupplyLimit(type(uint256).max);
        vm.stopPrank();

        address token = isToken0 ? Constants.OPTIMISM_WETH : Constants.OPTIMISM_OP;
        _deposit(recipient, token, amount);
    }

    function testDepositLazy2() external {
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.LazySyncing, contracts);

        vm.prank(params.lpWrapperManager);
        lpWrapper.setTotalSupplyLimit(type(uint256).max);

        {
            uint256 positionId = lpWrapper.positionId();
            ICore.ManagedPositionInfo memory position = core.managedPositionAt(positionId);

            vm.prank(params.lpWrapperManager);
            lpWrapper.setPositionParams(
                position.slippageD9,
                position.callbackParams,
                position.strategyParams,
                abi.encode(
                    IVeloOracle.SecurityParams({
                        lookback: 1,
                        maxAge: 1 seconds,
                        maxAllowedDelta: 10000,
                        extraData: ""
                    })
                )
            );
        }

        core = contracts.core;
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(lpWrapper.positionId());
        IVeloAmmModule ammModule = contracts.ammModule;
        IAmmModule.AmmPosition[] memory positions =
            new IAmmModule.AmmPosition[](info.ammPositionIds.length);
        for (uint256 index = 0; index < info.ammPositionIds.length; index++) {
            uint256 tokenId = info.ammPositionIds[index];
            positions[index] = ammModule.getAmmPosition(tokenId);
        }
        uint160[] memory sqrtPriceX96Check = new uint160[](2);
        sqrtPriceX96Check[0] = TickMath.getSqrtRatioAtTick(positions[0].tickUpper + 1);
        sqrtPriceX96Check[1] = TickMath.getSqrtRatioAtTick(positions[0].tickLower - 1);

        for (uint256 index = 0; index < sqrtPriceX96Check.length + 1; index++) {
            if (index > 0) {
                movePrice(pool, sqrtPriceX96Check[index - 1]);
            }
            {
                uint256 lpBalanceRecipientBefore = IERC20(lpWrapper).balanceOf(depositor);
                address token = pool.token0();
                uint256 amount = 10 ** ERC20(token).decimals();

                (,, uint256 actualLpAmount) = _deposit(depositor, token, amount);

                uint256 lpBalanceRecipientAfter = IERC20(lpWrapper).balanceOf(depositor);

                require(
                    lpBalanceRecipientAfter - lpBalanceRecipientBefore == actualLpAmount,
                    "depositor lp balance"
                );
            }
            {
                uint256 lpBalanceRecipientBefore = IERC20(lpWrapper).balanceOf(depositor);
                address token = pool.token1();
                uint256 amount = 10 ** ERC20(token).decimals();

                (,, uint256 actualLpAmount) = _deposit(depositor, token, amount);

                uint256 lpBalanceRecipientAfter = IERC20(lpWrapper).balanceOf(depositor);

                require(
                    lpBalanceRecipientAfter - lpBalanceRecipientBefore == actualLpAmount,
                    "depositor lp balance"
                );
            }
        }
    }

    function testDepositTamper2() external {
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.Tamper, contracts);

        vm.prank(params.lpWrapperManager);
        lpWrapper.setTotalSupplyLimit(type(uint256).max);

        {
            uint256 positionId = lpWrapper.positionId();
            ICore.ManagedPositionInfo memory position = core.managedPositionAt(positionId);

            vm.prank(params.lpWrapperManager);
            lpWrapper.setPositionParams(
                position.slippageD9,
                position.callbackParams,
                position.strategyParams,
                abi.encode(
                    IVeloOracle.SecurityParams({
                        lookback: 1,
                        maxAge: 1 seconds,
                        maxAllowedDelta: 10000,
                        extraData: ""
                    })
                )
            );
        }

        core = contracts.core;
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(lpWrapper.positionId());
        IVeloAmmModule ammModule = contracts.ammModule;
        IAmmModule.AmmPosition[] memory positions =
            new IAmmModule.AmmPosition[](info.ammPositionIds.length);
        for (uint256 index = 0; index < info.ammPositionIds.length; index++) {
            uint256 tokenId = info.ammPositionIds[index];
            positions[index] = ammModule.getAmmPosition(tokenId);
        }
        uint160[] memory sqrtPriceX96Check = new uint160[](4);
        sqrtPriceX96Check[0] = TickMath.getSqrtRatioAtTick(positions[0].tickUpper + 1);
        sqrtPriceX96Check[1] = TickMath.getSqrtRatioAtTick(positions[0].tickLower - 1);
        sqrtPriceX96Check[2] = TickMath.getSqrtRatioAtTick(positions[1].tickUpper + 1);
        sqrtPriceX96Check[3] = TickMath.getSqrtRatioAtTick(positions[1].tickLower - 1);

        for (uint256 index = 0; index < sqrtPriceX96Check.length + 1; index++) {
            if (index > 0) {
                movePrice(pool, sqrtPriceX96Check[index - 1]);
            }
            {
                uint256 lpBalanceRecipientBefore = IERC20(lpWrapper).balanceOf(depositor);
                address token = pool.token0();
                uint256 amount = 10 ** ERC20(token).decimals();

                (,, uint256 actualLpAmount) = _deposit(depositor, token, amount);

                uint256 lpBalanceRecipientAfter = IERC20(lpWrapper).balanceOf(depositor);

                require(
                    lpBalanceRecipientAfter - lpBalanceRecipientBefore == actualLpAmount,
                    "depositor lp balance"
                );
            }
            {
                uint256 lpBalanceRecipientBefore = IERC20(lpWrapper).balanceOf(depositor);
                address token = pool.token1();
                uint256 amount = 10 ** ERC20(token).decimals();

                (,, uint256 actualLpAmount) = _deposit(depositor, token, amount);

                uint256 lpBalanceRecipientAfter = IERC20(lpWrapper).balanceOf(depositor);

                require(
                    lpBalanceRecipientAfter - lpBalanceRecipientBefore == actualLpAmount,
                    "depositor lp balance"
                );
            }
        }
    }

    function testDepositSwapOnTarget() external {
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.Tamper, contracts);

        {
            address token = pool.token0();
            uint256 amount = 10 ** ERC20(token).decimals();
            vm.startPrank(depositor);
            IERC20(token).approve(address(depositBalancer), amount);

            uint256 balanceBefore = IERC20(token).balanceOf(depositor);
            (uint256 lpAmount, uint256 targetAmount0,) =
                depositBalancer.previewDepositAmounts(address(lpWrapper), amount, 0);

            bytes memory callData = abi.encodeWithSelector(
                ICLPoolActions.swap.selector,
                address(depositBalancer),
                true,
                amount - targetAmount0,
                TickMath.MIN_SQRT_RATIO + 1,
                ""
            );
            IDepositBalancer.SwapData memory swapData =
                IDepositBalancer.SwapData({minReturn: 0, target: address(pool), data: callData});

            console2.log("try deposit", ERC20(token).symbol(), amount);
            uint256 lpAmountBefore = IERC20(address(lpWrapper)).balanceOf(recipient);

            (,, uint256 actualLpAmount) = depositBalancer.deposit(
                address(lpWrapper), token, amount, recipient, type(uint256).max, swapData
            );
            vm.stopPrank();

            uint256 balanceAfter = IERC20(token).balanceOf(depositor);
            uint256 lpAmountAfter = IERC20(lpWrapper).balanceOf(recipient);

            require(lpAmountAfter - lpAmountBefore == actualLpAmount, "depositor lp balance");
            assertApproxEqRel(lpAmount, actualLpAmount, 1e15, "depositor actual lp");
            assertApproxEqRel(balanceBefore - balanceAfter, amount, 1e15, "depositor amount");
        }
        {
            address token = pool.token1();
            uint256 amount = 10 ** ERC20(token).decimals();
            vm.startPrank(depositor);
            IERC20(token).approve(address(depositBalancer), amount);

            uint256 balanceBefore = IERC20(token).balanceOf(depositor);
            (uint256 lpAmount,, uint256 targetAmount1) =
                depositBalancer.previewDepositAmounts(address(lpWrapper), 0, amount);

            bytes memory callData = abi.encodeWithSelector(
                ICLPoolActions.swap.selector,
                address(depositBalancer),
                false,
                amount - targetAmount1,
                TickMath.MAX_SQRT_RATIO - 1,
                ""
            );
            IDepositBalancer.SwapData memory swapData =
                IDepositBalancer.SwapData({minReturn: 0, target: address(pool), data: callData});

            console2.log("try deposit", ERC20(token).symbol(), amount);

            uint256 lpAmountBefore = IERC20(address(lpWrapper)).balanceOf(recipient);
            (,, uint256 actualLpAmount) = depositBalancer.deposit(
                address(lpWrapper), token, amount, recipient, type(uint256).max, swapData
            );

            uint256 balanceAfter = IERC20(token).balanceOf(depositor);
            uint256 lpAmountAfter = IERC20(lpWrapper).balanceOf(recipient);
            require(lpAmountAfter - lpAmountBefore == actualLpAmount, "depositor lp balance");
            assertApproxEqRel(lpAmount, actualLpAmount, 1e15, "depositor actual lp");
            assertApproxEqRel(balanceBefore - balanceAfter, amount, 1e15, "depositor amount");
        }
    }

    function testDepositBalancerWithdraw() external {
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.Tamper, contracts);

        address token = pool.token0();

        (uint256 actualAmount0, uint256 actualAmount1,) =
            _deposit(depositor, token, 10 ** ERC20(token).decimals());

        uint256 lpAmount = IERC20(lpWrapper).balanceOf(depositor);
        uint256 amount0;
        uint256 amount1;
        {
            uint256 lpAmountWithdraw = lpAmount / 3;
            uint256 lpBalanceRecipientBefore = IERC20(lpWrapper).balanceOf(depositor);
            (amount0, amount1,) = _withdraw(depositor, lpAmountWithdraw, address(0), false);
            uint256 lpBalanceRecipientAfter = IERC20(lpWrapper).balanceOf(depositor);
            require(
                lpBalanceRecipientBefore - lpBalanceRecipientAfter == lpAmountWithdraw,
                "depositor lp balance"
            );
            assertApproxEqAbs(amount0, actualAmount0 / 3, 1, "amount0");
            assertApproxEqAbs(amount1, actualAmount1 / 3, 1, "amount1");
        }
        {
            uint256 lpAmountWithdraw = lpAmount / 3;
            uint256 lpBalanceRecipientBefore = IERC20(lpWrapper).balanceOf(depositor);
            uint256 amount1Before = IERC20(pool.token1()).balanceOf(depositor);
            _withdraw(depositor, lpAmountWithdraw, pool.token0(), amount1 > 0);
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
            _withdraw(depositor, lpAmountWithdraw, pool.token1(), amount0 > 0);
            uint256 lpBalanceRecipientAfter = IERC20(lpWrapper).balanceOf(depositor);
            uint256 amount0After = IERC20(pool.token0()).balanceOf(depositor);
            require(
                lpBalanceRecipientBefore - lpBalanceRecipientAfter == lpAmountWithdraw,
                "depositor lp balance"
            );
            require(amount0After == amount0Before, "amount0");
        }

        require(IERC20(lpWrapper).balanceOf(depositor) == 0, "non zero LP");
    }

    function testWithdrawSwapOnTarget() external {
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.Tamper, contracts);

        address token0 = pool.token0();
        address token1 = pool.token1();
        uint256 amount = 10 ** ERC20(token0).decimals();

        _deposit(depositor, token0, amount);

        uint256 lpAmount = IERC20(lpWrapper).balanceOf(depositor);

        {
            uint256 lpAmountWithdraw = lpAmount / 2;
            uint256 lpBalanceRecipientBefore = IERC20(lpWrapper).balanceOf(depositor);

            (uint256 amount0, uint256 amount1) = lpWrapper.previewBurn(lpAmountWithdraw);

            bytes memory callData = abi.encodeWithSelector(
                ICLPoolActions.swap.selector,
                address(depositBalancer),
                false,
                amount1,
                TickMath.MAX_SQRT_RATIO - 1,
                ""
            );

            uint256 amount0Before = IERC20(token0).balanceOf(depositor);
            uint256 amount1Before = IERC20(token1).balanceOf(depositor);

            vm.startPrank(depositor);
            IERC20(address(lpWrapper)).approve(address(depositBalancer), lpAmountWithdraw);
            (amount0, amount1,) = depositBalancer.withdraw(
                address(lpWrapper),
                token0,
                lpAmountWithdraw,
                depositor,
                type(uint256).max,
                IDepositBalancer.SwapData({minReturn: 0, target: address(pool), data: callData})
            );

            require(
                lpBalanceRecipientBefore - IERC20(lpWrapper).balanceOf(depositor)
                    == lpAmountWithdraw,
                "depositor lp balance"
            );
            assertApproxEqRel(
                IERC20(token0).balanceOf(depositor) - amount0Before, amount / 2, 1e16, "amount0"
            );
            assertApproxEqAbs(IERC20(token1).balanceOf(depositor), amount1Before, 0, "amount1");
            vm.stopPrank();
        }
        {
            uint256 lpAmountWithdraw = IERC20(lpWrapper).balanceOf(depositor);
            uint256 lpBalanceRecipientBefore = IERC20(lpWrapper).balanceOf(depositor);

            (uint256 amount0, uint256 amount1) = lpWrapper.previewBurn(lpAmountWithdraw);

            bytes memory callData = abi.encodeWithSelector(
                ICLPoolActions.swap.selector,
                address(depositBalancer),
                true,
                amount0,
                TickMath.MIN_SQRT_RATIO + 1,
                ""
            );

            uint256 amount0Before = IERC20(token0).balanceOf(depositor);

            vm.startPrank(depositor);
            IERC20(address(lpWrapper)).approve(address(depositBalancer), lpAmountWithdraw);
            (amount0, amount1,) = depositBalancer.withdraw(
                address(lpWrapper),
                token1,
                lpAmountWithdraw,
                depositor,
                type(uint256).max,
                IDepositBalancer.SwapData({minReturn: 0, target: address(pool), data: callData})
            );

            require(
                lpBalanceRecipientBefore - IERC20(lpWrapper).balanceOf(depositor)
                    == lpAmountWithdraw,
                "depositor lp balance"
            );
            assertApproxEqAbs(IERC20(token0).balanceOf(depositor), amount0Before, 0, "amount0");
            vm.stopPrank();
        }
    }

    function _deposit(address recipient_, address token, uint256 amount)
        internal
        returns (uint256 actualAmount0, uint256 actualAmount1, uint256 actualLpAmount)
    {
        address lpWrapper = IVeloDeployFactory(lpWrapperFactory).poolToWrappers(address(pool))[0];

        vm.startPrank(depositor);
        IERC20(token).approve(address(depositBalancer), amount);

        uint256 balanceBefore = IERC20(token).balanceOf(depositor);

        console2.log("try deposit", ERC20(token).symbol(), amount);
        uint256 lpAmountBefore = IERC20(lpWrapper).balanceOf(recipient_);

        IDepositBalancer.SwapData memory swapData = _buildSwapDataDeposit(
            depositBalancer,
            lpWrapper,
            token == pool.token0() ? amount : 0,
            token == pool.token1() ? amount : 0
        );
        (actualAmount0, actualAmount1, actualLpAmount) = depositBalancer.deposit(
            lpWrapper, token, amount, recipient_, type(uint256).max, swapData
        );
        uint256 balanceAfter = IERC20(token).balanceOf(depositor);

        assertEq(
            IERC20(lpWrapper).balanceOf(recipient_) - lpAmountBefore,
            actualLpAmount,
            "LP token wrong balance"
        );

        console2.log("deposited", actualAmount0, actualAmount1);

        require(balanceBefore > balanceAfter, "no deposit");
        require(balanceBefore - balanceAfter <= amount, "too much");

        (uint160 sqrtPriceX96,) = ILpWrapper(lpWrapper).oracle().getOraclePrice(address(pool));

        uint256 capitalDesired = PositionMath.calculateCapital(
            pool.token0() == token ? amount : 0, pool.token0() == token ? 0 : amount, sqrtPriceX96
        );
        uint256 capitalActual =
            PositionMath.calculateCapital(actualAmount0, actualAmount1, sqrtPriceX96);

        assertApproxEqRel(capitalActual, capitalDesired, 1e15, "slippage more than 0.1%");

        _checkZeroRemaining(address(depositBalancer), pool);
    }

    function _withdraw(address recipient_, uint256 lpAmount, address tokenTarget, bool expectSwap)
        internal
        returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount)
    {
        address lpWrapper = IVeloDeployFactory(lpWrapperFactory).poolToWrappers(address(pool))[0];

        vm.startPrank(depositor);
        IERC20(lpWrapper).approve(address(depositBalancer), lpAmount);

        (amount0, amount1) = depositBalancer.previewWithdrawAmounts(lpWrapper, lpAmount);

        IDepositBalancer.SwapData memory swapData =
            _buildSwapDataWithdraw(depositBalancer, amount0, amount1, tokenTarget);

        vm.recordLogs();
        (amount0, amount1, actualLpAmount) = depositBalancer.withdraw(
            lpWrapper, tokenTarget, lpAmount, recipient_, type(uint256).max, swapData
        );
        Vm.Log[] memory entries = vm.getRecordedLogs();

        console2.log("withdrawn", tokenTarget == pool.token0(), amount0, amount1);
        assertTrue(
            tokenTarget == address(0)
                || (tokenTarget == pool.token0() ? amount1 == 0 : amount0 == 0),
            "Too many tokens"
        );

        bool swapEmitted = false;
        bytes32 swapTopic = 0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == swapTopic) {
                swapEmitted = true;
                break;
            }
        }

        require(
            expectSwap == swapEmitted, expectSwap ? "Swap event is absent" : "Unexpected swap event"
        );
        _checkZeroRemaining(address(depositBalancer), pool);
    }

    function _checkZeroRemaining(address account, ICLPool pool_) internal view {
        require(IERC20(pool_.token0()).balanceOf(account) == 0, "non zero balance of token0");
        require(IERC20(pool_.token1()).balanceOf(account) == 0, "non zero balance of token1");
    }

    function _buildSwapDataDeposit(
        IDepositBalancer balancer,
        address lpWrapper,
        uint256 amount0,
        uint256 amount1
    ) internal view returns (IDepositBalancer.SwapData memory swapData) {
        (, uint256 targetAmount0, uint256 targetAmount1) =
            depositBalancer.previewDepositAmounts(lpWrapper, amount0, amount1);
        bool zeroForOne = targetAmount0 < amount0;
        uint256 amountIn = zeroForOne ? amount0 - targetAmount0 : amount1 - targetAmount1;

        bytes memory data = abi.encodeWithSelector(
            ICLPoolActions.swap.selector,
            address(balancer),
            zeroForOne,
            int256(amountIn),
            zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            ""
        );
        swapData = IDepositBalancer.SwapData({target: address(pool), minReturn: 0, data: data});
    }

    function _buildSwapDataWithdraw(
        IDepositBalancer balancer,
        uint256 amount0,
        uint256 amount1,
        address tokenTarget
    ) internal view returns (IDepositBalancer.SwapData memory swapData) {
        bool zeroForOne;
        uint256 amountIn;
        if (tokenTarget == pool.token0()) {
            zeroForOne = false;
            amountIn = amount1;
        } else if (tokenTarget == pool.token1()) {
            zeroForOne = true;
            amountIn = amount0;
        }

        bytes memory data = abi.encodeWithSelector(
            ICLPoolActions.swap.selector,
            address(balancer),
            zeroForOne,
            int256(amountIn),
            zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            ""
        );
        swapData = IDepositBalancer.SwapData({target: address(pool), minReturn: 0, data: data});
    }
}
