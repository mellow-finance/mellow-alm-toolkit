// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

import "../../../src/bots/EmptyBot.sol";

import "src/utils/VeloDeployFactory.sol";
import "src/utils/VeloDeployFactoryHelper.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    int24 constant MAX_ALLOWED_DELTA = 100;
    uint32 constant MAX_AGE = 1 hours;
    uint128 INITIAL_LIQUIDITY = 1 ether;
    LpWrapper public lpWrapper;
    StakingRewards public farm;
    ICLPool public pool = ICLPool(factory.getPool(Constants.OP, Constants.WETH, 200));

    function _depositToken(uint256 tokenId_, address owner) private returns (uint256 id) {
        vm.startPrank(Constants.OWNER);
        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    treasury: Constants.PROTOCOL_TREASURY,
                    feeD9: Constants.PROTOCOL_FEE_D9
                })
            )
        );

        positionManager.approve(address(core), tokenId_);

        ICore.DepositParams memory depositParams;
        depositParams.ammPositionIds = new uint256[](1);
        depositParams.ammPositionIds[0] = tokenId_;
        depositParams.owner = owner;
        depositParams.callbackParams = abi.encode(
            IVeloAmmModule.CallbackParams({
                gauge: address(pool.gauge()),
                farm: address(1),
                counter: address(
                    new Counter(Constants.OWNER, address(core), Constants.VELO, address(1))
                )
            })
        );
        depositParams.strategyParams = abi.encode(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.Original,
                width: 1000,
                tickSpacing: 200,
                tickNeighborhood: 100,
                maxLiquidityRatioDeviationX96: 0
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

    function _createStrategy() private {
        vm.startPrank(Constants.OWNER);
        if (veloFactory.poolToAddresses(address(pool)).lpWrapper != address(0)) {
            veloFactory.removeAddressesForPool(address(pool));
        }
        vm.stopPrank();

        vm.startPrank(Constants.OWNER);

        IVeloDeployFactory.DeployParams memory parameters = IVeloDeployFactory.DeployParams({
            pool: pool,
            strategyType: IPulseStrategyModule.StrategyType.Original,
            width: pool.tickSpacing() * 20,
            tickNeighborhood: 0,
            slippageD9: 5 * 1e5,
            maxAmount0: 1 ether,
            maxAmount1: 1 ether,
            maxLiquidityRatioDeviationX96: 0,
            totalSupplyLimit: 1000 ether,
            securityParams: abi.encode(
                IVeloOracle.SecurityParams({
                    lookback: 1,
                    maxAllowedDelta: MAX_ALLOWED_DELTA,
                    maxAge: MAX_AGE
                })
            ),
            tokenId: new uint256[](0)
        });

        deal(pool.token0(), Constants.OWNER, 1000 ether);
        deal(pool.token1(), Constants.OWNER, 1000 ether);

        IERC20(pool.token0()).approve(address(factoryDeposit), type(uint256).max);
        IERC20(pool.token1()).approve(address(factoryDeposit), type(uint256).max);

        IVeloDeployFactory.PoolAddresses memory addresses = veloFactory.createStrategy(parameters);

        lpWrapper = LpWrapper(payable(addresses.lpWrapper));
        farm = StakingRewards(addresses.synthetixFarm);

        vm.stopPrank();
    }

    function testConstructor() external {
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        lpWrapper =
            new LpWrapper("", "", address(0), Constants.WETH, address(veloFactory), address(pool));
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        lpWrapper =
            new LpWrapper("", "", address(1), address(0), address(veloFactory), address(pool));
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        lpWrapper = new LpWrapper("", "", address(1), Constants.WETH, address(0), address(pool));
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        lpWrapper =
            new LpWrapper("", "", address(1), Constants.WETH, address(veloFactory), address(0));

        lpWrapper = new LpWrapper(
            "Name", "Symbol", address(1), Constants.WETH, address(veloFactory), address(pool)
        );

        assertEq(lpWrapper.name(), "Name");
        assertEq(lpWrapper.symbol(), "Symbol");
    }

    function testInitialize() external {
        lpWrapper = new LpWrapper(
            "Wrapper LP Token",
            "WLP",
            Constants.OWNER,
            Constants.WETH,
            address(veloFactory),
            address(pool)
        );

        uint256 tokenId_ = mint(
            pool.token0(), pool.token1(), pool.tickSpacing(), pool.tickSpacing() * 2, 1 ether, pool
        );

        uint256 positionId = _depositToken(tokenId_, Constants.OWNER);

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        lpWrapper.initialize(positionId, 5e5, type(uint256).max);

        positionId = _depositToken(
            mint(
                pool.token0(),
                pool.token1(),
                pool.tickSpacing(),
                pool.tickSpacing() * 2,
                1 ether,
                pool
            ),
            address(lpWrapper)
        );

        lpWrapper.initialize(positionId, 1 ether, type(uint256).max);

        assertApproxEqAbs(lpWrapper.totalSupply(), 1 ether, 1);
        assertApproxEqAbs(lpWrapper.balanceOf(address(lpWrapper)), 1 ether, 1);

        vm.expectRevert(abi.encodeWithSignature("AlreadyInitialized()"));
        lpWrapper.initialize(positionId, 1 ether, type(uint256).max);
    }

    function testDeposit() external {
        pool.increaseObservationCardinalityNext(2);

        lpWrapper = new LpWrapper(
            "Wrapper LP Token",
            "WLP",
            Constants.OWNER,
            Constants.WETH,
            address(veloFactory),
            address(pool)
        );

        uint256 tokenId_ = mint(
            pool.token0(), pool.token1(), pool.tickSpacing(), pool.tickSpacing() * 20, 10000, pool
        );
        uint256 positionId = _depositToken(tokenId_, address(lpWrapper));

        lpWrapper.initialize(positionId, 5e5, type(uint256).max);

        vm.startPrank(Constants.DEPOSITOR);

        deal(pool.token0(), Constants.DEPOSITOR, 1 ether);
        deal(pool.token1(), Constants.DEPOSITOR, 1 ether);

        IERC20(pool.token0()).approve(address(lpWrapper), 1 ether);
        IERC20(pool.token1()).approve(address(lpWrapper), 1 ether);

        vm.expectRevert(abi.encodeWithSignature("InsufficientLpAmount()"));
        lpWrapper.deposit(1 ether, 1 ether, 100 ether, Constants.DEPOSITOR, type(uint256).max);

        uint256 totalSupplyBefore = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionBefore = ammModule.getAmmPosition(tokenId_);

        (uint256 amount0, uint256 amount1, uint256 lpAmount) =
            lpWrapper.deposit(1 ether, 1 ether, 0.228 ether, Constants.DEPOSITOR, type(uint256).max);

        assertTrue(amount0 >= 4.736e14);
        assertTrue(amount1 >= 0.99 ether);
        assertTrue(lpAmount >= 0.228 ether);
        assertEq(lpWrapper.balanceOf(Constants.DEPOSITOR), lpAmount);

        uint256 totalSupplyAfter = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionAfter = ammModule.getAmmPosition(tokenId_);

        {
            uint256 expectedLiquidityIncrease = Math.mulDiv(
                positionBefore.liquidity, totalSupplyAfter - totalSupplyBefore, totalSupplyBefore
            );

            assertApproxEqAbs(
                expectedLiquidityIncrease, positionAfter.liquidity - positionBefore.liquidity, 1 wei
            );

            assertEq(
                Math.mulDiv(
                    positionAfter.liquidity - positionBefore.liquidity,
                    totalSupplyBefore,
                    positionBefore.liquidity
                ),
                totalSupplyAfter - totalSupplyBefore
            );
        }

        vm.expectRevert(abi.encodeWithSignature("InsufficientAmounts()"));
        lpWrapper.deposit(1 ether, 1 ether, 0 ether, Constants.DEPOSITOR, type(uint256).max);

        deal(pool.token0(), Constants.DEPOSITOR, 1 ether);
        deal(pool.token1(), Constants.DEPOSITOR, 1 ether);

        vm.expectRevert(abi.encodeWithSignature("InsufficientAllowance()"));
        lpWrapper.deposit(1 ether, 1 ether, 0 ether, Constants.DEPOSITOR, type(uint256).max);

        vm.stopPrank();
    }

    function testTotalSupplyLimitUpdate() external {
        lpWrapper = new LpWrapper(
            "Wrapper LP Token",
            "WLP",
            Constants.OWNER,
            Constants.WETH,
            address(veloFactory),
            address(pool)
        );

        uint256 positionId = _depositToken(
            mint(
                pool.token0(),
                pool.token1(),
                pool.tickSpacing(),
                pool.tickSpacing() * 2,
                1 ether - 1,
                pool
            ),
            address(lpWrapper)
        );

        lpWrapper.initialize(positionId, 1 ether, 1 ether);

        assertApproxEqAbs(lpWrapper.totalSupply(), 1 ether, 1);
        assertApproxEqAbs(lpWrapper.balanceOf(address(lpWrapper)), 1 ether, 1);
        assertEq(lpWrapper.totalSupplyLimit(), 1 ether);

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        lpWrapper.setTotalSupplyLimit(2 ether);
        assertEq(lpWrapper.totalSupplyLimit(), 1 ether);

        vm.prank(Constants.OWNER);
        lpWrapper.setTotalSupplyLimit(2 ether);
        assertEq(lpWrapper.totalSupplyLimit(), 2 ether);
    }

    function testTotalSupplyLimit() external {
        lpWrapper = new LpWrapper(
            "Wrapper LP Token",
            "WLP",
            Constants.OWNER,
            Constants.WETH,
            address(veloFactory),
            address(pool)
        );

        uint256 positionId0 = _depositToken(
            mint(
                pool.token0(),
                pool.token1(),
                pool.tickSpacing(),
                pool.tickSpacing() * 2,
                1 ether - 1,
                pool
            ),
            address(lpWrapper)
        );

        vm.expectRevert(abi.encodeWithSignature("TotalSupplyLimitReached()"));
        lpWrapper.initialize(positionId0, 1 ether, 1 ether / 2);

        lpWrapper.initialize(positionId0, 1 ether, 1 ether);

        assertApproxEqAbs(lpWrapper.totalSupply(), 1 ether, 1);
        assertApproxEqAbs(lpWrapper.balanceOf(address(lpWrapper)), 1 ether, 1);

        deal(pool.token0(), Constants.DEPOSITOR, 100 wei);
        deal(pool.token1(), Constants.DEPOSITOR, 100 wei);

        vm.startPrank(Constants.DEPOSITOR);
        IERC20(pool.token0()).approve(address(lpWrapper), 100 wei);
        IERC20(pool.token1()).approve(address(lpWrapper), 100 wei);
        vm.expectRevert(abi.encodeWithSignature("TotalSupplyLimitReached()"));
        lpWrapper.deposit(100 wei, 100 wei, 0, Constants.DEPOSITOR, type(uint256).max);
        vm.stopPrank();
    }

    function testWithdraw() external {
        _createStrategy();

        vm.startPrank(Constants.DEPOSITOR);

        deal(pool.token0(), Constants.DEPOSITOR, 1 ether);
        deal(pool.token1(), Constants.DEPOSITOR, 1 ether);

        IERC20(pool.token0()).approve(address(lpWrapper), 1 ether);
        IERC20(pool.token1()).approve(address(lpWrapper), 1 ether);

        lpWrapper.deposit(1 ether, 1 ether, 0.1 ether, Constants.DEPOSITOR, type(uint256).max);

        ICore.ManagedPositionInfo memory position = core.managedPositionAt(core.positionCount() - 1);
        uint256 totalSupplyBefore = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionBefore =
            ammModule.getAmmPosition(position.ammPositionIds[0]);

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

        lpWrapper.withdraw(balance / 2, 0, 0, Constants.DEPOSITOR, type(uint256).max);

        assertApproxEqAbs(
            depositorBalance - balance / 2, lpWrapper.balanceOf(Constants.DEPOSITOR), 0 wei
        );

        uint256 totalSupplyAfter = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionAfter =
            ammModule.getAmmPosition(position.ammPositionIds[0]);

        {
            uint256 expectedLiquidityDecrease = Math.mulDiv(
                positionBefore.liquidity, totalSupplyBefore - totalSupplyAfter, totalSupplyBefore
            );
            assertApproxEqAbs(
                expectedLiquidityDecrease, positionBefore.liquidity - positionAfter.liquidity, 1 wei
            );
        }

        vm.stopPrank();
    }

    function testDepositAndStake() external {
        _createStrategy();

        vm.startPrank(Constants.DEPOSITOR);

        deal(pool.token0(), Constants.DEPOSITOR, 1 ether);
        deal(pool.token1(), Constants.DEPOSITOR, 1 ether);

        IERC20(pool.token0()).approve(address(lpWrapper), 1 ether);
        IERC20(pool.token1()).approve(address(lpWrapper), 1 ether);

        vm.expectRevert(abi.encodeWithSignature("InsufficientLpAmount()"));
        lpWrapper.depositAndStake(
            1 ether, 1 ether, 100 ether, Constants.DEPOSITOR, type(uint256).max
        );

        ICore.ManagedPositionInfo memory position = core.managedPositionAt(core.positionCount() - 1);

        uint256 totalSupplyBefore = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionBefore =
            ammModule.getAmmPosition(position.ammPositionIds[0]);

        (uint256 amount0, uint256 amount1, uint256 lpAmount) = lpWrapper.depositAndStake(
            1 ether, 1 ether, 0.228 ether, Constants.DEPOSITOR, type(uint256).max
        );

        assertTrue(amount0 >= 6.459e14);
        assertTrue(amount1 >= 0.99 ether);
        assertTrue(lpAmount >= 0.267 ether);
        assertEq(lpWrapper.balanceOf(Constants.DEPOSITOR), 0); // because lpAmount was staked immediately
        assertEq(farm.balanceOf(Constants.DEPOSITOR), lpAmount); // because lpAmount was staked immediately

        uint256 totalSupplyAfter = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionAfter =
            ammModule.getAmmPosition(position.ammPositionIds[0]);

        {
            uint256 expectedLiquidityIncrease = Math.mulDiv(
                positionBefore.liquidity, totalSupplyAfter - totalSupplyBefore, totalSupplyBefore
            );

            assertApproxEqAbs(
                expectedLiquidityIncrease, positionAfter.liquidity - positionBefore.liquidity, 1 wei
            );

            assertEq(
                Math.mulDiv(
                    positionAfter.liquidity - positionBefore.liquidity,
                    totalSupplyBefore,
                    positionBefore.liquidity
                ),
                totalSupplyAfter - totalSupplyBefore
            );

            assertEq(totalSupplyAfter - totalSupplyBefore, farm.totalSupply());
        }

        vm.expectRevert(abi.encodeWithSignature("InsufficientAmounts()"));
        lpWrapper.depositAndStake(1 ether, 1 ether, 0 ether, Constants.DEPOSITOR, type(uint256).max);

        deal(pool.token0(), Constants.DEPOSITOR, 1 ether);
        deal(pool.token1(), Constants.DEPOSITOR, 1 ether);

        vm.expectRevert(abi.encodeWithSignature("InsufficientAllowance()"));
        lpWrapper.depositAndStake(1 ether, 1 ether, 0 ether, Constants.DEPOSITOR, type(uint256).max);

        vm.stopPrank();
    }

    function testUnstakeAndWithdraw() external {
        _createStrategy();

        vm.startPrank(Constants.DEPOSITOR);

        deal(pool.token0(), Constants.DEPOSITOR, 1 ether);
        deal(pool.token1(), Constants.DEPOSITOR, 1 ether);

        IERC20(pool.token0()).approve(address(lpWrapper), 1 ether);
        IERC20(pool.token1()).approve(address(lpWrapper), 1 ether);

        lpWrapper.depositAndStake(
            1 ether, 1 ether, 0.228 ether, Constants.DEPOSITOR, type(uint256).max
        );

        uint256 depositorBalance = farm.balanceOf(Constants.DEPOSITOR); // because all tokens were staked

        vm.expectRevert(abi.encodeWithSignature("InsufficientAmounts()"));
        lpWrapper.unstakeAndWithdraw(
            depositorBalance / 2,
            type(uint256).max,
            type(uint256).max,
            Constants.DEPOSITOR,
            type(uint256).max
        );

        ICore.ManagedPositionInfo memory position = core.managedPositionAt(lpWrapper.positionId());
        uint256 totalSupplyBefore = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionBefore =
            ammModule.getAmmPosition(position.ammPositionIds[0]);

        lpWrapper.unstakeAndWithdraw(
            depositorBalance / 2, 0, 0, Constants.DEPOSITOR, type(uint256).max
        );

        assertApproxEqAbs(depositorBalance / 2, farm.balanceOf(Constants.DEPOSITOR), 1 wei);

        lpWrapper.unstakeAndWithdraw(
            type(uint256).max, 0, 0, Constants.DEPOSITOR, type(uint256).max
        );
        uint256 totalSupplyAfter = lpWrapper.totalSupply();
        IAmmModule.AmmPosition memory positionAfter =
            ammModule.getAmmPosition(position.ammPositionIds[0]);

        {
            uint256 expectedLiquidityDecrease = Math.mulDiv(
                positionBefore.liquidity, totalSupplyBefore - totalSupplyAfter, totalSupplyBefore
            );
            assertApproxEqAbs(
                expectedLiquidityDecrease, positionBefore.liquidity - positionAfter.liquidity, 1 wei
            );

            /* assertEq(
                lpWrapper.totalSupply() - totalSupplyBefore,
                farm.totalSupply()
            ); */
        }

        vm.stopPrank();
    }

    function testReward() external {
        _createStrategy();

        vm.startPrank(Constants.DEPOSITOR);

        deal(pool.token0(), Constants.DEPOSITOR, 1 ether);
        deal(pool.token1(), Constants.DEPOSITOR, 1 ether);

        IERC20(pool.token0()).approve(address(lpWrapper), 1 ether);
        IERC20(pool.token1()).approve(address(lpWrapper), 1 ether);

        lpWrapper.depositAndStake(
            1 ether, 1 ether, 0.228 ether, Constants.DEPOSITOR, type(uint256).max
        );
        vm.stopPrank();

        address gauge = pool.gauge();
        address rewardToken = ICLGauge(gauge).rewardToken();

        for (uint256 i = 0; i < 10; i++) {
            skip(7 days);
            deal(rewardToken, Constants.FARM_OWNER, 1 ether);

            vm.prank(Constants.FARM_OWNER);
            IERC20(rewardToken).transfer(address(farm), 1 ether);

            vm.prank(Constants.OWNER);
            farm.setRewardsDistribution(Constants.FARM_OWNER);

            vm.prank(Constants.FARM_OWNER);
            farm.notifyRewardAmount(1 ether);
        }

        vm.startPrank(Constants.DEPOSITOR);
        uint256 eranedAmount = lpWrapper.earned(Constants.DEPOSITOR);

        lpWrapper.getReward();
        uint256 rewardedAmount = IERC20(rewardToken).balanceOf(Constants.DEPOSITOR);

        console2.log("  earned:", eranedAmount);
        console2.log("rewarded:", rewardedAmount);

        assertEq(eranedAmount, rewardedAmount);
        vm.stopPrank();
    }
}
