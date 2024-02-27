// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Test {
    using SafeERC20 for IERC20;

    VeloAmmModule public module;

    function testConstructor() external {
        vm.expectRevert();
        module = new VeloAmmModule(
            INonfungiblePositionManager(address(0)),
            address(0),
            0
        );
        vm.expectRevert("VeloAmmModule: treasury is zero");
        module = new VeloAmmModule(
            INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER),
            address(0),
            0
        );
        vm.expectRevert("VeloAmmModule: invalid fee");
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
    }
}
