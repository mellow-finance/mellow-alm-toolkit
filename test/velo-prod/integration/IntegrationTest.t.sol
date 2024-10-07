// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Integration is Test {
    using SafeERC20 for IERC20;

    // constants:
    address public constant VELO_DEPLOY_FACTORY_ADMIN =
        address(bytes20(keccak256("VELO_DEPLOY_FACTORY_ADMIN")));
    address public constant VELO_DEPLOY_FACTORY_OPERATOR =
        address(bytes20(keccak256("VELO_DEPLOY_FACTORY_OPERATOR")));
    address public constant CORE_ADMIN =
        address(bytes20(keccak256("CORE_ADMIN")));
    address public constant MELLOW_PROTOCOL_TREASURY =
        address(bytes20(keccak256("MELLOW_PROTOCOL_TREASURY")));
    address public constant WRAPPER_ADMIN =
        address(bytes20(keccak256("WRAPPER_ADMIN")));
    address public constant FARM_OWNER =
        address(bytes20(keccak256("FARM_OWNER")));
    address public constant FARM_OPERATOR =
        address(bytes20(keccak256("FARM_OPERATOR")));
    uint32 public constant MELLOW_PROTOCOL_FEE = 1e8;
    address public constant DEPOSITOR =
        address(bytes20(keccak256("DEPOSITOR")));

    // mellow contracts:
    Core public core;
    VeloAmmModule public ammModule;
    VeloDepositWithdrawModule public depositWithdrawModule;
    VeloOracle public oracle;
    PulseStrategyModule public strategyModule;
    VeloDeployFactoryHelper public deployFactoryHelper;
    VeloDeployFactory public deployFactory;

    // velodrome contracts:
    INonfungiblePositionManager public positionManager =
        INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER);
    ICLFactory public factory = ICLFactory(Constants.VELO_FACTORY);

    ISwapRouter public swapRouter =
        ISwapRouter(address(new SwapRouter(address(factory), Constants.WETH)));

    IQuoterV2 public quoterV2 =
        IQuoterV2(address(new QuoterV2(address(factory), Constants.WETH)));

    // parameters:
    int24[1] public fees = [int24(200)];

    function setUp() external virtual {
        ammModule = new VeloAmmModule(positionManager);
        depositWithdrawModule = new VeloDepositWithdrawModule(positionManager);
        strategyModule = new PulseStrategyModule();
        oracle = new VeloOracle();
        core = new Core(ammModule, strategyModule, oracle, CORE_ADMIN);

        deployFactoryHelper = new VeloDeployFactoryHelper(Constants.WETH);
        deployFactory = new VeloDeployFactory(
            VELO_DEPLOY_FACTORY_ADMIN,
            core,
            depositWithdrawModule,
            deployFactoryHelper
        );

        vm.prank(CORE_ADMIN);
        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    feeD9: MELLOW_PROTOCOL_FEE,
                    treasury: MELLOW_PROTOCOL_TREASURY
                })
            )
        );

        vm.startPrank(VELO_DEPLOY_FACTORY_ADMIN);

        deployFactory.updateMutableParams(
            IVeloDeployFactory.MutableParams({
                lpWrapperAdmin: WRAPPER_ADMIN,
                lpWrapperManager: address(0),
                farmOwner: FARM_OWNER,
                farmOperator: FARM_OPERATOR,
                minInitialLiquidity: 1000
            })
        );

        deployFactory.grantRole(
            deployFactory.ADMIN_DELEGATE_ROLE(),
            VELO_DEPLOY_FACTORY_ADMIN
        );

        deployFactory.grantRole(
            deployFactory.OPERATOR(),
            VELO_DEPLOY_FACTORY_OPERATOR
        );

        vm.stopPrank();
    }

    function mint(
        ICLPool pool,
        uint128 liquidity,
        int24 width,
        address owner
    ) public returns (uint256 tokenId, int24 tickLower, int24 tickUpper) {
        vm.startPrank(owner);

        (uint160 sqrtPriceX96, int24 tick, , , , ) = pool.slot0();
        tickLower = tick - width / 2;
        {
            int24 remainder = tickLower % width;
            if (remainder < 0) remainder += width;
            tickLower -= remainder;
        }
        tickUpper = tickLower + width;

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity + 1
            );

        deal(pool.token0(), owner, amount0);
        deal(pool.token1(), owner, amount1);

        IERC20(pool.token0()).approve(address(positionManager), amount0);
        IERC20(pool.token1()).approve(address(positionManager), amount1);

        (tokenId, , , ) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: pool.token0(),
                token1: pool.token1(),
                tickLower: tickLower,
                tickUpper: tickUpper,
                tickSpacing: pool.tickSpacing(),
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: owner,
                deadline: type(uint256).max,
                sqrtPriceX96: 0
            })
        );

        vm.stopPrank();
    }

    function swapDust(int24 tickSpacing) public {
        uint256 amount = 0.1 ether;
        deal(Constants.WETH, address(this), amount);
        IERC20(Constants.WETH).approve(address(swapRouter), amount);
        swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: Constants.WETH,
                tokenOut: Constants.OP,
                tickSpacing: tickSpacing,
                recipient: address(this),
                deadline: type(uint256).max,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function createStrategy(
        ICLPool pool
    ) public returns (IVeloDeployFactory.PoolAddresses memory addresses) {
        pool.increaseObservationCardinalityNext(2);
        mint(pool, 1000000, pool.tickSpacing() * 4, address(this));
        swapDust(pool.tickSpacing());

        (uint256 tokenId, , ) = mint(
            pool,
            1e8,
            pool.tickSpacing() * 4,
            VELO_DEPLOY_FACTORY_OPERATOR
        );
        vm.startPrank(VELO_DEPLOY_FACTORY_OPERATOR);
        positionManager.approve(address(deployFactory), tokenId);
        addresses = deployFactory.createStrategy(
            IVeloDeployFactory.DeployParams({
                securityParams: abi.encode(
                    IVeloOracle.SecurityParams({
                        lookback: 1,
                        maxAge: 7 days,
                        maxAllowedDelta: type(int24).max
                    })
                ),
                slippageD9: 5 * 1e5,
                tokenId: tokenId,
                tickNeighborhood: 0,
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing
            })
        );
        vm.stopPrank();
    }

    function addRewards(ICLPool pool, uint256 amount) public {
        ICLGauge gauge = ICLGauge(pool.gauge());
        address voter = address(gauge.voter());
        address rewardToken = gauge.rewardToken();
        deal(rewardToken, voter, amount);
        vm.startPrank(voter);
        IERC20(rewardToken).safeIncreaseAllowance(address(gauge), amount);
        ICLGauge(gauge).notifyRewardAmount(amount);
        vm.stopPrank();
    }

    function testMultiplePools() external {
        IVeloDeployFactory.PoolAddresses[]
            memory addresses = new IVeloDeployFactory.PoolAddresses[](
                fees.length
            );

        uint256 totalEarned = 0;
        uint256 totalFees = 0;
        for (uint256 i = 0; i < fees.length; i++) {
            ICLPool pool = ICLPool(
                factory.getPool(Constants.WETH, Constants.OP, fees[i])
            );
            addresses[i] = createStrategy(pool);
            vm.prank(VELO_DEPLOY_FACTORY_ADMIN);
            deployFactory.removeAddressesForPool(address(pool));
            addresses[i] = createStrategy(pool);
            vm.startPrank(DEPOSITOR);
            deal(pool.token0(), DEPOSITOR, 1 ether);
            deal(pool.token1(), DEPOSITOR, 1 ether);
            IERC20(pool.token0()).approve(addresses[i].lpWrapper, 1 ether);
            IERC20(pool.token1()).approve(addresses[i].lpWrapper, 1 ether);
            ILpWrapper(addresses[i].lpWrapper).deposit(
                1 ether,
                1 ether,
                1 ether,
                DEPOSITOR,
                type(uint256).max
            );

            uint256 balance = IERC20(addresses[i].lpWrapper).balanceOf(
                DEPOSITOR
            );

            assertTrue(balance >= 1 ether);
            IERC20(addresses[i].lpWrapper).approve(
                addresses[i].synthetixFarm,
                balance
            );
            StakingRewards(addresses[i].synthetixFarm).stake(balance);
            assertEq(
                IERC20(addresses[i].synthetixFarm).balanceOf(DEPOSITOR),
                balance
            );
            vm.stopPrank();

            addRewards(pool, 10 ether);
            skip(7 days);

            vm.prank(WRAPPER_ADMIN);
            ILpWrapper(addresses[i].lpWrapper).emptyRebalance();

            uint256 addedRewards = IERC20(Constants.VELO).balanceOf(
                addresses[i].synthetixFarm
            );

            vm.prank(FARM_OPERATOR);
            StakingRewards(addresses[i].synthetixFarm).notifyRewardAmount(
                addedRewards
            );

            skip(7 days);

            totalEarned += StakingRewards(addresses[i].synthetixFarm).earned(
                DEPOSITOR
            );
            totalFees = IERC20(Constants.VELO).balanceOf(
                MELLOW_PROTOCOL_TREASURY
            );

            uint256 currentRatio = (1e9 * totalEarned) /
                (totalFees + totalEarned);
            uint256 expectedRatio = 1e9 - 1e8;
            assertApproxEqAbs(currentRatio, expectedRatio, 1);
        }
    }

    function testMultipleUsersMultiplePools() external {
        IVeloDeployFactory.PoolAddresses[]
            memory addresses = new IVeloDeployFactory.PoolAddresses[](
                fees.length
            );

        uint256 totalEarned = 0;
        uint256 totalFees = 0;

        for (uint256 i = 0; i < fees.length; i++) {
            address depositor = address(
                bytes20(
                    abi.encodePacked(keccak256("DEPOSITOR"), vm.toString(i))
                )
            );
            ICLPool pool = ICLPool(
                factory.getPool(Constants.WETH, Constants.OP, fees[i])
            );
            addresses[i] = createStrategy(pool);
            vm.prank(VELO_DEPLOY_FACTORY_ADMIN);
            deployFactory.removeAddressesForPool(address(pool));
            addresses[i] = createStrategy(pool);

            vm.startPrank(depositor);
            deal(pool.token0(), depositor, 1 ether);
            deal(pool.token1(), depositor, 1 ether);
            IERC20(pool.token0()).approve(addresses[i].lpWrapper, 1 ether);
            IERC20(pool.token1()).approve(addresses[i].lpWrapper, 1 ether);
            ILpWrapper(addresses[i].lpWrapper).deposit(
                1 ether,
                1 ether,
                1 ether,
                depositor,
                type(uint256).max
            );

            uint256 balance = IERC20(addresses[i].lpWrapper).balanceOf(
                depositor
            );

            assertTrue(balance >= 1 ether);
            IERC20(addresses[i].lpWrapper).approve(
                addresses[i].synthetixFarm,
                balance
            );
            StakingRewards(addresses[i].synthetixFarm).stake(balance);
            assertEq(
                IERC20(addresses[i].synthetixFarm).balanceOf(depositor),
                balance
            );
            vm.stopPrank();

            addRewards(pool, 10 ether);
            skip(7 days);

            vm.startPrank(FARM_OPERATOR);
            ILpWrapper(addresses[i].lpWrapper).emptyRebalance();
            uint256 addedRewards = IERC20(Constants.VELO).balanceOf(
                addresses[i].synthetixFarm
            );
            StakingRewards(addresses[i].synthetixFarm).notifyRewardAmount(
                addedRewards
            );
            vm.stopPrank();

            skip(7 days);

            totalEarned += StakingRewards(addresses[i].synthetixFarm).earned(
                depositor
            );
            totalFees = IERC20(Constants.VELO).balanceOf(
                MELLOW_PROTOCOL_TREASURY
            );

            uint256 currentRatio = (1e9 * totalEarned) /
                (totalFees + totalEarned);
            uint256 expectedRatio = 1e9 - 1e8;
            assertApproxEqAbs(currentRatio, expectedRatio, 1);
        }
    }
}
