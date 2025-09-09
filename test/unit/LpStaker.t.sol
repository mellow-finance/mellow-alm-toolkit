// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;
    using Math for uint256;

    int24 constant MAX_ALLOWED_DELTA = 100;
    uint32 constant MAX_AGE = 1 hours;
    uint128 INITIAL_LIQUIDITY = 1 ether;

    address public constant VELO = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;

    address immutable admin = vm.addr(uint256(keccak256("admin")));
    address immutable manager = vm.addr(uint256(keccak256("manager")));
    address immutable operator = vm.addr(uint256(keccak256("operator")));
    address immutable user = vm.addr(uint256(keccak256("user")));

    address lpStakerImplementation;

    uint32 constant defaultTimeLock = 1 days;

    DeployScript.CoreDeployment contracts;

    function setUp() external {
        contracts = deployContracts();

        lpStakerImplementation = address(new LpStaker(address(contracts.core)));

        deal(Constants.OPTIMISM_WETH, address(this), 1e10 ether);
        deal(Constants.OPTIMISM_OP, address(this), 1e10 ether);
    }

    function testStake(uint32 lpAmountX32) external {
        vm.assume(lpAmountX32 > 0);
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
        (ILpStaker lpStaker, ILpWrapper lpWrapper) = _initLpStaker(pool, defaultTimeLock);

        uint256 lpAmount = uint256(lpAmountX32).mulDiv(1 ether, type(uint32).max);
        (uint256 amount0, uint256 amount1) = lpWrapper.previewMint(lpAmount);

        IERC20(Constants.OPTIMISM_WETH).safeIncreaseAllowance(address(lpWrapper), amount0);
        IERC20(Constants.OPTIMISM_OP).safeIncreaseAllowance(address(lpWrapper), amount1);
        (,, lpAmount) = lpWrapper.mint(
            ILpWrapper.MintParams(lpAmount, amount0, amount1, user, type(uint256).max)
        );

        vm.startPrank(user);
        IERC20(address(lpWrapper)).safeIncreaseAllowance(address(lpStaker), lpAmount);
        uint256 shares = lpStaker.stake(lpAmount);
        vm.stopPrank();

        assertEq(IERC20(address(lpWrapper)).balanceOf(user), 0);
        assertEq(IERC20(address(lpStaker)).balanceOf(user), shares);
        assertEq(lpStaker.lpAmountOf(user), lpAmount);

        skip(defaultTimeLock);

        uint256 amountExpected = lpStaker.lpAmountOf(user);
        vm.prank(user);
        uint256 amount = lpStaker.unstake(shares);

        assertEq(amount, amountExpected, "unstake amount mismatch");
        assertEq(lpStaker.sharesOf(user), 0, "shares after unstake mismatch");
        assertEq(lpStaker.lpAmountOf(user), 0, "assets after unstake mismatch");
    }

    function testMintAndStake() external {
        uint32 lpAmountX32 = type(uint32).max; //vm.assume(lpAmountX32 > 0);
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
        (ILpStaker lpStaker, ILpWrapper lpWrapper) = _initLpStaker(pool, defaultTimeLock);

        uint256 lpAmount = uint256(lpAmountX32).mulDiv(1 ether, type(uint32).max);
        (uint256 amount0, uint256 amount1) = lpWrapper.previewMint(lpAmount);
        deal(Constants.OPTIMISM_WETH, user, amount0);
        deal(Constants.OPTIMISM_OP, user, amount1);

        vm.startPrank(user);
        IERC20(Constants.OPTIMISM_WETH).safeIncreaseAllowance(address(lpStaker), amount0);
        IERC20(Constants.OPTIMISM_OP).safeIncreaseAllowance(address(lpStaker), amount1);

        uint256 lpAmountActual;
        uint256 shares;

        (amount0, amount1, lpAmountActual, shares) = lpStaker.mintAndStake(amount0, amount1);
        vm.stopPrank();

        assertEq(IERC20(address(lpWrapper)).balanceOf(user), 0);
        assertEq(IERC20(address(lpWrapper)).balanceOf(address(lpStaker)), lpAmountActual);
        assertEq(IERC20(address(lpStaker)).balanceOf(user), shares);
        assertEq(lpStaker.lpAmountOf(user), lpAmountActual);

        assertEq(
            IERC20(Constants.OPTIMISM_WETH).balanceOf(address(lpStaker)),
            0,
            "token0 too much dust after mint"
        );
        assertEq(
            IERC20(Constants.OPTIMISM_OP).balanceOf(address(lpStaker)),
            0,
            "token1 too much dust after mint"
        );

        skip(defaultTimeLock);

        uint256 amountExpected = lpStaker.lpAmountOf(user);
        vm.prank(user);
        (uint256 actualAmount0, uint256 actualAmount1, uint256 actualLpAmount) =
            lpStaker.unstakeAndWithdraw(shares, 0, 0, user);

        assertApproxEqAbs(actualLpAmount, amountExpected, 1, "unstake lpAmount mismatch");
        assertApproxEqAbs(amount0, actualAmount0, 1, "unstake amount0 mismatch");
        assertApproxEqAbs(amount1, actualAmount1, 1, "unstake amount1 mismatch");
        assertEq(lpStaker.sharesOf(user), 0, "shares after unstake mismatch");
        assertEq(lpStaker.lpAmountOf(user), 0, "assets after unstake mismatch");
        assertEq(lpStaker.lpAmountOf(user), 0, "assets after unstake mismatch");
    }

    function testQuoteSwap() external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
        (ILpStaker lpStaker, ILpWrapper lpWrapper) = _initLpStaker(pool, defaultTimeLock);

        (address token0, address token1) = contracts.ammModule.getPoolTokens(address(pool));

        uint256 lpAmount = 1 ether;
        (uint256 amount0, uint256 amount1) = lpWrapper.previewMint(lpAmount);

        IERC20(Constants.OPTIMISM_WETH).safeIncreaseAllowance(address(lpWrapper), amount0);
        IERC20(Constants.OPTIMISM_OP).safeIncreaseAllowance(address(lpWrapper), amount1);
        (,, lpAmount) = lpWrapper.mint(
            ILpWrapper.MintParams(lpAmount, amount0, amount1, user, type(uint256).max)
        );

        vm.startPrank(user);
        IERC20(address(lpWrapper)).safeIncreaseAllowance(address(lpStaker), lpAmount);
        uint256 shares = lpStaker.stake(lpAmount);
        vm.stopPrank();

        skip(30 days);

        /// @dev collect rewards to have something to swap
        lpWrapper.collectRewards();

        ILpStaker.QuoteParams[2] memory quoteParams = lpStaker.quoteSwapAmounts();

        uint256 earned = lpWrapper.earned(address(lpStaker));
        uint256 swapRewardAmount;

        for (uint256 index = 0; index < quoteParams.length; index++) {
            assertEq(quoteParams[index].tokenIn, lpWrapper.rewardToken(), "tokenIn mismatch");
            assertTrue(
                quoteParams[index].tokenOut == token0 || quoteParams[index].tokenOut == token1,
                "tokenOut mismatch"
            );
            swapRewardAmount += quoteParams[index].amountIn;
        }
        assertEq(swapRewardAmount, earned, "total amount rewards mismatch");

        skip(defaultTimeLock);

        uint256 amountExpected = lpStaker.lpAmountOf(user);
        vm.prank(user);
        uint256 amount = lpStaker.unstake(shares);

        assertEq(amount, amountExpected, "unstake amount mismatch");
        assertEq(lpStaker.sharesOf(user), 0, "shares after unstake mismatch");
        assertEq(lpStaker.lpAmountOf(user), 0, "assets after unstake mismatch");
    }

    function testSwapRewards() external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
        (ILpStaker lpStaker, ILpWrapper lpWrapper) = _initLpStaker(pool, defaultTimeLock);

        (address token0, address token1) = contracts.ammModule.getPoolTokens(address(pool));

        uint256 lpAmount = 1 ether;
        (uint256 amount0, uint256 amount1) = lpWrapper.previewMint(lpAmount);

        IERC20(Constants.OPTIMISM_WETH).safeIncreaseAllowance(address(lpWrapper), amount0);
        IERC20(Constants.OPTIMISM_OP).safeIncreaseAllowance(address(lpWrapper), amount1);
        (,, lpAmount) = lpWrapper.mint(
            ILpWrapper.MintParams(lpAmount, amount0, amount1, user, type(uint256).max)
        );

        SwapRouterMock target = new SwapRouterMock();
        /// 1 ETH = 5000 VELO
        target.setPriceX96(token0, VELO, 5000 * Q96);
        /// 1 OP = 15 VELO
        target.setPriceX96(token1, VELO, 15 * Q96);

        vm.startPrank(user);
        IERC20(address(lpWrapper)).safeIncreaseAllowance(address(lpStaker), lpAmount);
        uint256 shares = lpStaker.stake(lpAmount);
        vm.stopPrank();

        skip(30 days);

        /// @dev collect rewards to have something to swap
        lpWrapper.collectRewards();

        ILpStaker.SwapParams[2] memory swapParams = _buildSwapData(lpStaker, target);

        vm.expectRevert(DefaultAccessControl.Forbidden.selector);
        lpStaker.compoundRewards(swapParams);

        vm.prank(manager);
        IAccessControlCalls(address(lpStaker)).allowTargetCall(
            address(target), SwapRouterMock.swap.selector
        );

        vm.expectRevert(DefaultAccessControl.Forbidden.selector);
        lpStaker.compoundRewards(swapParams);

        vm.prank(operator);
        lpStaker.compoundRewards(swapParams);

        uint256 lpTotal = IERC20(address(lpStaker)).totalSupply();
        assertApproxEqAbs(
            lpTotal.mulDiv(IERC20(address(lpWrapper)).balanceOf(address(lpStaker)), 1 ether),
            lpStaker.lpPrice(),
            1
        );
        assertApproxEqAbs(
            lpStaker.lpAmountOf(user), IERC20(address(lpWrapper)).balanceOf(address(lpStaker)), 1
        );

        skip(defaultTimeLock);

        uint256 amountExpected = lpStaker.lpAmountOf(user);
        vm.prank(user);
        uint256 amount = lpStaker.unstake(shares);

        assertEq(amount, amountExpected, "unstake amount mismatch");
        assertEq(lpStaker.sharesOf(user), 0, "shares after unstake mismatch");
        assertEq(lpStaker.lpAmountOf(user), 0, "assets after unstake mismatch");
    }

    function testSwapRewardsFuzz() external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
        (ILpStaker lpStaker, ILpWrapper lpWrapper) = _initLpStaker(pool, defaultTimeLock);

        (address token0, address token1) = contracts.ammModule.getPoolTokens(address(pool));

        uint256 lpAmount = 1 ether;
        (uint256 amount0, uint256 amount1) = lpWrapper.previewMint(lpAmount);

        IERC20(Constants.OPTIMISM_WETH).safeIncreaseAllowance(address(lpWrapper), amount0);
        IERC20(Constants.OPTIMISM_OP).safeIncreaseAllowance(address(lpWrapper), amount1);
        (,, lpAmount) = lpWrapper.mint(
            ILpWrapper.MintParams(lpAmount, amount0, amount1, user, type(uint256).max)
        );

        SwapRouterMock target = new SwapRouterMock();
        /// 1 ETH = 5000 VELO
        target.setPriceX96(token0, VELO, 5000 * Q96);
        /// 1 OP = 15 VELO
        target.setPriceX96(token1, VELO, 15 * Q96);

        vm.prank(manager);
        IAccessControlCalls(address(lpStaker)).allowTargetCall(
            address(target), SwapRouterMock.swap.selector
        );

        vm.startPrank(user);
        IERC20(address(lpWrapper)).safeIncreaseAllowance(address(lpStaker), lpAmount);
        lpStaker.stake(lpAmount);
        vm.stopPrank();

        for (uint256 index = 0; index < 42; index++) {
            skip(4 hours);

            /// @dev collect rewards to have something to swap
            lpWrapper.collectRewards();

            ILpStaker.SwapParams[2] memory swapParams = _buildSwapData(lpStaker, target);

            vm.prank(operator);
            lpStaker.compoundRewards(swapParams);

            uint256 lpTotal = IERC20(address(lpStaker)).totalSupply();
            assertApproxEqAbs(
                lpTotal.mulDiv(IERC20(address(lpWrapper)).balanceOf(address(lpStaker)), 1 ether),
                lpStaker.lpPrice(),
                1
            );
            assertApproxEqAbs(
                lpStaker.lpAmountOf(user),
                IERC20(address(lpWrapper)).balanceOf(address(lpStaker)),
                1
            );
        }
    }

    function testUpdateTimeLock() external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));

        uint32 timeLock = 2 days;
        (ILpStaker lpStaker,) = _initLpStaker(pool, timeLock);

        assertEq(lpStaker.timeLock(), timeLock);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                DefaultAccessControl(address(lpStaker)).ADMIN_ROLE()
            )
        );
        lpStaker.updateTimeLock(7 hours);
        assertEq(lpStaker.timeLock(), timeLock);

        uint32 minTimeLock = lpStaker.MIN_TIMELOCK_DURATION();
        uint32 maxTimeLock = lpStaker.MAX_TIMELOCK_DURATION();

        vm.startPrank(admin);

        vm.expectRevert(abi.encodeWithSelector(ILpStaker.InvalidTimeLock.selector, minTimeLock - 1));
        lpStaker.updateTimeLock(minTimeLock - 1);

        vm.expectRevert(abi.encodeWithSelector(ILpStaker.InvalidTimeLock.selector, maxTimeLock + 1));
        lpStaker.updateTimeLock(maxTimeLock + 1);

        lpStaker.updateTimeLock(minTimeLock);
        assertEq(lpStaker.timeLock(), minTimeLock);

        lpStaker.updateTimeLock(maxTimeLock);
        assertEq(lpStaker.timeLock(), maxTimeLock);

        vm.stopPrank();
    }

    function testLockedAmountOneDeposit() external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));

        uint32 timeLock = 6 hours;
        (ILpStaker lpStaker, ILpWrapper lpWrapper) = _initLpStaker(pool, timeLock);

        address recipient = vm.addr(uint256(keccak256("recipient")));

        uint256 lpAmount = 1 ether;
        (uint256 amount0, uint256 amount1) = lpWrapper.previewMint(lpAmount);
        deal(Constants.OPTIMISM_WETH, user, type(uint128).max);
        deal(Constants.OPTIMISM_OP, user, type(uint128).max);

        vm.startPrank(user);
        IERC20(Constants.OPTIMISM_WETH).safeIncreaseAllowance(address(lpStaker), type(uint256).max);
        IERC20(Constants.OPTIMISM_OP).safeIncreaseAllowance(address(lpStaker), type(uint256).max);

        uint256 lpAmountActual;
        uint256 shares;

        (amount0, amount1, lpAmountActual, shares) = lpStaker.mintAndStake(amount0, amount1);

        for (uint256 index = 0; index < 10; index++) {
            uint256 sharesToTransfer = (index + 1) * shares / (10 + 1);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ILpStaker.InsufficientUnlockedShares.selector, user, shares, sharesToTransfer
                )
            );
            ERC20(address(lpStaker)).transfer(recipient, sharesToTransfer);
        }
        vm.stopPrank();

        {
            skip(timeLock - 1);
            (uint256 lockedShares, uint32 activeCheckpoints) =
                lpStaker.getLockedShares(user, uint32(block.timestamp));
            assertEq(lockedShares, shares, "locked shares mismatch");
            assertEq(activeCheckpoints, 1, "active checkpoints mismatch");

            skip(1);

            (lockedShares, activeCheckpoints) =
                lpStaker.getLockedShares(user, uint32(block.timestamp));
            assertEq(lockedShares, 0, "locked shares mismatch");
            assertEq(activeCheckpoints, 0, "active checkpoints mismatch");
        }

        {
            vm.prank(user);
            ERC20(address(lpStaker)).transfer(recipient, shares / 2);
            assertEq(
                ERC20(address(lpStaker)).balanceOf(recipient),
                shares / 2,
                "recipient shares mismatch"
            );
            assertEq(
                ERC20(address(lpStaker)).balanceOf(user),
                shares - shares / 2,
                "user shares mismatch"
            );

            vm.prank(user);
            lpStaker.unstake(shares - shares / 2);
            assertEq(ERC20(address(lpStaker)).balanceOf(user), 0, "user shares mismatch");

            vm.prank(recipient);
            lpStaker.unstake(shares / 2);
            assertEq(ERC20(address(lpStaker)).balanceOf(recipient), 0, "recipient shares mismatch");
        }
    }

    function _buildSwapData(ILpStaker lpStaker, SwapRouterMock target)
        internal
        view
        returns (ILpStaker.SwapParams[2] memory swapParams)
    {
        ILpStaker.QuoteParams[2] memory quoteParams = lpStaker.quoteSwapAmounts();

        for (uint256 index = 0; index < quoteParams.length; index++) {
            uint256 amountOut = target.quote(
                quoteParams[index].tokenIn, quoteParams[index].tokenOut, quoteParams[index].amountIn
            );

            swapParams[index] = ILpStaker.SwapParams({
                target: address(target),
                amountIn: quoteParams[index].amountIn,
                tokenOut: quoteParams[index].tokenOut,
                minAmountOut: amountOut * 999 / 1000,
                data: abi.encodeWithSelector(
                    target.swap.selector,
                    quoteParams[index].amountIn,
                    quoteParams[index].tokenIn,
                    quoteParams[index].tokenOut,
                    address(lpStaker)
                )
            });
        }
    }

    function _initLpStaker(ICLPool pool, uint32 timeLock)
        internal
        returns (ILpStaker lpStaker, ILpWrapper lpWrapper)
    {
        (lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.LazySyncing, contracts);

        lpStaker = ILpStaker(Clones.clone(lpStakerImplementation));
        lpStaker.initialize(lpWrapper, admin, manager, operator, timeLock);
    }
}
