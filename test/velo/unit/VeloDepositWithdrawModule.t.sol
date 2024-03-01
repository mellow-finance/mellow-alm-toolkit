// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    VeloDepositWithdrawModule public module;

    function testConstructor() external {
        module = new VeloDepositWithdrawModule(positionManager);
    }

    function testDeposit() external {
        module = new VeloDepositWithdrawModule(positionManager);

        ICLPool pool = ICLPool(0xC358c95b146E9597339b376063A2cB657AFf84eb);
        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool
        );

        (
            ,
            ,
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,

        ) = positionManager.positions(tokenId);

        (uint256 before0, uint256 before1) = LiquidityAmounts
            .getAmountsForLiquidity(
                TickMath.getSqrtRatioAtTick(0),
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );

        deal(pool.token0(), address(this), 1 ether);
        deal(pool.token1(), address(this), 1 ether);
        IERC20(pool.token0()).approve(address(module), 1 ether);
        IERC20(pool.token1()).approve(address(module), 1 ether);

        (uint256 actualAmount0, uint256 actualAmount1) = module.deposit(
            tokenId,
            1 ether,
            1 ether,
            address(this)
        );

        (, , , , , , , liquidity, , , , ) = positionManager.positions(tokenId);

        (uint256 after0, uint256 after1) = LiquidityAmounts
            .getAmountsForLiquidity(
                TickMath.getSqrtRatioAtTick(0),
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );

        assertEq(actualAmount0, after0 - before0);
        assertEq(actualAmount1, after1 - before1);
    }

    function testWithdraw() external {
        module = new VeloDepositWithdrawModule(positionManager);

        ICLPool pool = ICLPool(0xC358c95b146E9597339b376063A2cB657AFf84eb);
        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool
        );

        (
            ,
            ,
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,

        ) = positionManager.positions(tokenId);

        (uint256 before0, uint256 before1) = LiquidityAmounts
            .getAmountsForLiquidity(
                TickMath.getSqrtRatioAtTick(0),
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );

        vm.startPrank(Constants.OWNER);
        positionManager.transferFrom(Constants.OWNER, address(module), tokenId);
        vm.stopPrank();

        (uint256 actualAmount0, uint256 actualAmount1) = module.withdraw(
            tokenId,
            liquidity / 4,
            address(this)
        );

        (, , , , , , , uint128 liquidityAfter, , , , ) = positionManager
            .positions(tokenId);
        (uint256 after0, uint256 after1) = LiquidityAmounts
            .getAmountsForLiquidity(
                TickMath.getSqrtRatioAtTick(0),
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidityAfter
            );

        assertEq(liquidityAfter, liquidity - liquidity / 4);
        assertEq(actualAmount0, before0 - after0);
        assertEq(actualAmount1, before1 - after1);
    }
}
