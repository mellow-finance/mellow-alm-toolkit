// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    VeloAmmModule public module =
        new VeloAmmModule(
            INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER)
        );

    ICLPool public pool =
        ICLPool(factory.getPool(Constants.WETH, Constants.OP, 200));

    address public testFarmAddress = address(123);
    address public counterAddress =
        address(
            new Counter(
                Constants.OWNER,
                Constants.OWNER,
                Constants.VELO,
                testFarmAddress
            )
        );

    bytes public defaultCallbackParams =
        abi.encode(
            IVeloAmmModule.CallbackParams({
                farm: testFarmAddress,
                gauge: address(pool.gauge()),
                counter: address(
                    new Counter(
                        address(this),
                        address(this),
                        Constants.VELO,
                        testFarmAddress
                    )
                )
            })
        );

    bytes public defaultProtocolParams =
        abi.encode(
            IVeloAmmModule.ProtocolParams({
                feeD9: 3e8,
                treasury: Constants.PROTOCOL_TREASURY
            })
        );

    function addRewardToGauge(uint256 amount, ICLGauge gauge) public {
        address voter = address(gauge.voter());
        address rewardToken = gauge.rewardToken();
        deal(rewardToken, voter, amount);
        vm.startPrank(voter);
        IERC20(rewardToken).safeIncreaseAllowance(address(gauge), amount);
        ICLGauge(gauge).notifyRewardAmount(amount);
        vm.stopPrank();
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function testConstructor() external {
        module = new VeloAmmModule(
            INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER)
        );
    }

    function testGetAmountsForLiquidity() external {
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
        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool
        );
        (uint160 sqrtPriceX96, , , , , ) = pool.slot0();
        {
            (uint256 amount0, uint256 amount1) = module.tvl(
                tokenId,
                sqrtPriceX96,
                defaultCallbackParams,
                defaultProtocolParams
            );
            assertTrue(amount0 > 0 && amount1 > 0);
            (uint256 expected0, uint256 expected1) = PositionValue.total(
                positionManager,
                tokenId,
                sqrtPriceX96
            );

            assertEq(amount0, expected0);
            assertEq(amount1, expected1);
        }
        vm.startPrank(Constants.DEPLOYER);
        movePrice(100, pool);
        (sqrtPriceX96, , , , , ) = pool.slot0();
        vm.stopPrank();
        {
            (uint256 amount0, uint256 amount1) = module.tvl(
                tokenId,
                sqrtPriceX96,
                defaultCallbackParams,
                defaultProtocolParams
            );
            assertTrue(amount0 + amount1 > 0);
            (uint256 expected0, uint256 expected1) = PositionValue.total(
                positionManager,
                tokenId,
                sqrtPriceX96
            );
            assertEq(amount0, expected0);
            assertEq(amount1, expected1);
        }
        // {
        //     (sqrtPriceX96, , , , , ) = pool.slot0();
        //     (uint256 amount0, uint256 amount1) = module.tvl(
        //         tokenId,
        //         sqrtPriceX96,
        //         defaultCallbackParams,
        //         defaultProtocolParams
        //     );
        //     assertTrue(amount0 + amount1 > 0);
        //     (uint256 left0, uint256 left1) = LiquidityAmounts
        //         .getAmountsForLiquidity(
        //             (sqrtPriceX96 * 101) / 100,
        //             TickMath.getSqrtRatioAtTick(tickLower),
        //             TickMath.getSqrtRatioAtTick(tickUpper),
        //             liquidity
        //         );
        //     (uint256 right0, uint256 right1) = LiquidityAmounts
        //         .getAmountsForLiquidity(
        //             (sqrtPriceX96 * 99) / 100,
        //             TickMath.getSqrtRatioAtTick(tickLower),
        //             TickMath.getSqrtRatioAtTick(tickUpper),
        //             liquidity
        //         );
        //     if (left0 <= right0) {
        //         assertTrue(amount0 >= left0 && amount0 <= right0);
        //     } else {
        //         assertTrue(amount0 >= right0 && amount0 <= left0);
        //     }
        //     if (left1 <= right1) {
        //         assertTrue(amount1 >= left1 && amount1 <= right1);
        //     } else {
        //         assertTrue(amount1 >= right1 && amount1 <= left1);
        //     }
        // }
    }

    function testGetPositionInfo() external {
        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool
        );
        IAmmModule.AmmPosition memory position = module.getAmmPosition(tokenId);
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
        int24[6] memory tickSpacings = [
            int24(1),
            int24(50),
            int24(100),
            int24(200),
            int24(2000),
            int24(2001)
        ];

        address[6] memory pools = [
            address(0),
            address(0),
            address(0),
            address(0x1e60272caDcFb575247a666c11DBEA146299A2c4),
            address(0),
            address(0)
        ];

        for (uint256 i = 0; i < 5; i++) {
            assertEq(
                pools[i],
                module.getPool(
                    Constants.WETH,
                    Constants.OP,
                    uint24(tickSpacings[i])
                )
            );
        }
    }

    function testGetProperty() external {
        int24[1] memory tickSpacings = [int24(200)];

        address[1] memory pools = [0x1e60272caDcFb575247a666c11DBEA146299A2c4];

        for (uint256 i = 0; i < pools.length; i++) {
            assertEq(uint24(tickSpacings[i]), module.getProperty(pools[i]));
        }
    }

    function testBeforeRebalance() external {
        vm.expectRevert();
        module.beforeRebalance(0, new bytes(0), new bytes(0));
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        module.beforeRebalance(
            0,
            abi.encode(
                IVeloAmmModule.CallbackParams({
                    farm: address(0),
                    gauge: address(0),
                    counter: address(0)
                })
            ),
            defaultProtocolParams
        );

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool
        );

        vm.startPrank(Constants.OWNER);
        positionManager.transferFrom(Constants.OWNER, address(this), tokenId);
        vm.stopPrank();

        (bool success, ) = address(module).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.afterRebalance.selector,
                tokenId,
                defaultCallbackParams,
                defaultProtocolParams
            )
        );
        assertTrue(success);

        addRewardToGauge(10 ether, ICLGauge(pool.gauge()));
        skip(10 days);

        (success, ) = address(module).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.beforeRebalance.selector,
                tokenId,
                defaultCallbackParams,
                defaultProtocolParams
            )
        );
        assertTrue(success);

        assertTrue(IERC20(Constants.VELO).balanceOf(testFarmAddress) > 0);
        assertTrue(
            IERC20(Constants.VELO).balanceOf(Constants.PROTOCOL_TREASURY) > 0
        );
    }

    function testAfterRebalance() external {
        vm.expectRevert();
        module.beforeRebalance(0, new bytes(0), new bytes(0));
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        module.beforeRebalance(
            0,
            abi.encode(
                IVeloAmmModule.CallbackParams({
                    farm: address(0),
                    gauge: address(0),
                    counter: address(0)
                })
            ),
            defaultProtocolParams
        );

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool
        );

        vm.startPrank(Constants.OWNER);
        positionManager.transferFrom(Constants.OWNER, address(this), tokenId);
        vm.stopPrank();

        (bool success, ) = address(module).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.afterRebalance.selector,
                tokenId,
                defaultCallbackParams,
                defaultProtocolParams
            )
        );
        assertTrue(success);

        (success, ) = address(module).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.beforeRebalance.selector,
                tokenId,
                defaultCallbackParams,
                defaultProtocolParams
            )
        );
        assertTrue(success);

        (success, ) = address(module).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.afterRebalance.selector,
                tokenId,
                defaultCallbackParams,
                defaultProtocolParams
            )
        );
        assertTrue(success);
        assertEq(positionManager.ownerOf(tokenId), address(pool.gauge()));

        (success, ) = address(module).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.beforeRebalance.selector,
                tokenId,
                defaultCallbackParams,
                defaultProtocolParams
            )
        );
        assertTrue(success);
        assertEq(positionManager.ownerOf(tokenId), address(this));
    }

    function testTransferFrom() external {
        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool
        );

        vm.startPrank(Constants.OWNER);
        positionManager.transferFrom(Constants.OWNER, address(module), tokenId);
        vm.stopPrank();

        assertEq(positionManager.ownerOf(tokenId), address(module));
        module.transferFrom(address(module), Constants.OWNER, tokenId);
        assertEq(positionManager.ownerOf(tokenId), Constants.OWNER);
    }

    function testValidateCallbackParams() external {
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        module.validateCallbackParams(
            abi.encode(
                IVeloAmmModule.CallbackParams({
                    farm: address(0),
                    gauge: address(0),
                    counter: address(0)
                })
            )
        );
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        module.validateCallbackParams(
            abi.encode(
                IVeloAmmModule.CallbackParams({
                    farm: address(1),
                    gauge: address(0),
                    counter: address(0)
                })
            )
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        module.validateCallbackParams(new bytes(123));

        module.validateCallbackParams(
            abi.encode(
                IVeloAmmModule.CallbackParams({
                    farm: address(1),
                    gauge: address(pool.gauge()),
                    counter: address(1)
                })
            )
        );
    }

    function testValidateProtocolParams() external {
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        module.validateProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    feeD9: 3e8,
                    treasury: address(0)
                })
            )
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidFee()"));
        module.validateProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    feeD9: 3e8 + 1,
                    treasury: address(1)
                })
            )
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        module.validateProtocolParams(new bytes(123));

        module.validateProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    feeD9: 3e8,
                    treasury: address(1)
                })
            )
        );
    }
}
