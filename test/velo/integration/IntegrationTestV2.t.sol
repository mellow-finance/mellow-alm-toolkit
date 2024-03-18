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

    // helpers:
    PulseVeloBot public bot =
        new PulseVeloBot(quoterV2, swapRouter, positionManager);

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
        mint(pool, 1e19, pool.tickSpacing() * 1000, address(this));
        _swap(address(this), pool, false, 2 wei);
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

    function _execute(
        ILpWrapper wrapper,
        StakingRewards farm,
        ICLPool pool,
        Actions[] memory actions
    ) private {
        EnumerableSet.AddressSet storage depositors;
        for (uint256 i = 0; i < actions.length; i++) {
            Actions action = actions[i];
            if (action == Actions.DEPOSIT) {
                _deposit(address(this), wrapper, 100);
            } else if (action == Actions.WITHDRAW) {
                _withdraw(address(this), 1e18, wrapper);
            } else if (action == Actions.REBALANCE) {
                _rebalance(address(this), wrapper);
            } else if (action == Actions.PUSH_REWARDS) {
                _pushRewards(address(this), wrapper, farm);
            } else if (action == Actions.SWAP) {
                _swap(address(this), pool, true, 1e6);
            } else if (action == Actions.MEV) {
                // vm.startPrank(address(this));
                // // TODO
                // depositors.add(address(this));
                // vm.stopPrank();
            } else if (action == Actions.ADD_REWARDS) {
                _addRewards(pool, 1 ether);
            } else if (action == Actions.IDLE) {
                _idle(1 days);
            }
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

        ICore.PositionInfo memory info = core.position(wrapper.positionId());
        IVeloAmmModule.CallbackParams memory callbackParams = abi.decode(
            info.callbackParams,
            (IVeloAmmModule.CallbackParams)
        );
        Counter counter = Counter(callbackParams.counter);
        if (counter.value() != 0 && block.timestamp >= farm.periodFinish()) {
            farm.notifyRewardAmount(counter.value());
            counter.reset();
        }
        vm.stopPrank();
    }

    function _rebalance(address user, ILpWrapper wrapper) private {
        uint256 positionId = wrapper.positionId();
        ICore.PositionInfo memory info = core.position(positionId);
        (bool flag, ICore.TargetPositionInfo memory target) = core
            .strategyModule()
            .getTargets(info, core.ammModule(), core.oracle());
        if (!flag) {
            console2.log("Nothing to rebalance");
            return;
        }

        (uint160 sqrtPriceX96, , , , , ) = ICLPool(info.pool).slot0();
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

        ) = positionManager.positions(info.tokenIds[0]);

        (uint256 target0, uint256 target1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(target.lowerTicks[0]),
                TickMath.getSqrtRatioAtTick(target.upperTicks[0]),
                uint128(target.minLiquidities[0] * 1001) / 1000 + 1
            );

        (uint256 current0, uint256 current1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );

        ISwapRouter.ExactInputSingleParams[]
            memory params = new ISwapRouter.ExactInputSingleParams[](1);
        if (target0 > current0) {
            params[0] = ISwapRouter.ExactInputSingleParams({
                tokenIn: token0,
                tokenOut: token1,
                recipient: address(bot),
                deadline: block.timestamp,
                amountIn: target0 - current0,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0,
                tickSpacing: tickSpacing
            });
        } else if (target1 > current1) {
            params[0] = ISwapRouter.ExactInputSingleParams({
                tokenIn: token1,
                tokenOut: token0,
                recipient: address(bot),
                deadline: block.timestamp,
                amountIn: target1 - current1,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0,
                tickSpacing: tickSpacing
            });
        } else {
            revert("Invalid state - to much liquidity");
        }

        ICore.RebalanceParams memory rebalanceParams;
        rebalanceParams.ids = new uint256[](1);
        rebalanceParams.ids[0] = positionId;
        rebalanceParams.callback = address(bot);
        rebalanceParams.data = abi.encode(params);

        vm.startPrank(user);
        try core.rebalance(rebalanceParams) {
            console2.log("Successfully rebalanced");
        } catch {
            console2.log("Failed to rebalance");
        }
        vm.stopPrank();
    }

    function _idle(uint256 seconds_) private {
        skip(seconds_);
    }

    function _mev(
        address user,
        ICLPool pool,
        ILpWrapper wrapper,
        bool dir,
        uint256 amount
    ) private {
        uint256 amountOut = _swap(address(this), pool, false, amount);
        _rebalance(user, wrapper);
        _swap(address(this), pool, true, amountOut);
    }

    function test() external {
        // address depositor = address(123);
        // ICLPool pool = ICLPool(
        //     factory.getPool(Constants.WETH, Constants.USDC, 200)
        // );
        // vm.prank(VELO_DEPLOY_FACTORY_OPERATOR);
        // IVeloDeployFactory.PoolAddresses memory addresses = createStrategy(
        //     pool
        // );
        // vm.startPrank(FARM_OPERATOR);
        // ILpWrapper(addresses.lpWrapper).emptyRebalance();
        // uint256 addedRewards = IERC20(Constants.VELO).balanceOf(
        //     addresses.synthetixFarm
        // );
        // StakingRewards(addresses.synthetixFarm).notifyRewardAmount(
        //     addedRewards
        // );
        // vm.stopPrank();
        // skip(7 days);
    }
}
