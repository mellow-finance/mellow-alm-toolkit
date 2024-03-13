// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Integration is Test {
    using EnumerableSet for EnumerableSet.AddressSet;
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

    function createStrategy(
        ICLPool pool
    ) public returns (IVeloDeployFactory.PoolAddresses memory addresses) {
        pool.increaseObservationCardinalityNext(2);
        mint(pool, 1000000, pool.tickSpacing() * 4, address(this));
        // swapDust(pool.tickSpacing());
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

    enum Actions {
        DEPOSIT,
        WITHDRAW,
        REBALANCE,
        PUSH_REWARDS,
        SWAP,
        MEV,
        ADD_REWARDS,
        IDLE
    }

    function _execute(Actions[] memory actions) private {
        EnumerableSet.AddressSet storage depositors;

        for (uint256 i = 0; i < actions.length; i++) {
            Actions action = actions[i];
            // TODO:
        }
    }

    function _deposit(
        address user,
        ILpWrapper wrapper,
        uint256 ratioD2
    ) private {
        vm.startPrank(user);
        ICore.PositionInfo memory info = core.position(wrapper.positionId());
        (uint160 sqrtPriceX96, , , , , ) = ICLPool(info.pool).slot0();
        (uint256 amount0, uint256 amount1) = ammModule.tvl(
            info.tokenIds[0],
            sqrtPriceX96,
            new bytes(0),
            new bytes(0)
        );
        ICLPool pool = ICLPool(info.pool);

        amount0 = (amount0 * ratioD2) / 1e2 + 1;
        amount1 = (amount1 * ratioD2) / 1e2 + 1;

        uint256 lpAmount = (IERC20(address(wrapper)).totalSupply() * ratioD2) /
            1e2;

        deal(pool.token0(), user, amount0);
        deal(pool.token1(), user, amount1);
        IERC20(pool.token0()).approve(address(wrapper), amount0);
        IERC20(pool.token1()).approve(address(wrapper), amount1);
        wrapper.deposit(amount0, amount1, (lpAmount * 999) / 1000, user);
        vm.stopPrank();
    }

    function _withdraw(
        address user,
        uint256 lpAmount,
        ILpWrapper wrapper
    ) private {
        vm.startPrank(user);
        ICore.PositionInfo memory info = core.position(wrapper.positionId());
        (uint160 sqrtPriceX96, , , , , ) = ICLPool(info.pool).slot0();
        (uint256 amount0, uint256 amount1) = ammModule.tvl(
            info.tokenIds[0],
            sqrtPriceX96,
            new bytes(0),
            new bytes(0)
        );
        uint256 totalSupply = IERC20(address(wrapper)).totalSupply();
        amount0 = (amount0 * lpAmount) / totalSupply;
        amount1 = (amount1 * lpAmount) / totalSupply;
        wrapper.withdraw(
            lpAmount,
            (amount0 * 999) / 1000,
            (amount1 * 999) / 1000,
            user
        );
        vm.stopPrank();
    }

    function _swap(
        address user,
        ICLPool pool,
        bool dir,
        uint256 amount
    ) private returns (uint256) {
        vm.startPrank(user);
        address tokenIn = dir ? pool.token0() : pool.token1();
        address tokenOut = dir ? pool.token1() : pool.token0();
        deal(tokenIn, user, amount);
        IERC20(tokenIn).approve(address(swapRouter), amount);
        uint256 amountOut = swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                tickSpacing: pool.tickSpacing(),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        vm.stopPrank();
        return amountOut;
    }

    function _addRewards(ICLPool pool, uint256 amount) private {
        ICLGauge gauge = ICLGauge(pool.gauge());
        address voter = address(gauge.voter());
        address rewardToken = gauge.rewardToken();
        deal(rewardToken, voter, amount);
        vm.startPrank(voter);
        IERC20(rewardToken).safeIncreaseAllowance(address(gauge), amount);
        ICLGauge(gauge).notifyRewardAmount(amount);
        vm.stopPrank();
    }

    function _pushRewards(
        address user,
        ILpWrapper wrapper,
        StakingRewards farm
    ) private {
        vm.startPrank(user);
        wrapper.emptyRebalance();

        uint256 rewards = IERC20(Constants.VELO).balanceOf(address(farm));
        if (block.timestamp < farm.periodFinish()) {
            rewards -=
                (farm.periodFinish() - block.timestamp) *
                farm.rewardRate();
        }
        StakingRewards(farm).notifyRewardAmount(rewards);
        vm.stopPrank();
    }

    function _rebalance(address user) private {
        vm.startPrank(user);

        vm.stopPrank();
    }

    // function test() external {
    //     address depositor = address(123);
    //     ICLPool pool = ICLPool(
    //         factory.getPool(Constants.WETH, Constants.USDC, 200)
    //     );

    //     vm.prank(VELO_DEPLOY_FACTORY_OPERATOR);
    //     IVeloDeployFactory.PoolAddresses memory addresses = createStrategy(
    //         pool
    //     );

    //     vm.startPrank(FARM_OPERATOR);
    //     ILpWrapper(addresses.lpWrapper).emptyRebalance();
    //     uint256 addedRewards = IERC20(Constants.VELO).balanceOf(
    //         addresses.synthetixFarm
    //     );
    //     StakingRewards(addresses.synthetixFarm).notifyRewardAmount(
    //         addedRewards
    //     );
    //     vm.stopPrank();

    //     skip(7 days);
    // }

    function test() external {
        address weth = Constants.WETH;
        address reward = Constants.VELO;
        address owner = address(1);
        address operator = address(2);
        address user1 = address(3);
        address user2 = address(4);

        deal(weth, user1, 1 ether);
        deal(weth, user2, 1 ether);

        StakingRewards farm = new StakingRewards(owner, operator, reward, weth);

        vm.startPrank(user1);
        IERC20(weth).approve(address(farm), 1 ether);
        farm.stake(1 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        IERC20(weth).approve(address(farm), 1 ether);
        farm.stake(1 ether);
        vm.stopPrank();

        deal(reward, address(farm), 1 ether);

        vm.prank(operator);
        farm.notifyRewardAmount(1 ether);

        skip(7 days);

        vm.prank(user1);
        farm.getReward();
        vm.prank(user2);
        farm.getReward();

        console2.log(
            IERC20(reward).balanceOf(user1),
            IERC20(reward).balanceOf(user2)
        );

        // console2.log(farm.earned(user1), farm.earned(user2));

        // vm.prank(operator);
        // farm.notifyRewardAmount(1 ether);

        // skip(7 days);

        // console2.log(farm.earned(user1), farm.earned(user2));
    }

    function test2() external {
        address weth = Constants.WETH;
        address reward = Constants.VELO;
        address owner = address(1);
        address operator = address(2);
        address user1 = address(3);
        address user2 = address(4);

        deal(weth, user1, 1 ether);
        deal(weth, user2, 1 ether);

        StakingRewards farm = new StakingRewards(owner, operator, reward, weth);

        vm.startPrank(user1);
        IERC20(weth).approve(address(farm), 1 ether);
        farm.stake(1 ether);
        vm.stopPrank();

        vm.startPrank(user2);
        IERC20(weth).approve(address(farm), 1 ether);
        farm.stake(1 ether);
        vm.stopPrank();

        deal(reward, address(farm), 1 ether);

        vm.prank(operator);
        farm.notifyRewardAmount(1 ether);

        skip(7 days);

        vm.prank(operator);
        farm.notifyRewardAmount(1 ether);

        skip(7 days);

        vm.prank(user1);
        farm.getReward();
        // vm.prank(user2);
        // farm.getReward();

        console2.log(
            IERC20(reward).balanceOf(user1),
            IERC20(reward).balanceOf(user2)
        );
    }
}
