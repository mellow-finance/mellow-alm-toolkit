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
    int24[5] public fees = [int24(1), 50, 100, 200, 2000];

    function setUp() external {
        ammModule = new VeloAmmModule(positionManager);
        depositWithdrawModule = new VeloDepositWithdrawModule(positionManager);
        strategyModule = new PulseStrategyModule();
        oracle = new VeloOracle();
        core = new Core(ammModule, strategyModule, oracle, CORE_ADMIN);

        deployFactoryHelper = new VeloDeployFactoryHelper();
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
                farmOwner: FARM_OWNER,
                farmOperator: FARM_OPERATOR,
                rewardsToken: Constants.VELO
            })
        );

        ICore.DepositParams memory depositParams;
        depositParams.slippageD4 = 5;
        depositParams.securityParams = new bytes(0);

        deployFactory.updateStrategyParams(
            1,
            IVeloDeployFactory.StrategyParams({
                tickNeighborhood: 0,
                intervalWidth: 3,
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                initialLiquidity: 1000000,
                minInitialLiquidity: 800000
            })
        );

        deployFactory.updateDepositParams(1, depositParams);

        deployFactory.updateStrategyParams(
            50,
            IVeloDeployFactory.StrategyParams({
                tickNeighborhood: 0,
                intervalWidth: 200,
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                initialLiquidity: 100000,
                minInitialLiquidity: 80000
            })
        );
        deployFactory.updateDepositParams(50, depositParams);

        deployFactory.updateStrategyParams(
            100,
            IVeloDeployFactory.StrategyParams({
                tickNeighborhood: 0,
                intervalWidth: 500,
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                initialLiquidity: 100000,
                minInitialLiquidity: 80000
            })
        );
        deployFactory.updateDepositParams(100, depositParams);

        deployFactory.updateStrategyParams(
            200,
            IVeloDeployFactory.StrategyParams({
                tickNeighborhood: 0,
                intervalWidth: 1000,
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                initialLiquidity: 100000,
                minInitialLiquidity: 80000
            })
        );
        deployFactory.updateDepositParams(200, depositParams);

        deployFactory.updateStrategyParams(
            2000,
            IVeloDeployFactory.StrategyParams({
                tickNeighborhood: 1000,
                intervalWidth: 10000,
                strategyType: IPulseStrategyModule.StrategyType.Original,
                initialLiquidity: 10000,
                minInitialLiquidity: 8000
            })
        );
        deployFactory.updateDepositParams(2000, depositParams);

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
    ) public returns (uint256 tokenId) {
        vm.startPrank(owner);

        (uint160 sqrtPriceX96, int24 tick, , , , ) = pool.slot0();
        int24 tickLower = tick - width / 2;
        {
            int24 remainder = tickLower % width;
            if (remainder < 0) remainder += width;
            tickLower -= remainder;
        }
        int24 tickUpper = tickLower + width;

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
                deadline: block.timestamp
            })
        );

        vm.stopPrank();
    }

    function swapDust(int24 tickSpacing) public {
        uint256 amount = 10 wei;
        deal(Constants.WETH, address(this), amount);
        IERC20(Constants.WETH).approve(address(swapRouter), amount);
        swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: Constants.WETH,
                tokenOut: Constants.USDC,
                tickSpacing: tickSpacing,
                recipient: address(this),
                deadline: block.timestamp,
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
        vm.startPrank(VELO_DEPLOY_FACTORY_OPERATOR);
        deal(pool.token0(), VELO_DEPLOY_FACTORY_OPERATOR, 1e6);
        deal(pool.token1(), VELO_DEPLOY_FACTORY_OPERATOR, 1e6);

        IERC20(pool.token0()).approve(address(deployFactory), 1e6);
        IERC20(pool.token1()).approve(address(deployFactory), 1e6);

        addresses = deployFactory.createStrategy(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing()
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

    // function _testMultipleUsersMultiplePools() external {
    //     uint256 totalEarned = 0;
    //     uint256 totalFees = 0;

    //     address depositor = address(123);
    //     ICLPool pool = ICLPool(
    //         factory.getPool(Constants.WETH, Constants.USDC, fees[i])
    //     );

    //     vm.prank(VELO_DEPLOY_FACTORY_OPERATOR);
    //     addresses[i] = createStrategy(pool);

    //     vm.startPrank(depositor);
    //     deal(pool.token0(), depositor, 1 ether);
    //     deal(pool.token1(), depositor, 1 ether);
    //     IERC20(pool.token0()).approve(addresses[i].lpWrapper, 1 ether);
    //     IERC20(pool.token1()).approve(addresses[i].lpWrapper, 1 ether);
    //     ILpWrapper(addresses[i].lpWrapper).deposit(
    //         1 ether,
    //         1 ether,
    //         1 ether,
    //         depositor
    //     );

    //     uint256 balance = IERC20(addresses[i].lpWrapper).balanceOf(depositor);

    //     assertTrue(balance >= 1 ether);
    //     IERC20(addresses[i].lpWrapper).approve(
    //         addresses[i].synthetixFarm,
    //         balance
    //     );
    //     StakingRewards(addresses[i].synthetixFarm).stake(balance);
    //     assertEq(
    //         IERC20(addresses[i].synthetixFarm).balanceOf(depositor),
    //         balance
    //     );
    //     vm.stopPrank();

    //     addRewards(pool, 10 ether);
    //     skip(7 days);

    //     vm.startPrank(FARM_OPERATOR);
    //     ILpWrapper(addresses[i].lpWrapper).emptyRebalance();
    //     uint256 addedRewards = IERC20(Constants.VELO).balanceOf(
    //         addresses[i].synthetixFarm
    //     );
    //     StakingRewards(addresses[i].synthetixFarm).notifyRewardAmount(
    //         addedRewards
    //     );
    //     vm.stopPrank();

    //     skip(7 days);

    //     totalEarned += StakingRewards(addresses[i].synthetixFarm).earned(
    //         depositor
    //     );
    //     totalFees = IERC20(Constants.VELO).balanceOf(MELLOW_PROTOCOL_TREASURY);

    //     uint256 currentRatio = (1e9 * totalEarned) / (totalFees + totalEarned);
    //     uint256 expectedRatio = 1e9 - 1e8;
    //     assertApproxEqAbs(currentRatio, expectedRatio, 1);
    // }
}
