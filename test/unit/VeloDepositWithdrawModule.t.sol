// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    VeloDepositWithdrawModule public module;
    ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
    address token0 = pool.token0();
    address token1 = pool.token1();

    function testConstructor() external {
        module = new VeloDepositWithdrawModule(positionManager);
    }

    function testDeposit() external {
        module = new VeloDepositWithdrawModule(positionManager);

        uint256 tokenId = mint(
            token0, token1, pool.tickSpacing(), pool.tickSpacing() * 2, 10000, pool, address(this)
        );

        (,,,,, int24 tickLower, int24 tickUpper, uint128 liquidity,,,,) =
            positionManager.positions(tokenId);

        (uint160 sqrtPriceX96,,,,,) = pool.slot0();

        for (uint256 i = 0; i < 10; i++) {
            (uint256 before0, uint256 before1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );

            deal(token0, address(this), 1 ether);
            deal(token1, address(this), 1 ether);
            IERC20(token0).approve(address(module), 1 ether);
            IERC20(token1).approve(address(module), 1 ether);

            (uint256 actualAmount0, uint256 actualAmount1) =
                module.deposit(tokenId, 1 ether, 1 ether, address(this), token0, token1);

            (,,,,,,, liquidity,,,,) = positionManager.positions(tokenId);

            (uint256 after0, uint256 after1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );

            assertApproxEqAbs(actualAmount0, after0 - before0, 1 wei);
            assertApproxEqAbs(actualAmount1, after1 - before1, 1 wei);
        }
    }

    function testWithdraw() external {
        module = new VeloDepositWithdrawModule(positionManager);

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            1000000,
            pool,
            Constants.OPTIMISM_DEPLOYER
        );

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);
        positionManager.transferFrom(Constants.OPTIMISM_DEPLOYER, address(module), tokenId);
        vm.stopPrank();

        (uint160 sqrtPriceX96,,,,,) = pool.slot0();

        for (uint256 i = 0; i < 10; i++) {
            (,,,,, int24 tickLower, int24 tickUpper, uint128 liquidity,,,,) =
                positionManager.positions(tokenId);

            (uint256 before0, uint256 before1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );

            uint128 liquidityForWithdraw = liquidity / 4;

            (uint256 actualAmount0, uint256 actualAmount1) =
                module.withdraw(tokenId, liquidityForWithdraw, address(this));

            (,,,,,,, uint128 liquidityAfter,,,,) = positionManager.positions(tokenId);
            (uint256 after0, uint256 after1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidityAfter
            );

            assertApproxEqAbs(liquidityAfter, liquidity - liquidityForWithdraw, 0 wei);
            assertApproxEqAbs(actualAmount0, before0 - after0, 1 wei);
            assertApproxEqAbs(actualAmount1, before1 - after1, 1 wei);
        }
    }
}
