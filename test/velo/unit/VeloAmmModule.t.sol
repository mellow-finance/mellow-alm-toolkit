// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    VeloAmmModule public module;

    function testConstructor() external {
        vm.expectRevert();
        module = new VeloAmmModule(
            INonfungiblePositionManager(address(0)),
            address(0),
            0
        );
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        module = new VeloAmmModule(
            INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER),
            address(0),
            0
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidFee()"));
        module = new VeloAmmModule(
            INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER),
            address(1),
            3e8 + 1
        );
        module = new VeloAmmModule(
            INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER),
            address(1),
            3e8
        );
    }

    function testGetAmountsForLiquidity() external {
        module = new VeloAmmModule(
            INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER),
            address(1),
            3e8
        );

        {
            uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(1234);
            int24 tickLower = -1234;
            int24 tickUpper = 1234;
            (uint256 amount0, uint256 amount1) = module.getAmountsForLiquidity(
                1000,
                sqrtRatioX96,
                tickLower,
                tickUpper
            );
            assertTrue(amount0 == 0);
            assertTrue(amount1 > 0);
        }

        {
            uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(-1234);
            int24 tickLower = -1234;
            int24 tickUpper = 1234;
            (uint256 amount0, uint256 amount1) = module.getAmountsForLiquidity(
                1000,
                sqrtRatioX96,
                tickLower,
                tickUpper
            );
            assertTrue(amount0 > 0);
            assertTrue(amount1 == 0);
        }

        {
            uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(0);
            int24 tickLower = -1234;
            int24 tickUpper = 1234;
            (uint256 amount0, uint256 amount1) = module.getAmountsForLiquidity(
                1000,
                sqrtRatioX96,
                tickLower,
                tickUpper
            );
            assertTrue(amount0 == amount1);
            assertTrue(amount0 > 0);
        }

        {
            uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(100);
            int24 tickLower = -1234;
            int24 tickUpper = 1234;
            (uint256 amount0, uint256 amount1) = module.getAmountsForLiquidity(
                1000,
                sqrtRatioX96,
                tickLower,
                tickUpper
            );
            assertTrue(amount0 > 0);
            assertTrue(amount1 > 0);
            assertTrue(amount0 != amount1);
        }
    }

    function testTvl() external {
        module = new VeloAmmModule(
            INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER),
            address(1),
            3e8
        );

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
        {
            (uint256 amount0, uint256 amount1) = module.tvl(
                tokenId,
                TickMath.getSqrtRatioAtTick(0),
                address(0),
                address(0)
            );
            assertTrue(amount0 > 0 && amount1 > 0 && amount0 == amount1);
            (uint256 expected0, uint256 expected1) = LiquidityAmounts
                .getAmountsForLiquidity(
                    TickMath.getSqrtRatioAtTick(0),
                    TickMath.getSqrtRatioAtTick(tickLower),
                    TickMath.getSqrtRatioAtTick(tickUpper),
                    liquidity
                );
            assertTrue(amount0 == expected0 && amount1 == expected1);
        }
        vm.startPrank(Constants.DEPLOYER);
        movePrice(100, pool);
        vm.stopPrank();
        {
            (uint256 amount0, uint256 amount1) = module.tvl(
                tokenId,
                TickMath.getSqrtRatioAtTick(0),
                address(0),
                address(0)
            );
            assertTrue(amount0 > 0 && amount1 > 0 && amount0 == amount1);
            (uint256 expected0, uint256 expected1) = LiquidityAmounts
                .getAmountsForLiquidity(
                    TickMath.getSqrtRatioAtTick(0),
                    TickMath.getSqrtRatioAtTick(tickLower),
                    TickMath.getSqrtRatioAtTick(tickUpper),
                    liquidity
                );
            assertTrue(amount0 == expected0 && amount1 == expected1);
        }
        {
            (uint160 sqrtPriceX96, , , , , ) = pool.slot0();
            (uint256 amount0, uint256 amount1) = module.tvl(
                tokenId,
                sqrtPriceX96,
                address(0),
                address(0)
            );
            assertTrue(amount0 > 0 && amount1 > 0 && amount0 != amount1);
            (uint256 left0, uint256 left1) = LiquidityAmounts
                .getAmountsForLiquidity(
                    TickMath.getSqrtRatioAtTick(101),
                    TickMath.getSqrtRatioAtTick(tickLower),
                    TickMath.getSqrtRatioAtTick(tickUpper),
                    liquidity
                );
            (uint256 right0, uint256 right1) = LiquidityAmounts
                .getAmountsForLiquidity(
                    TickMath.getSqrtRatioAtTick(99),
                    TickMath.getSqrtRatioAtTick(tickLower),
                    TickMath.getSqrtRatioAtTick(tickUpper),
                    liquidity
                );
            if (left0 <= right0) {
                assertTrue(amount0 >= left0 && amount0 <= right0);
            } else {
                assertTrue(amount0 >= right0 && amount0 <= left0);
            }
            if (left1 <= right1) {
                assertTrue(amount1 >= left1 && amount1 <= right1);
            } else {
                assertTrue(amount1 >= right1 && amount1 <= left1);
            }
        }
    }

    function testGetPositionInfo() external {
        module = new VeloAmmModule(
            INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER),
            address(1),
            3e8
        );

        ICLPool pool = ICLPool(0xC358c95b146E9597339b376063A2cB657AFf84eb);
        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool
        );
        IAmmModule.Position memory position = module.getPositionInfo(tokenId);
        (
            ,
            ,
            address token0,
            address token1,
            int24 tickSpacing,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,

        ) = positionManager.positions(tokenId);
        assertEq(position.tickLower, tickLower, "tickLower should be equal");
        assertEq(position.tickUpper, tickUpper, "tickUpper should be equal");
        assertEq(position.liquidity, liquidity, "liquidity should be equal");
        assertEq(position.token0, token0, "token0 should be equal");
        assertEq(position.token1, token1, "token1 should be equal");
        assertEq(
            int24(position.property),
            tickSpacing,
            "tickSpacing should be equal"
        );
    }

    function testGetPool() external {
        module = new VeloAmmModule(
            INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER),
            address(1),
            3e8
        );

        int24[6] memory tickSpacings = [
            int24(1),
            int24(50),
            int24(100),
            int24(200),
            int24(2000),
            int24(2001)
        ];

        address[6] memory pools = [
            0xC5f793371847071EB87C693Ba0F1e938361A73a8,
            0x63D7198c41c4689875e7BdD8E572c06a694d6975,
            0x251dFdCd1e21893f7A94A1A68d445eF68dFaC622,
            0xC358c95b146E9597339b376063A2cB657AFf84eb,
            0xEeA91EdCcf7c43323BB42b26E46c7232Aa47302E,
            address(0)
        ];

        for (uint256 i = 0; i < 5; i++) {
            assertEq(
                pools[i],
                module.getPool(
                    Constants.WETH,
                    Constants.USDC,
                    uint24(tickSpacings[i])
                )
            );
        }
    }

    function testGetProperty() external {
        module = new VeloAmmModule(
            INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER),
            address(1),
            3e8
        );

        int24[5] memory tickSpacings = [
            int24(1),
            int24(50),
            int24(100),
            int24(200),
            int24(2000)
        ];

        address[5] memory pools = [
            0xC5f793371847071EB87C693Ba0F1e938361A73a8,
            0x63D7198c41c4689875e7BdD8E572c06a694d6975,
            0x251dFdCd1e21893f7A94A1A68d445eF68dFaC622,
            0xC358c95b146E9597339b376063A2cB657AFf84eb,
            0xEeA91EdCcf7c43323BB42b26E46c7232Aa47302E
        ];

        for (uint256 i = 0; i < 5; i++) {
            assertEq(uint24(tickSpacings[i]), module.getProperty(pools[i]));
        }
    }

    function testBeforeRebalance() external {
        module = new VeloAmmModule(
            INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER),
            address(1),
            3e8
        );

        // nothing happens
        module.beforeRebalance(address(0), address(0), 0);

        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        module.beforeRebalance(address(1), address(0), 0);

        //     ICLGauge(gauge).getReward(tokenId);
        //     address token = ICLGauge(gauge).rewardToken();
        //     uint256 balance = IERC20(token).balanceOf(address(this));
        //     if (balance > 0) {
        //         uint256 protocolReward = FullMath.mulDiv(
        //             protocolFeeD9,
        //             balance,
        //             D9
        //         );

        //         if (protocolReward > 0) {
        //             IERC20(token).safeTransfer(protocolTreasury, protocolReward);
        //         }

        //         balance -= protocolReward;
        //         if (balance > 0) {
        //             IERC20(token).safeTransfer(synthetixFarm, balance);
        //         }
        //     }
        //     ICLGauge(gauge).withdraw(tokenId);
        // }
    }
}
