// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    VeloAmmModule public module = new VeloAmmModule(
        INonfungiblePositionManager(Constants.OPTIMISM_POSITION_MANAGER),
        Constants.OPTIMISM_IS_POOL_SELECTOR
    );

    ICLPool public pool =
        ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
    address public VELO = ICLGauge(pool.gauge()).rewardToken();

    address farm = address(new VeloFarmMock());

    bytes public defaultCallbackParams =
        abi.encode(IVeloAmmModule.CallbackParams({farm: farm, gauge: address(pool.gauge())}));

    bytes public defaultProtocolParams = abi.encode(
        IVeloAmmModule.ProtocolParams({feeD9: 3e8, treasury: Constants.OPTIMISM_MELLOW_TREASURY})
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

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    function testConstructor() external {
        module = new VeloAmmModule(
            INonfungiblePositionManager(Constants.OPTIMISM_POSITION_MANAGER),
            Constants.OPTIMISM_IS_POOL_SELECTOR
        );
    }

    function testGetAmountsForLiquidity() external {
        {
            uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(1234);
            int24 tickLower = -1234;
            int24 tickUpper = 1234;
            (uint256 amount0, uint256 amount1) =
                module.getAmountsForLiquidity(1000, sqrtRatioX96, tickLower, tickUpper);
            assertTrue(amount0 == 0);
            assertTrue(amount1 > 0);
        }

        {
            uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(-1234);
            int24 tickLower = -1234;
            int24 tickUpper = 1234;
            (uint256 amount0, uint256 amount1) =
                module.getAmountsForLiquidity(1000, sqrtRatioX96, tickLower, tickUpper);
            assertTrue(amount0 > 0);
            assertTrue(amount1 == 0);
        }

        {
            uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(0);
            int24 tickLower = -1234;
            int24 tickUpper = 1234;
            (uint256 amount0, uint256 amount1) =
                module.getAmountsForLiquidity(1000, sqrtRatioX96, tickLower, tickUpper);
            assertTrue(amount0 == amount1);
            assertTrue(amount0 > 0);
        }

        {
            uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(100);
            int24 tickLower = -1234;
            int24 tickUpper = 1234;
            (uint256 amount0, uint256 amount1) =
                module.getAmountsForLiquidity(1000, sqrtRatioX96, tickLower, tickUpper);
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
            pool,
            Constants.OPTIMISM_DEPLOYER
        );
        (uint160 sqrtPriceX96,,,,,) = pool.slot0();

        {
            (uint256 amount0, uint256 amount1) =
                module.tvl(tokenId, sqrtPriceX96, defaultCallbackParams, defaultProtocolParams);
            assertTrue(amount0 > 0 && amount1 > 0);
            (uint256 expected0, uint256 expected1) =
                PositionValue.total(positionManager, tokenId, sqrtPriceX96);

            assertEq(amount0, expected0);
            assertEq(amount1, expected1);
        }

        (, int24 tick,,,,) = pool.slot0();
        for (int24 i = 0; i < 10; i++) {
            (sqrtPriceX96,,,,,) = pool.slot0();

            movePrice(pool, TickMath.getSqrtRatioAtTick(tick + int24(i - 5) * 100));

            (uint256 amount0, uint256 amount1) =
                module.tvl(tokenId, sqrtPriceX96, defaultCallbackParams, defaultProtocolParams);
            assertTrue(amount0 + amount1 > 0);
            (uint256 expected0, uint256 expected1) =
                PositionValue.total(positionManager, tokenId, sqrtPriceX96);
            assertEq(amount0, expected0);
            assertEq(amount1, expected1);
        }
    }

    function testGetPositionInfo() external {
        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool,
            Constants.OPTIMISM_DEPLOYER
        );
        IAmmModule.AmmPosition memory position = module.getAmmPosition(tokenId);
        PositionLibrary.Position memory position_ =
            PositionLibrary.getPosition(address(positionManager), tokenId);
        assertEq(position.tickLower, position_.tickLower, "tickLower should be equal");
        assertEq(position.tickUpper, position_.tickUpper, "tickUpper should be equal");
        assertEq(position.liquidity, position_.liquidity, "liquidity should be equal");
        assertEq(position.token0, position_.token0, "token0 should be equal");
        assertEq(position.token1, position_.token1, "token1 should be equal");
        assertEq(int24(position.property), position_.tickSpacing, "tickSpacing should be equal");
    }

    function testGetPool() external {
        int24[6] memory tickSpacings =
            [int24(1), int24(50), int24(100), int24(200), int24(2000), int24(2001)];

        address[6] memory pools = [
            address(0),
            address(0),
            address(0),
            address(0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60),
            address(0),
            address(0)
        ];

        for (uint256 i = 0; i < 5; i++) {
            assertEq(
                pools[i],
                module.getPool(
                    Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, uint24(tickSpacings[i])
                )
            );
        }
    }

    function testGetProperty() external {
        int24[1] memory tickSpacings = [int24(200)];

        address[1] memory pools = [0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60];

        for (uint256 i = 0; i < pools.length; i++) {
            assertEq(uint24(tickSpacings[i]), module.getProperty(pools[i]));
        }
    }

    function testBeforeRebalance() external {
        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool,
            address(this)
        );

        positionManager.approve(pool.gauge(), tokenId);
        (bool success,) = address(module).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.beforeRebalance.selector,
                tokenId,
                defaultCallbackParams,
                defaultProtocolParams
            )
        );
        assertTrue(success);
        ICLGauge(pool.gauge()).deposit(tokenId);

        addRewardToGauge(10 ether, ICLGauge(pool.gauge()));
        skip(10 days);

        (success,) = address(module).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.beforeRebalance.selector,
                tokenId,
                defaultCallbackParams,
                defaultProtocolParams
            )
        );
        assertTrue(success);

        assertTrue(IERC20(VELO).balanceOf(farm) > 0);
        assertTrue(IERC20(VELO).balanceOf(Constants.OPTIMISM_MELLOW_TREASURY) > 0);
        assertEq(positionManager.ownerOf(tokenId), address(this));
    }

    function testAfterRebalance() external {
        vm.expectRevert();
        module.beforeRebalance(0, new bytes(0), new bytes(0));
        vm.expectRevert("ERC721: owner query for nonexistent token");
        module.beforeRebalance(
            0,
            abi.encode(IVeloAmmModule.CallbackParams({farm: address(0), gauge: address(0)})),
            defaultProtocolParams
        );

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool,
            Constants.OPTIMISM_DEPLOYER
        );

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);
        positionManager.transferFrom(Constants.OPTIMISM_DEPLOYER, address(this), tokenId);
        vm.stopPrank();

        (bool success,) = address(module).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.afterRebalance.selector,
                tokenId,
                abi.encode(
                    IVeloAmmModule.CallbackParams({
                        farm: address(0),
                        gauge: address(new GaugeMock(address(pool)))
                    })
                ),
                defaultProtocolParams
            )
        );
        assertTrue(success);
        assertEq(positionManager.ownerOf(tokenId), address(this));

        (success,) = address(module).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.afterRebalance.selector,
                tokenId,
                defaultCallbackParams,
                defaultProtocolParams
            )
        );
        assertEq(positionManager.ownerOf(tokenId), address(pool.gauge()));
        assertTrue(success);
    }

    function testTransferFrom() external {
        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool,
            Constants.OPTIMISM_DEPLOYER
        );

        vm.startPrank(Constants.OPTIMISM_DEPLOYER);
        positionManager.transferFrom(Constants.OPTIMISM_DEPLOYER, address(module), tokenId);
        vm.stopPrank();

        assertEq(positionManager.ownerOf(tokenId), address(module));
        module.transferFrom(address(module), Constants.OPTIMISM_DEPLOYER, tokenId);
        assertEq(positionManager.ownerOf(tokenId), Constants.OPTIMISM_DEPLOYER);
    }

    function testValidateCallbackParams() external {
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        module.validateCallbackParams(
            abi.encode(IVeloAmmModule.CallbackParams({farm: address(0), gauge: address(0)}))
        );
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        module.validateCallbackParams(
            abi.encode(IVeloAmmModule.CallbackParams({farm: address(1), gauge: address(0)}))
        );

        address wrongGuauge = address(new GaugeMock(address(pool)));
        vm.expectRevert(abi.encodeWithSignature("InvalidGauge()"));
        module.validateCallbackParams(
            abi.encode(IVeloAmmModule.CallbackParams({farm: address(1), gauge: wrongGuauge}))
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        module.validateCallbackParams(new bytes(123));

        module.validateCallbackParams(
            abi.encode(
                IVeloAmmModule.CallbackParams({farm: address(1), gauge: address(pool.gauge())})
            )
        );
    }

    function testValidateProtocolParams() external {
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        module.validateProtocolParams(
            abi.encode(IVeloAmmModule.ProtocolParams({feeD9: 3e8, treasury: address(0)}))
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidFee()"));
        module.validateProtocolParams(
            abi.encode(IVeloAmmModule.ProtocolParams({feeD9: 3e8 + 1, treasury: address(1)}))
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        module.validateProtocolParams(new bytes(123));

        module.validateProtocolParams(
            abi.encode(IVeloAmmModule.ProtocolParams({feeD9: 3e8, treasury: address(1)}))
        );
    }
}
