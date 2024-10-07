// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

import "../../../src/bots/EmptyBot.sol";
import "src/utils/VeloDeployFactoryHelper.sol";
import "src/utils/VeloDeployFactory.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    int24 constant MAX_ALLOWED_DELTA = 100;
    uint32 constant MAX_AGE = 1 hours;
    uint128 INITIAL_LIQUIDITY = 1 ether;

    VeloOracle public oracle = new VeloOracle();
    VeloAmmModule public ammModule =
        new VeloAmmModule(positionManager, Constants.IS_POOL_SELECTOR);
    VeloDepositWithdrawModule public depositWithdrawModule =
        new VeloDepositWithdrawModule(positionManager);
    PulseStrategyModule public strategyModule = new PulseStrategyModule();
    Core public core =
        new Core(ammModule, strategyModule, oracle, Constants.OWNER);
    LpWrapper public lpWrapper;
    StakingRewards public farm;

    ICLPool public pool =
        ICLPool(factory.getPool(Constants.OP, Constants.WETH, 200));

    VeloDeployFactoryHelper helper =
        new VeloDeployFactoryHelper(Constants.WETH);
    VeloDeployFactory veloFactory =
        new VeloDeployFactory(
            Constants.OWNER,
            core,
            depositWithdrawModule,
            helper
        );

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
                maxAllowedDelta: MAX_ALLOWED_DELTA,
                maxAge: MAX_AGE
            })
        );

        id = core.deposit(depositParams);

        vm.stopPrank();
    }

    function _createStrategy(
        uint256 tokenId
    ) private returns (IVeloDeployFactory.PoolAddresses memory addresses) {
        vm.startPrank(Constants.OWNER);
        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    feeD9: Constants.PROTOCOL_FEE_D9,
                    treasury: Constants.PROTOCOL_TREASURY
                })
            )
        );
        positionManager.approve(address(veloFactory), tokenId);
        veloFactory.updateMutableParams(
            IVeloDeployFactory.MutableParams({
                lpWrapperAdmin: Constants.WRAPPER_ADMIN,
                lpWrapperManager: address(0),
                farmOwner: Constants.FARM_OWNER,
                farmOperator: Constants.FARM_OPERATOR,
                minInitialLiquidity: 1000
            })
        );

        addresses = veloFactory.createStrategy(
            IVeloDeployFactory.DeployParams({
                tickNeighborhood: 0,
                slippageD9: 5 * 1e5,
                tokenId: tokenId,
                securityParams: abi.encode(
                    IVeloOracle.SecurityParams({
                        lookback: 1,
                        maxAllowedDelta: MAX_ALLOWED_DELTA,
                        maxAge: MAX_AGE
                    })
                ),
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing
            })
        );
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
            Constants.WETH,
            address(0),
            address(0)
        );

        lpWrapper = new LpWrapper(
            core,
            depositWithdrawModule,
            "Name",
            "Symbol",
            address(1),
            Constants.WETH,
            address(0),
            address(0)
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
            Constants.WETH,
            address(0),
            address(0)
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
            Constants.WETH,
            address(0),
            address(0)
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
                0.228 ether,
                Constants.DEPOSITOR,
                type(uint256).max
            );

        assertTrue(amount0 >= 4.736e14);
        assertTrue(amount1 >= 0.99 ether);
        assertTrue(lpAmount >= 0.228 ether);
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
            Constants.WETH,
            address(0),
            address(0)
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

    function testDepositAndStake() external {
        pool.increaseObservationCardinalityNext(100);

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 20,
            INITIAL_LIQUIDITY,
            pool
        );

        IVeloDeployFactory.PoolAddresses memory addresses = _createStrategy(
            tokenId
        );
        lpWrapper = LpWrapper(payable(addresses.lpWrapper));
        farm = StakingRewards(addresses.synthetixFarm);

        vm.startPrank(Constants.DEPOSITOR);

        deal(pool.token0(), Constants.DEPOSITOR, 1 ether);
        deal(pool.token1(), Constants.DEPOSITOR, 1 ether);

        IERC20(pool.token0()).approve(address(lpWrapper), 1 ether);
        IERC20(pool.token1()).approve(address(lpWrapper), 1 ether);

        vm.expectRevert(abi.encodeWithSignature("InsufficientLpAmount()"));
        lpWrapper.depositAndStake(
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
            .depositAndStake(
                1 ether,
                1 ether,
                0.228 ether,
                Constants.DEPOSITOR,
                type(uint256).max
            );

        assertTrue(amount0 >= 4.736e14);
        assertTrue(amount1 >= 0.99 ether);
        assertTrue(lpAmount >= 0.228 ether);
        assertEq(lpWrapper.balanceOf(Constants.DEPOSITOR), 0); // because lpAmount was staked immediately
        assertEq(farm.balanceOf(Constants.DEPOSITOR), lpAmount); // because lpAmount was staked immediately

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

            assertEq(
                lpWrapper.totalSupply() - INITIAL_LIQUIDITY,
                farm.totalSupply()
            );
        }

        vm.expectRevert(abi.encodeWithSignature("DepositCallFailed()"));
        lpWrapper.depositAndStake(
            1 ether,
            1 ether,
            100 ether,
            Constants.DEPOSITOR,
            type(uint256).max
        );

        vm.stopPrank();
    }

    function testUnstakeAndWithdraw() external {
        pool.increaseObservationCardinalityNext(2);

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 20,
            INITIAL_LIQUIDITY,
            pool
        );

        IVeloDeployFactory.PoolAddresses memory addresses = _createStrategy(
            tokenId
        );
        lpWrapper = LpWrapper(payable(addresses.lpWrapper));
        farm = StakingRewards(addresses.synthetixFarm);

        vm.startPrank(Constants.DEPOSITOR);

        deal(pool.token0(), Constants.DEPOSITOR, 1 ether);
        deal(pool.token1(), Constants.DEPOSITOR, 1 ether);

        IERC20(pool.token0()).approve(address(lpWrapper), 1 ether);
        IERC20(pool.token1()).approve(address(lpWrapper), 1 ether);

        lpWrapper.depositAndStake(
            1 ether,
            1 ether,
            0.228 ether,
            Constants.DEPOSITOR,
            type(uint256).max
        );

        uint256 totalSupplyBefore = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionBefore = ammModule.getAmmPosition(
            tokenId
        );

        uint256 depositorBalance = farm.balanceOf(Constants.DEPOSITOR); // because all tokens were staked
        uint256 balance = farm.balanceOf(Constants.DEPOSITOR); // because all tokens were staked

        vm.expectRevert(abi.encodeWithSignature("InsufficientAmounts()"));
        lpWrapper.unstakeAndWithdraw(
            balance / 2,
            type(uint256).max,
            type(uint256).max,
            Constants.DEPOSITOR,
            type(uint256).max
        );

        lpWrapper.unstakeAndWithdraw(
            balance / 2,
            0,
            0,
            Constants.DEPOSITOR,
            type(uint256).max
        );

        assertApproxEqAbs(
            depositorBalance - balance / 2,
            farm.balanceOf(Constants.DEPOSITOR),
            0 wei
        );

        lpWrapper.unstakeAndWithdraw(
            type(uint256).max,
            0,
            0,
            Constants.DEPOSITOR,
            type(uint256).max
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

            assertEq(
                lpWrapper.totalSupply() - INITIAL_LIQUIDITY,
                farm.totalSupply()
            );
        }

        vm.stopPrank();
    }

    function testReward() external {
        pool.increaseObservationCardinalityNext(2);

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 20,
            INITIAL_LIQUIDITY,
            pool
        );

        IVeloDeployFactory.PoolAddresses memory addresses = _createStrategy(
            tokenId
        );
        lpWrapper = LpWrapper(payable(addresses.lpWrapper));
        farm = StakingRewards(addresses.synthetixFarm);

        vm.startPrank(Constants.DEPOSITOR);

        deal(pool.token0(), Constants.DEPOSITOR, 1 ether);
        deal(pool.token1(), Constants.DEPOSITOR, 1 ether);

        IERC20(pool.token0()).approve(address(lpWrapper), 1 ether);
        IERC20(pool.token1()).approve(address(lpWrapper), 1 ether);

        lpWrapper.depositAndStake(
            1 ether,
            1 ether,
            0.228 ether,
            Constants.DEPOSITOR,
            type(uint256).max
        );
        vm.stopPrank();

        address gauge = pool.gauge();
        address rewardToken = ICLGauge(gauge).rewardToken();

        for (uint i = 0; i < 10; i++) {
            skip(7 days);
            vm.startPrank(Constants.FARM_OWNER);
            deal(rewardToken, Constants.FARM_OWNER, 1 ether);
            IERC20(rewardToken).transfer(address(farm), 1 ether);
            farm.setRewardsDistribution(Constants.FARM_OWNER);
            farm.notifyRewardAmount(1 ether);
            vm.stopPrank();
        }

        vm.startPrank(Constants.DEPOSITOR);
        uint256 eranedAmount = lpWrapper.earned(Constants.DEPOSITOR);

        lpWrapper.getReward();
        uint256 rewardedAmount = IERC20(rewardToken).balanceOf(
            Constants.DEPOSITOR
        );

        console2.log("  earned:", eranedAmount);
        console2.log("rewarded:", rewardedAmount);

        assertEq(eranedAmount, rewardedAmount);
        vm.stopPrank();
    }
}
