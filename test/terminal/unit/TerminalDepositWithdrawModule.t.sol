// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    TerminalDepositWithdrawModule public module;

    function testConstructor() external {
        module = new TerminalDepositWithdrawModule(positionManager);
    }

    function testDeposit() external {
        module = new TerminalDepositWithdrawModule(positionManager);
        IVeloAmmModule ammModule = new TerminalAmmModule(positionManager);

        uint256 tokenId =
            mint(poolAB.tickSpacing(), poolAB.tickSpacing() * 2, 10000, poolAB, address(this), true);

        IVeloAmmModule.Position memory position_ = ammModule.getPosition(tokenId);

        (uint160 sqrtPriceX96, int24 tick) = ammModule.getSqrtPriceX96AndTick(address(poolAB));

        for (int24 i = 0; i < 10; i++) {
            sqrtPriceX96 = ammModule.getSqrtPriceX96(address(poolAB));

            (uint256 before0, uint256 before1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(position_.tickLower),
                TickMath.getSqrtRatioAtTick(position_.tickUpper),
                position_.liquidity
            );

            deal(tokenA, address(this), 1 ether);
            deal(tokenB, address(this), 1 ether);
            IERC20(tokenA).approve(address(module), 1 ether);
            IERC20(tokenB).approve(address(module), 1 ether);

            (uint256 actualAmount0, uint256 actualAmount1) =
                module.deposit(tokenId, 1 ether, 1 ether, address(this), tokenA, tokenB);

            position_.liquidity = ammModule.getPosition(tokenId).liquidity;

            (uint256 after0, uint256 after1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(position_.tickLower),
                TickMath.getSqrtRatioAtTick(position_.tickUpper),
                position_.liquidity
            );

            assertApproxEqAbs(actualAmount0, after0 - before0, 1 wei);
            assertApproxEqAbs(actualAmount1, after1 - before1, 1 wei);

            movePrice(poolAB, TickMath.getSqrtRatioAtTick(tick + int24(i - 5) * 100));
        }
    }

    function testWithdraw() external {
        module = new TerminalDepositWithdrawModule(positionManager);
        IVeloAmmModule ammModule = new TerminalAmmModule(positionManager);

        uint256 tokenId = mint(
            poolAB.tickSpacing(),
            poolAB.tickSpacing() * 2,
            1000000,
            poolAB,
            Constants.TERMINAL_DEPLOYER,
            true
        );

        vm.startPrank(Constants.TERMINAL_DEPLOYER);
        positionManager.transferFrom(Constants.TERMINAL_DEPLOYER, address(module), tokenId);
        vm.stopPrank();

        uint160 sqrtPriceX96 = ammModule.getSqrtPriceX96(address(poolAB));

        for (uint256 i = 0; i < 10; i++) {
            IVeloAmmModule.Position memory position_ = ammModule.getPosition(tokenId);

            (uint256 before0, uint256 before1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(position_.tickLower),
                TickMath.getSqrtRatioAtTick(position_.tickUpper),
                position_.liquidity
            );

            uint128 liquidityForWithdraw = position_.liquidity / 4;

            (uint256 actualAmount0, uint256 actualAmount1) =
                module.withdraw(tokenId, liquidityForWithdraw, address(this));

            uint128 liquidityAfter = ammModule.getPosition(tokenId).liquidity;
            (uint256 after0, uint256 after1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(position_.tickLower),
                TickMath.getSqrtRatioAtTick(position_.tickUpper),
                liquidityAfter
            );

            assertApproxEqAbs(liquidityAfter, position_.liquidity - liquidityForWithdraw, 0 wei);
            assertApproxEqAbs(actualAmount0, before0 - after0, 1 wei);
            assertApproxEqAbs(actualAmount1, before1 - after1, 1 wei);
        }
    }

    function testMintPosition() external {
        module = new TerminalDepositWithdrawModule(positionManager);
        IVeloAmmModule ammModule = new TerminalAmmModule(positionManager);

        deal(tokenA, address(this), 1 ether);
        deal(tokenB, address(this), 1 ether);

        int24 tickLower;
        int24 tickUpper;
        int24 ts = poolAB.tickSpacing();

        (uint160 sqrtPriceX96, int24 tick) = ammModule.getSqrtPriceX96AndTick(address(poolAB));
        int24 tickAligned = (tick / ts) * ts;
        tickLower = tickAligned - ts * 2;
        tickUpper = tickAligned + ts * 2;

        bytes memory data = Address.functionDelegateCall(
            address(module),
            abi.encodeWithSelector(
                IAmmDepositWithdrawModule.mint.selector,
                address(poolAB),
                tickLower,
                tickUpper,
                1 ether,
                1 ether,
                address(this)
            )
        );

        (uint256 tokenId, uint128 liquidity, uint256 amount0Actual, uint256 amount1Actual) =
            abi.decode(data, (uint256, uint128, uint256, uint256));
        assertTrue(tokenId != 0);
        assertTrue(positionManager.ownerOf(tokenId) == address(this));

        IVeloAmmModule.Position memory position_ = ammModule.getPosition(tokenId);
        assertEq(position_.liquidity, liquidity);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(position_.tickLower),
            TickMath.getSqrtRatioAtTick(position_.tickUpper),
            liquidity
        );
        assertApproxEqAbs(amount0, amount0Actual, 1 wei);
        assertApproxEqAbs(amount1, amount1Actual, 1 wei);
    }

    function testBurnPosition() external {
        module = new TerminalDepositWithdrawModule(positionManager);
        IVeloAmmModule ammModule = new TerminalAmmModule(positionManager);

        deal(tokenA, address(this), 1 ether);
        deal(tokenB, address(this), 1 ether);

        int24 tickLower;
        int24 tickUpper;
        int24 ts = poolAB.tickSpacing();

        (, int24 tick) = ammModule.getSqrtPriceX96AndTick(address(poolAB));
        int24 tickAligned = (tick / ts) * ts;
        tickLower = tickAligned - ts * 2;
        tickUpper = tickAligned + ts * 2;

        bytes memory data = Address.functionDelegateCall(
            address(module),
            abi.encodeWithSelector(
                IAmmDepositWithdrawModule.mint.selector,
                address(poolAB),
                tickLower,
                tickUpper,
                1 ether,
                1 ether,
                address(this)
            )
        );

        (uint256 tokenId, uint128 liquidity,,) =
            abi.decode(data, (uint256, uint128, uint256, uint256));
        assertTrue(tokenId != 0);
        assertTrue(positionManager.ownerOf(tokenId) == address(this));

        data = Address.functionDelegateCall(
            address(module),
            abi.encodeWithSelector(
                IAmmDepositWithdrawModule.withdraw.selector, tokenId, liquidity, address(this)
            )
        );

        assertApproxEqAbs(IERC20(tokenA).balanceOf(address(this)), 1 ether, 2 wei);
        assertApproxEqAbs(IERC20(tokenB).balanceOf(address(this)), 1 ether, 2 wei);

        data = Address.functionDelegateCall(
            address(module),
            abi.encodeWithSelector(IAmmDepositWithdrawModule.burn.selector, tokenId)
        );

        vm.expectRevert("ERC721: owner query for nonexistent token");
        positionManager.ownerOf(tokenId);
    }
}
