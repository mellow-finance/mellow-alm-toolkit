// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

import "../../../src/bots/EmptyBot.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    VeloOracle public oracle = new VeloOracle();
    VeloAmmModule public ammModule = new VeloAmmModule(positionManager);
    VeloDepositWithdrawModule public depositWithdrawModule =
        new VeloDepositWithdrawModule(positionManager);
    PulseStrategyModule public strategyModule = new PulseStrategyModule();
    Core public core =
        new Core(ammModule, strategyModule, oracle, Constants.OWNER);
    LpWrapper public lpWrapper;

    ICLPool public pool =
        ICLPool(factory.getPool(Constants.OP, Constants.WETH, 200));

    function _depositToken(
        uint256 tokenId,
        address owner
    ) private returns (uint256 id) {
        vm.startPrank(Constants.OWNER);
        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    treasury: Constants.PROTOCOL_TREASURY,
                    feeD9: Constants.PROTOCOL_FEE_D9
                })
            )
        );

        positionManager.approve(address(core), tokenId);

        ICore.DepositParams memory depositParams;
        depositParams.ammPositionIds = new uint256[](1);
        depositParams.ammPositionIds[0] = tokenId;
        depositParams.owner = owner;
        depositParams.callbackParams = abi.encode(
            IVeloAmmModule.CallbackParams({
                gauge: address(pool.gauge()),
                farm: address(1),
                counter: address(
                    new Counter(
                        Constants.OWNER,
                        address(core),
                        Constants.VELO,
                        address(1)
                    )
                )
            })
        );
        depositParams.strategyParams = abi.encode(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.Original,
                width: 1000,
                tickSpacing: 200,
                tickNeighborhood: 100
            })
        );
        depositParams.slippageD9 = 1 * 1e5;
        depositParams.securityParams = abi.encode(
            IVeloOracle.SecurityParams({
                lookback: 1,
                maxAllowedDelta: 100000,
                maxAge: 7 days
            })
        );

        id = core.deposit(depositParams);

        vm.stopPrank();
    }

    function testConstructor() external {
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        lpWrapper = new LpWrapper(
            core,
            depositWithdrawModule,
            "",
            "",
            address(0),
            Constants.WETH
        );

        lpWrapper = new LpWrapper(
            core,
            depositWithdrawModule,
            "Name",
            "Symbol",
            address(1),
            Constants.WETH
        );

        assertEq(lpWrapper.name(), "Name");
        assertEq(lpWrapper.symbol(), "Symbol");
    }

    function testInitialize() external {
        lpWrapper = new LpWrapper(
            core,
            depositWithdrawModule,
            "Wrapper LP Token",
            "WLP",
            Constants.OWNER,
            Constants.WETH
        );

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool
        );

        uint256 positionId = _depositToken(tokenId, Constants.OWNER);

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        lpWrapper.initialize(positionId, 1 ether);

        positionId = _depositToken(
            mint(
                pool.token0(),
                pool.token1(),
                pool.tickSpacing(),
                pool.tickSpacing() * 2,
                10000,
                pool
            ),
            address(lpWrapper)
        );

        lpWrapper.initialize(positionId, 1 ether);

        assertEq(lpWrapper.totalSupply(), 1 ether);
        assertEq(lpWrapper.balanceOf(address(lpWrapper)), 1 ether);

        vm.expectRevert(abi.encodeWithSignature("AlreadyInitialized()"));
        lpWrapper.initialize(positionId, 1 ether);
    }

    function testDeposit() external {
        pool.increaseObservationCardinalityNext(2);
        lpWrapper = new LpWrapper(
            core,
            depositWithdrawModule,
            "Wrapper LP Token",
            "WLP",
            Constants.OWNER,
            Constants.WETH
        );

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 20,
            10000,
            pool
        );
        uint256 positionId = _depositToken(tokenId, address(lpWrapper));

        lpWrapper.initialize(positionId, 10000);

        vm.startPrank(Constants.DEPOSITOR);

        deal(pool.token0(), Constants.DEPOSITOR, 1 ether);
        deal(pool.token1(), Constants.DEPOSITOR, 1 ether);

        IERC20(pool.token0()).approve(address(lpWrapper), 1 ether);
        IERC20(pool.token1()).approve(address(lpWrapper), 1 ether);

        vm.expectRevert(abi.encodeWithSignature("InsufficientLpAmount()"));
        lpWrapper.deposit(
            1 ether,
            1 ether,
            100 ether,
            Constants.DEPOSITOR,
            type(uint256).max
        );

        uint256 totalSupplyBefore = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionBefore = ammModule.getAmmPosition(
            tokenId
        );

        (uint256 amount0, uint256 amount1, uint256 lpAmount) = lpWrapper
            .deposit(
                1 ether,
                1 ether,
                0.3 ether,
                Constants.DEPOSITOR,
                type(uint256).max
            );

        assertTrue(amount0 >= 8e14);
        assertTrue(amount1 >= 0.99 ether);
        assertTrue(lpAmount >= 0.3 ether);
        assertEq(lpWrapper.balanceOf(Constants.DEPOSITOR), lpAmount);

        uint256 totalSupplyAfter = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionAfter = ammModule.getAmmPosition(
            tokenId
        );

        {
            uint256 expectedLiquidityIncrease = FullMath.mulDiv(
                positionBefore.liquidity,
                totalSupplyAfter - totalSupplyBefore,
                totalSupplyBefore
            );

            assertApproxEqAbs(
                expectedLiquidityIncrease,
                positionAfter.liquidity - positionBefore.liquidity,
                1 wei
            );

            assertEq(
                FullMath.mulDiv(
                    positionAfter.liquidity - positionBefore.liquidity,
                    totalSupplyBefore,
                    positionBefore.liquidity
                ),
                totalSupplyAfter - totalSupplyBefore
            );
        }

        vm.expectRevert(abi.encodeWithSignature("DepositCallFailed()"));
        lpWrapper.deposit(
            1 ether,
            1 ether,
            100 ether,
            Constants.DEPOSITOR,
            type(uint256).max
        );

        vm.stopPrank();
    }

    function testWithdraw() external {
        pool.increaseObservationCardinalityNext(2);
        lpWrapper = new LpWrapper(
            core,
            depositWithdrawModule,
            "Wrapper LP Token",
            "WLP",
            Constants.OWNER,
            Constants.WETH
        );

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 20,
            10000,
            pool
        );
        uint256 positionId = _depositToken(tokenId, address(lpWrapper));

        lpWrapper.initialize(positionId, 10000);

        vm.startPrank(Constants.DEPOSITOR);

        deal(pool.token0(), Constants.DEPOSITOR, 1 ether);
        deal(pool.token1(), Constants.DEPOSITOR, 1 ether);

        IERC20(pool.token0()).approve(address(lpWrapper), 1 ether);
        IERC20(pool.token1()).approve(address(lpWrapper), 1 ether);

        lpWrapper.deposit(
            1 ether,
            1 ether,
            0.1 ether,
            Constants.DEPOSITOR,
            type(uint256).max
        );

        uint256 totalSupplyBefore = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionBefore = ammModule.getAmmPosition(
            tokenId
        );

        uint256 depositorBalance = lpWrapper.balanceOf(Constants.DEPOSITOR);

        uint256 balance = lpWrapper.balanceOf(Constants.DEPOSITOR);

        vm.expectRevert(abi.encodeWithSignature("InsufficientAmounts()"));
        lpWrapper.withdraw(
            balance / 2,
            type(uint256).max,
            type(uint256).max,
            Constants.DEPOSITOR,
            type(uint256).max
        );

        lpWrapper.withdraw(
            balance / 2,
            0,
            0,
            Constants.DEPOSITOR,
            type(uint256).max
        );

        assertApproxEqAbs(
            depositorBalance - balance / 2,
            lpWrapper.balanceOf(Constants.DEPOSITOR),
            0 wei
        );

        uint256 totalSupplyAfter = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionAfter = ammModule.getAmmPosition(
            tokenId
        );

        {
            uint256 expectedLiquidityDecrease = FullMath.mulDiv(
                positionBefore.liquidity,
                totalSupplyBefore - totalSupplyAfter,
                totalSupplyBefore
            );
            assertApproxEqAbs(
                expectedLiquidityDecrease,
                positionBefore.liquidity - positionAfter.liquidity,
                1 wei
            );
        }

        vm.stopPrank();
    }
}
