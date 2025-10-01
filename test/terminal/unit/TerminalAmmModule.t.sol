// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Fixture.sol";
import "../mocks/TerminalFarmMock.sol";
import "../mocks/TransferFromMock.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    TerminalAmmModule public module =
        new TerminalAmmModule(INonfungiblePositionManager(Constants.SEPOLIA_POSITION_MANAGER));

    address public TERMINAL = module.getRewardToken(address(poolAB));

    address farm = address(new TerminalFarmMock(TERMINAL, "TerminalFarmMock", "TFM", address(this)));

    bytes public defaultCallbackParams = abi.encode(
        IVeloAmmModule.CallbackParams({farm: farm, gauge: address(poolAB.gauge()), extraData: ""})
    );

    bytes public defaultProtocolParams = abi.encode(
        IVeloAmmModule.ProtocolParams({
            feeD9: 3e8,
            treasury: Constants.TERMINAL_MELLOW_TREASURY,
            extraData: ""
        })
    );

    function addRewardToGauge(uint256 amount, IGauge gauge) public {
        address voter = address(gauge.voter());
        deal(TERMINAL, voter, amount);
        vm.startPrank(voter);
        IERC20(TERMINAL).safeIncreaseAllowance(address(gauge), amount);
        IGauge(gauge).notifyRewardAmount(amount);
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
        module =
            new TerminalAmmModule(INonfungiblePositionManager(Constants.SEPOLIA_POSITION_MANAGER));
    }

    function testTvl() external {
        uint256 tokenId = mint(address(this), 1 ether, true);

        deal(tokenA, address(this), 1e10 ether);
        deal(tokenB, address(this), 1e10 ether);

        (uint160 sqrtPriceX96, int24 tick,,,,,,) = poolAB.slot0();
        {
            (uint256 amount0, uint256 amount1) = module.tvl(tokenId, sqrtPriceX96);
            assertTrue(amount0 > 0 && amount1 > 0);
            (uint256 expected0, uint256 expected1) = module.total(tokenId, sqrtPriceX96);

            assertEq(amount0, expected0);
            assertEq(amount1, expected1);
        }

        (, tick,,,,,,) = poolAB.slot0();
        for (int24 i = 0; i < 10; i++) {
            (sqrtPriceX96,,,,,,,) = poolAB.slot0();

            movePrice(poolAB, TickMath.getSqrtRatioAtTick(tick + int24(i - 5) * 100));

            (uint256 amount0, uint256 amount1) = module.tvl(tokenId, sqrtPriceX96);
            assertTrue(amount0 + amount1 > 0);
            (uint256 expected0, uint256 expected1) = module.total(tokenId, sqrtPriceX96);
            assertEq(amount0, expected0);
            assertEq(amount1, expected1);
        }
    }

    function testGetPositionInfo() external {
        uint256 tokenId = mint(address(this), 1 ether, true);

        IAmmModule.AmmPosition memory position = module.getAmmPosition(tokenId);
        IVeloAmmModule.Position memory position_ = module.getPosition(tokenId);
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

        address[6] memory pools =
            [address(0), address(0), address(0), address(poolAB), address(0), address(0)];

        for (uint256 i = 0; i < 5; i++) {
            assertEq(pools[i], module.getPool(tokenA, tokenB, uint24(tickSpacings[i])));
        }
    }

    function testIsPool() external {
        int24[6] memory tickSpacings =
            [int24(1), int24(50), int24(100), int24(200), int24(2000), int24(2001)];

        bool[6] memory pools = [false, false, false, true, false, false];

        for (uint256 i = 0; i < 5; i++) {
            assertEq(
                pools[i], module.isPool(module.getPool(tokenA, tokenB, uint24(tickSpacings[i])))
            );
        }
    }

    function testGetProperty() external {
        int24[1] memory tickSpacings = [int24(200)];

        address[1] memory pools = [address(poolAB)];

        for (uint256 i = 0; i < pools.length; i++) {
            assertEq(uint24(tickSpacings[i]), module.getProperty(pools[i]));
        }
    }

    function testGetSqrtPriceX96() external {
        (uint160 sqrtPriceX96Expected, int24 tickExpected,,,,,,) = poolAB.slot0();

        assertEq(sqrtPriceX96Expected, module.getSqrtPriceX96(address(poolAB)));
        (uint160 sqrtPriceX96, int24 tick) = module.getSqrtPriceX96AndTick(address(poolAB));
        assertEq(sqrtPriceX96, module.getSqrtPriceX96(address(poolAB)));
        assertEq(tickExpected, tick);
    }

    function testGetToken() external {
        assertEq(tokenA, module.getToken0(address(poolAB)));
        assertEq(tokenB, module.getToken1(address(poolAB)));
        (address token0, address token1) = module.getPoolTokens(address(poolAB));
        assertEq(tokenA, token0);
        assertEq(tokenB, token1);
    }

    function testGetRewardToken() external {
        assertEq(TERMINAL, module.getRewardToken(address(poolAB)));
    }

    function testGetGauge() external {
        assertEq(address(poolAB.gauge()), module.getGauge(address(poolAB)));
    }

    function testCollectRewardsNotStaked() external {
        uint256 tokenId = mint(address(this), 1 ether, false);
        uint160 sqrtPriceX96 = module.getSqrtPriceX96(address(poolAB));
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        bool success;

        addRewardToGauge(1 ether, IGauge(poolAB.gauge()));

        /// @dev move price to generate some fees
        movePrice(poolAB, TickMath.getSqrtRatioAtTick(tick + 10));
        movePrice(poolAB, TickMath.getSqrtRatioAtTick(tick - 10));
        movePrice(poolAB, TickMath.getSqrtRatioAtTick(tick));

        /// @dev skip some time to accumulate rewards
        skip(1 days);

        uint256 amount0Before = IERC20(tokenA).balanceOf(address(this));
        uint256 amount1Before = IERC20(tokenB).balanceOf(address(this));
        uint256 rewardBefore = IERC20(TERMINAL).balanceOf(address(this));
        assertTrue(IERC20(TERMINAL).balanceOf(farm) == 0);

        (success,) = address(module).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.collectRewards.selector,
                tokenId,
                defaultCallbackParams,
                defaultProtocolParams
            )
        );
        assertTrue(success, "collectRewards call failed");
        uint256 amount0After = IERC20(tokenA).balanceOf(address(this));
        uint256 amount1After = IERC20(tokenB).balanceOf(address(this));
        uint256 rewardAfter = IERC20(TERMINAL).balanceOf(address(this));
        assertTrue(IERC20(TERMINAL).balanceOf(farm) == 0);
        assertEq(amount0After, amount0Before, "Token A balance did not change");
        assertEq(amount1After, amount1Before, "Token B balance did not change");
        assertEq(rewardAfter, rewardBefore, "Reward balance did not change");
    }

    function testCollectRewardsStaked() external {
        uint256 tokenId = mint(address(this), 1 ether, true);
        uint160 sqrtPriceX96 = module.getSqrtPriceX96(address(poolAB));
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        bool success;

        TerminalFarmMock(farm).mint(address(this), 1 ether);
        addRewardToGauge(1 ether, IGauge(poolAB.gauge()));

        /// @dev move price to generate some fees
        movePrice(poolAB, TickMath.getSqrtRatioAtTick(tick + 10));
        movePrice(poolAB, TickMath.getSqrtRatioAtTick(tick - 10));
        movePrice(poolAB, TickMath.getSqrtRatioAtTick(tick));

        /// @dev skip some time to accumulate rewards
        skip(1 days);

        uint256 amount0Before = IERC20(tokenA).balanceOf(address(this));
        uint256 amount1Before = IERC20(tokenB).balanceOf(address(this));
        uint256 rewardBefore = IERC20(TERMINAL).balanceOf(address(this));
        assertTrue(IERC20(TERMINAL).balanceOf(farm) == 0);

        (success,) = address(module).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.collectRewards.selector,
                tokenId,
                defaultCallbackParams,
                defaultProtocolParams
            )
        );
        assertTrue(success, "collectRewards call failed");
        uint256 amount0After = IERC20(tokenA).balanceOf(address(this));
        uint256 amount1After = IERC20(tokenB).balanceOf(address(this));
        uint256 rewardAfter = IERC20(TERMINAL).balanceOf(address(this));
        assertTrue(IERC20(TERMINAL).balanceOf(farm) > 0);
        assertEq(amount0After, amount0Before, "Token A balance did not change");
        assertEq(amount1After, amount1Before, "Token B balance did not change");
        assertEq(rewardAfter, rewardBefore, "Reward balance did not change");
    }

    function testBeforeRebalance() external {
        uint256 liquidity = 1 ether;
        uint256 lpAmount = 1 ether;
        uint256 rewardAmount = 10 ether;
        uint256 tokenId = mint(address(this), liquidity, true);

        TerminalFarmMock(farm).mint(address(this), lpAmount);

        (bool success,) = address(module).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.beforeRebalance.selector,
                tokenId,
                defaultCallbackParams,
                defaultProtocolParams
            )
        );
        assertTrue(success, "beforeRebalance call failed");

        addRewardToGauge(rewardAmount, IGauge(poolAB.gauge()));
        uint256 timeSkip = 3 days;
        skip(timeSkip);

        (success,) = address(module).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.beforeRebalance.selector,
                tokenId,
                defaultCallbackParams,
                defaultProtocolParams
            )
        );
        uint256 rewardCollected = IERC20(TERMINAL).balanceOf(farm)
            + IERC20(TERMINAL).balanceOf(Constants.TERMINAL_MELLOW_TREASURY);
        assertTrue(success, "beforeRebalance call failed");
        assertTrue(IERC20(TERMINAL).balanceOf(farm) > 0);
        assertTrue(IERC20(TERMINAL).balanceOf(Constants.TERMINAL_MELLOW_TREASURY) > 0);
        assertEq(positionManager.ownerOf(tokenId), address(this));

        uint256 expectedEarned = rewardAmount * liquidity / poolAB.liquidity();
        assertApproxEqAbs(expectedEarned, rewardCollected, 1);
    }

    function testAfterRebalance() external {
        address gauge = poolAB.gauge();
        vm.expectRevert("Invalid token ID");
        module.beforeRebalance(0, new bytes(0), new bytes(0));

        vm.expectRevert("Invalid token ID");
        module.beforeRebalance(
            0,
            abi.encode(
                IVeloAmmModule.CallbackParams({farm: address(farm), gauge: gauge, extraData: ""})
            ),
            defaultProtocolParams
        );
        uint256 tokenId = mint(Constants.TERMINAL_DEPLOYER, 1 ether, true);

        vm.expectRevert("Not approved");
        module.beforeRebalance(
            tokenId,
            abi.encode(
                IVeloAmmModule.CallbackParams({farm: address(farm), gauge: gauge, extraData: ""})
            ),
            defaultProtocolParams
        );

        tokenId = mint(address(this), 1 ether, true);

        (bool success,) = address(module).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.afterRebalance.selector,
                tokenId,
                abi.encode(
                    IVeloAmmModule.CallbackParams({farm: address(0), gauge: gauge, extraData: ""})
                ),
                defaultProtocolParams
            )
        );
        assertTrue(success, "afterRebalance call failed");
        assertEq(positionManager.ownerOf(tokenId), address(this));

        (success,) = address(module).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.afterRebalance.selector,
                tokenId,
                defaultCallbackParams,
                defaultProtocolParams
            )
        );
        assertTrue(success, "afterRebalance call failed");
        assertEq(positionManager.ownerOf(tokenId), address(this));
    }

    function testTransferFromStaked() external {
        TransferFromMock transferFromMock = new TransferFromMock();

        uint256 tokenId = mint(address(transferFromMock), 1 ether, true);
        addRewardToGauge(1 ether, IGauge(poolAB.gauge()));

        assertTrue(IERC20(TERMINAL).balanceOf(address(this)) == 0);
        assertEq(IERC20(TERMINAL).balanceOf(address(transferFromMock)), 0);
        assertEq(IERC20(TERMINAL).balanceOf(address(farm)), 0);

        assertEq(positionManager.ownerOf(tokenId), address(transferFromMock));

        /// @dev skip some time to accumulate rewards
        skip(1 days);
        transferFromMock.transferFrom(
            address(module), address(transferFromMock), address(this), tokenId
        );

        assertTrue(IERC20(TERMINAL).balanceOf(address(this)) == 0);
        assertTrue(IERC20(TERMINAL).balanceOf(address(transferFromMock)) == 0);
        assertTrue(IERC20(TERMINAL).balanceOf(address(farm)) == 0);
        assertEq(positionManager.ownerOf(tokenId), address(this));

        Address.functionDelegateCall(
            address(module),
            abi.encodeWithSelector(
                IAmmModule.transferFrom.selector, address(this), address(transferFromMock), tokenId
            )
        );
        assertEq(positionManager.ownerOf(tokenId), address(transferFromMock));
        assertTrue(IERC20(TERMINAL).balanceOf(address(this)) == 0);
        assertTrue(IERC20(TERMINAL).balanceOf(address(transferFromMock)) == 0);
        assertTrue(IERC20(TERMINAL).balanceOf(address(farm)) == 0);

        vm.prank(address(transferFromMock));
        positionManager.approve(address(this), tokenId);

        Address.functionDelegateCall(
            address(module),
            abi.encodeWithSelector(
                IAmmModule.transferFrom.selector, address(transferFromMock), address(this), tokenId
            )
        );
        assertTrue(IERC20(TERMINAL).balanceOf(address(this)) == 0);
        assertTrue(IERC20(TERMINAL).balanceOf(address(transferFromMock)) > 0);
        assertTrue(IERC20(TERMINAL).balanceOf(address(farm)) == 0);
        assertEq(positionManager.ownerOf(tokenId), address(this));
    }

    function testTransferFromNotStaked() external {
        TransferFromMock transferFromMock = new TransferFromMock();

        uint256 tokenId = mint(address(transferFromMock), 1 ether, false);
        addRewardToGauge(1 ether, IGauge(poolAB.gauge()));

        uint160 sqrtPriceX96 = module.getSqrtPriceX96(address(poolAB));
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        /// @dev move price to generate some fees
        movePrice(poolAB, TickMath.getSqrtRatioAtTick(tick + 10));
        movePrice(poolAB, TickMath.getSqrtRatioAtTick(tick - 10));
        movePrice(poolAB, TickMath.getSqrtRatioAtTick(tick));

        uint256 amount0ThisBefore = IERC20(tokenA).balanceOf(address(this));
        uint256 amount1ThisBefore = IERC20(tokenB).balanceOf(address(this));
        uint256 amount0MockBefore = IERC20(tokenA).balanceOf(address(transferFromMock));
        uint256 amount1MockBefore = IERC20(tokenB).balanceOf(address(transferFromMock));

        assertTrue(IERC20(TERMINAL).balanceOf(address(this)) == 0);
        assertEq(IERC20(TERMINAL).balanceOf(address(transferFromMock)), 0);
        assertEq(IERC20(TERMINAL).balanceOf(address(farm)), 0);

        assertEq(amount0ThisBefore, IERC20(tokenA).balanceOf(address(this)));
        assertEq(amount1ThisBefore, IERC20(tokenB).balanceOf(address(this)));
        assertEq(amount0MockBefore, IERC20(tokenA).balanceOf(address(transferFromMock)));
        assertEq(amount1MockBefore, IERC20(tokenB).balanceOf(address(transferFromMock)));

        assertEq(positionManager.ownerOf(tokenId), address(transferFromMock));

        /// @dev skip some time to accumulate rewards
        skip(1 days);
        transferFromMock.transferFrom(
            address(module), address(transferFromMock), address(this), tokenId
        );

        assertTrue(IERC20(TERMINAL).balanceOf(address(this)) == 0);
        assertTrue(IERC20(TERMINAL).balanceOf(address(transferFromMock)) == 0);
        assertTrue(IERC20(TERMINAL).balanceOf(address(farm)) == 0);

        assertEq(amount0ThisBefore, IERC20(tokenA).balanceOf(address(this)));
        assertEq(amount1ThisBefore, IERC20(tokenB).balanceOf(address(this)));
        assertEq(amount0MockBefore, IERC20(tokenA).balanceOf(address(transferFromMock)));
        assertEq(amount1MockBefore, IERC20(tokenB).balanceOf(address(transferFromMock)));

        assertEq(positionManager.ownerOf(tokenId), address(this));

        Address.functionDelegateCall(
            address(module),
            abi.encodeWithSelector(
                IAmmModule.transferFrom.selector, address(this), address(transferFromMock), tokenId
            )
        );
        assertEq(positionManager.ownerOf(tokenId), address(transferFromMock));
        assertTrue(IERC20(TERMINAL).balanceOf(address(this)) == 0);
        assertTrue(IERC20(TERMINAL).balanceOf(address(transferFromMock)) == 0);
        assertTrue(IERC20(TERMINAL).balanceOf(address(farm)) == 0);

        assertEq(amount0ThisBefore, IERC20(tokenA).balanceOf(address(this)));
        assertEq(amount1ThisBefore, IERC20(tokenB).balanceOf(address(this)));
        assertEq(amount0MockBefore, IERC20(tokenA).balanceOf(address(transferFromMock)));
        assertEq(amount1MockBefore, IERC20(tokenB).balanceOf(address(transferFromMock)));

        vm.prank(address(transferFromMock));
        positionManager.approve(address(this), tokenId);

        Address.functionDelegateCall(
            address(module),
            abi.encodeWithSelector(
                IAmmModule.transferFrom.selector, address(transferFromMock), address(this), tokenId
            )
        );
        assertTrue(IERC20(TERMINAL).balanceOf(address(this)) == 0);
        assertTrue(IERC20(TERMINAL).balanceOf(address(transferFromMock)) == 0);
        assertTrue(IERC20(TERMINAL).balanceOf(address(farm)) == 0);

        assertEq(amount0ThisBefore, IERC20(tokenA).balanceOf(address(this)));
        assertEq(amount1ThisBefore, IERC20(tokenB).balanceOf(address(this)));
        /// @dev transferFromMock should receive some fees
        assertTrue(amount0MockBefore < IERC20(tokenA).balanceOf(address(transferFromMock)));
        assertTrue(amount1MockBefore < IERC20(tokenB).balanceOf(address(transferFromMock)));
        assertEq(positionManager.ownerOf(tokenId), address(this));
    }

    function testMint() external {
        address user = vm.createWallet("user").addr;
        (, int24 tick) = module.getSqrtPriceX96AndTick(address(poolAB));
        int24 tickSpacing = poolAB.tickSpacing();
        int24 tickAligned = (tick / tickSpacing) * tickSpacing;

        uint256 amount0Init = 2 ether;
        uint256 amount1Init = 2 ether;

        deal(tokenA, user, amount0Init);
        deal(tokenB, user, amount1Init);
        vm.startPrank(user);
        IERC20(tokenA).safeIncreaseAllowance(address(this), amount0Init);
        IERC20(tokenB).safeIncreaseAllowance(address(this), amount1Init);
        vm.stopPrank();

        IAmmModule.MintInfo[] memory infos = new IAmmModule.MintInfo[](2);
        infos[0] = IAmmModule.MintInfo({
            pool: address(poolAB),
            amount0: amount0Init / 2,
            amount1: amount1Init / 2,
            tickLower: tickAligned - 5 * tickSpacing,
            tickUpper: tickAligned + 15 * tickSpacing
        });
        infos[1] = IAmmModule.MintInfo({
            pool: address(poolAB),
            amount0: amount0Init / 2,
            amount1: amount1Init / 2,
            tickLower: tickAligned - 15 * tickSpacing,
            tickUpper: tickAligned + 5 * tickSpacing
        });

        assertEq(IERC20(tokenA).balanceOf(address(module)), 0);
        assertEq(IERC20(tokenB).balanceOf(address(module)), 0);
        bytes memory result = Address.functionDelegateCall(
            address(module), abi.encodeWithSelector(IAmmModule.mint.selector, user, infos)
        );
        uint256[] memory tokenIds = abi.decode(result, (uint256[]));

        uint256 amount0Total;
        uint256 amount1Total;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(positionManager.ownerOf(tokenIds[i]), address(this));
            (uint256 amount0, uint256 amount1) = module.tvl(tokenIds[i]);
            amount0Total += amount0;
            amount1Total += amount1;
        }
        console2.log("Total amounts used:", amount0Total, amount1Total);
        /// @dev check that amounts used for mint and remain amounts on this balance are correct
        assertApproxEqAbs(
            amount0Init - IERC20(tokenA).balanceOf(address(this)),
            amount0Total,
            2,
            "Incorrect amount0 used"
        );
        assertApproxEqAbs(
            amount1Init - IERC20(tokenB).balanceOf(address(this)),
            amount1Total,
            2,
            "Incorrect amount1 used"
        );
        assertEq(IERC20(tokenA).balanceOf(address(module)), 0, "AmmModule should not have token0");
        assertEq(IERC20(tokenB).balanceOf(address(module)), 0, "AmmModule should not have token1");
    }

    function testValidateCallbackParams() external {
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        module.validateCallbackParams(
            address(0),
            abi.encode(
                IVeloAmmModule.CallbackParams({farm: address(0), gauge: address(0), extraData: ""})
            )
        );
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        module.validateCallbackParams(
            address(0),
            abi.encode(
                IVeloAmmModule.CallbackParams({farm: address(1), gauge: address(0), extraData: ""})
            )
        );

        address wrongGauge = address(0x1234567890123456789012345678901234567890);
        vm.expectRevert();
        module.validateCallbackParams(
            address(0),
            abi.encode(
                IVeloAmmModule.CallbackParams({farm: address(1), gauge: wrongGauge, extraData: ""})
            )
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidGauge()"));
        module.validateCallbackParams(
            address(poolAB),
            abi.encode(
                IVeloAmmModule.CallbackParams({farm: address(1), gauge: wrongGauge, extraData: ""})
            )
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        module.validateCallbackParams(address(0), new bytes(123));

        module.validateCallbackParams(
            address(poolAB),
            abi.encode(
                IVeloAmmModule.CallbackParams({
                    farm: address(1),
                    gauge: address(poolAB.gauge()),
                    extraData: ""
                })
            )
        );
    }

    function testValidateProtocolParams() external {
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        module.validateProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({feeD9: 3e8, treasury: address(0), extraData: ""})
            )
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidFee()"));
        module.validateProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({feeD9: 3e8 + 1, treasury: address(1), extraData: ""})
            )
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        module.validateProtocolParams(new bytes(123));

        module.validateProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({feeD9: 3e8, treasury: address(1), extraData: ""})
            )
        );
    }

    function mint(address recipient, uint256 liquidity, bool isStaked) public returns (uint256) {
        (, int24 tick) = module.getSqrtPriceX96AndTick(address(poolAB));
        int24 tickSpacing = poolAB.tickSpacing();
        int24 tickAligned = (tick / tickSpacing) * tickSpacing;
        return mint(
            tickAligned - tickSpacing * 20,
            tickAligned + tickSpacing * 20,
            uint128(liquidity),
            poolAB,
            recipient,
            isStaked
        );
    }
}
