// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

import "../../../src/libraries/external/velo/PositionValue.sol";

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
    address public constant CORE_OPERATOR =
        address(bytes20(keccak256("CORE_OPERATOR")));
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
    address public constant USER = address(bytes20(keccak256("USER")));

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
        SWAP_DUST,
        SWAP_LEFT_5,
        SWAP_LEFT_25,
        SWAP_LEFT_50,
        SWAP_LEFT_90,
        SWAP_RIGHT_5,
        SWAP_RIGHT_25,
        SWAP_RIGHT_50,
        SWAP_RIGHT_90,
        ADD_REWARDS,
        IDLE,
        KILL_GAUGE,
        REVIVE_GAUGE
    }

    function setUp() external {
        ammModule = new VeloAmmModule(positionManager);
        depositWithdrawModule = new VeloDepositWithdrawModule(positionManager);
        strategyModule = new PulseStrategyModule();
        oracle = new VeloOracle();
        core = new Core(
            ammModule,
            depositWithdrawModule,
            strategyModule,
            oracle,
            CORE_ADMIN,
            Constants.WETH
        );
        vm.startPrank(CORE_ADMIN);
        core.grantRole(core.ADMIN_DELEGATE_ROLE(), CORE_ADMIN);
        core.grantRole(core.OPERATOR(), CORE_OPERATOR);
        vm.stopPrank();

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
    ) public returns (uint256 tokenId) {
        vm.startPrank(owner);

        (uint160 sqrtPriceX96, int24 tick, , , , ) = pool.slot0();
        int24 tickLower = tick - width / 2;

        {
            int24 tickSpacing = pool.tickSpacing();
            int24 remainder = tickLower % tickSpacing;
            if (remainder < 0) remainder += tickSpacing;
            if (remainder > tickSpacing / 2) {
                tickLower += tickSpacing - remainder;
            } else {
                tickLower -= remainder;
            }
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
                deadline: block.timestamp,
                sqrtPriceX96: 0
            })
        );

        vm.stopPrank();
    }

    function createStrategy(
        ICLPool pool
    ) public returns (IVeloDeployFactory.PoolAddresses memory addresses) {
        pool.increaseObservationCardinalityNext(2);
        mint(pool, 1e19, pool.tickSpacing() * 1000, address(this));
        _swap(address(123), pool, false, 1 gwei);
        uint256 tokenId = mint(
            pool,
            100000,
            1000,
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

    function _logFees(ILpWrapper wrapper) private view {
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(
            wrapper.positionId()
        );
        (uint256 fee0, uint256 fee1) = PositionValue.fees(
            positionManager,
            info.ammPositionIds[0]
        );
        console2.log("Fees:", fee0, fee1);
    }

    function _execute(
        ILpWrapper wrapper,
        StakingRewards farm,
        ICLPool pool,
        Actions[] memory actions
    ) private {
        bool initialDeposit = true;
        for (uint256 i = 0; i < actions.length; i++) {
            Actions action = actions[i];
            if (action == Actions.DEPOSIT) {
                if (initialDeposit) {
                    _deposit(DEPOSITOR, wrapper, farm, 50000);
                    initialDeposit = false;
                } else {
                    _deposit(DEPOSITOR, wrapper, farm, 100);
                }
            } else if (action == Actions.WITHDRAW) {
                _withdraw(DEPOSITOR, 30, wrapper, farm);
            } else if (action == Actions.REBALANCE) {
                _rebalance(CORE_OPERATOR, wrapper);
            } else if (action == Actions.PUSH_REWARDS) {
                _pushRewards(FARM_OPERATOR, wrapper, farm);
            } else if (action == Actions.ADD_REWARDS) {
                _addRewards(pool, 1 ether);
            } else if (action == Actions.IDLE) {
                _idle(1 days);
            } else if (action == Actions.KILL_GAUGE) {
                _killGauge(pool);
            } else if (action == Actions.REVIVE_GAUGE) {
                _reviveGauge(pool);
            } else {
                uint256 amount0 = IERC20(pool.token0()).balanceOf(
                    address(pool)
                );
                uint256 amount1 = IERC20(pool.token1()).balanceOf(
                    address(pool)
                ) / 100;
                if (action == Actions.SWAP_DUST)
                    _swap(USER, pool, false, amount0 / 10000);
                else if (action == Actions.SWAP_LEFT_5)
                    _swap(USER, pool, false, amount0 / 20);
                else if (action == Actions.SWAP_LEFT_25)
                    _swap(USER, pool, false, amount0 / 4);
                else if (action == Actions.SWAP_LEFT_50)
                    _swap(USER, pool, false, amount0 / 2);
                else if (action == Actions.SWAP_LEFT_90)
                    _swap(USER, pool, false, (amount0 * 9) / 10);
                else if (action == Actions.SWAP_RIGHT_5)
                    _swap(USER, pool, true, amount1 / 20);
                else if (action == Actions.SWAP_RIGHT_25)
                    _swap(USER, pool, true, amount1 / 4);
                else if (action == Actions.SWAP_RIGHT_50)
                    _swap(USER, pool, true, amount1 / 2);
                else if (action == Actions.SWAP_RIGHT_90)
                    _swap(USER, pool, true, (amount1 * 9) / 10);
            }
        }
    }

    using stdStorage for StdStorage;

    function _killGauge(ICLPool pool) private {
        ICLGauge gauge = ICLGauge(pool.gauge());
        IVoter voter = IVoter(gauge.voter());
        stdstore
            .target({_target: address(voter)})
            .sig({_sig: voter.isAlive.selector})
            .with_key({who: address(gauge)})
            .checked_write({write: false});
    }

    function _reviveGauge(ICLPool pool) private {
        ICLGauge gauge = ICLGauge(pool.gauge());
        IVoter voter = IVoter(gauge.voter());
        stdstore
            .target({_target: address(voter)})
            .sig({_sig: voter.isAlive.selector})
            .with_key({who: address(gauge)})
            .checked_write({write: true});
    }

    function _deposit(
        address user,
        ILpWrapper wrapper,
        StakingRewards farm,
        uint256 ratioD2
    ) private {
        deal(address(positionManager), 1 ether);
        vm.startPrank(user);
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(
            wrapper.positionId()
        );
        (uint160 sqrtPriceX96, , , , , ) = ICLPool(info.pool).slot0();
        (uint256 amount0, uint256 amount1) = ammModule.tvl(
            info.ammPositionIds[0],
            sqrtPriceX96,
            info.callbackParams,
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
        (, , lpAmount) = wrapper.deposit(
            amount0,
            amount1,
            (lpAmount * 95) / 100,
            user,
            type(uint256).max
        );
        IERC20(address(wrapper)).approve(address(farm), lpAmount);
        farm.stake(lpAmount);
        vm.stopPrank();
    }

    function _withdraw(
        address user,
        uint256 d2,
        ILpWrapper wrapper,
        StakingRewards farm
    ) private {
        vm.startPrank(user);
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(
            wrapper.positionId()
        );
        (uint160 sqrtPriceX96, , , , , ) = ICLPool(info.pool).slot0();
        (uint256 amount0, uint256 amount1) = ammModule.tvl(
            info.ammPositionIds[0],
            sqrtPriceX96,
            info.callbackParams,
            new bytes(0)
        );
        uint256 totalSupply = IERC20(address(wrapper)).totalSupply();
        uint256 lpAmount = (totalSupply * d2) / 100;
        farm.withdraw(lpAmount);
        amount0 = (amount0 * lpAmount) / totalSupply;
        amount1 = (amount1 * lpAmount) / totalSupply;
        wrapper.withdraw(
            lpAmount,
            (amount0 * 95) / 100,
            (amount1 * 95) / 100,
            user,
            type(uint256).max
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

        ICore.ManagedPositionInfo memory info = core.managedPositionAt(
            wrapper.positionId()
        );
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
        ICore.RebalanceParams memory rebalanceParams;
        {
            ICore.ManagedPositionInfo memory info = core.managedPositionAt(
                wrapper.positionId()
            );
            ICore.TargetPositionInfo memory target;
            {
                bool flag;
                (flag, target) = core.strategyModule().getTargets(
                    info,
                    core.ammModule(),
                    core.oracle()
                );

                if (!flag) {
                    console2.log("Nothing to rebalance");
                    return;
                }
            }

            (uint160 sqrtPriceX96, , , , , ) = ICLPool(info.pool).slot0();

            ISwapRouter.ExactInputSingleParams[]
                memory params = new ISwapRouter.ExactInputSingleParams[](1);

            {
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

                ) = positionManager.positions(info.ammPositionIds[0]);
                (uint256 target0, uint256 target1) = LiquidityAmounts
                    .getAmountsForLiquidity(
                        sqrtPriceX96,
                        TickMath.getSqrtRatioAtTick(target.lowerTicks[0]),
                        TickMath.getSqrtRatioAtTick(target.upperTicks[0]),
                        uint128(2 ** 96)
                    );

                (uint256 current0, uint256 current1) = LiquidityAmounts
                    .getAmountsForLiquidity(
                        sqrtPriceX96,
                        TickMath.getSqrtRatioAtTick(tickLower),
                        TickMath.getSqrtRatioAtTick(tickUpper),
                        liquidity
                    );
                {
                    uint256 priceX96 = FullMath.mulDiv(
                        sqrtPriceX96,
                        sqrtPriceX96,
                        2 ** 96
                    );
                    uint256 targetCapital = FullMath.mulDiv(
                        target0,
                        priceX96,
                        2 ** 96
                    ) + target1;
                    uint256 currentCapital = FullMath.mulDiv(
                        current0,
                        priceX96,
                        2 ** 96
                    ) + current1;
                    target0 = FullMath.mulDiv(
                        target0,
                        currentCapital,
                        targetCapital
                    );
                    target1 = FullMath.mulDiv(
                        target1,
                        currentCapital,
                        targetCapital
                    );
                }

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
                    params = new ISwapRouter.ExactInputSingleParams[](0);
                }
            }
            rebalanceParams.ids = new uint256[](1);
            rebalanceParams.ids[0] = wrapper.positionId();
            rebalanceParams.callback = address(bot);
            rebalanceParams.data = abi.encode(params);
        }
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

    function build(
        int24 tickSpacing
    ) public returns (ILpWrapper wrapper, StakingRewards farm, ICLPool pool) {
        pool = ICLPool(
            factory.getPool(Constants.WETH, Constants.OP, tickSpacing)
        );
        IVeloDeployFactory.PoolAddresses memory addresses = createStrategy(
            pool
        );
        wrapper = ILpWrapper(addresses.lpWrapper);
        farm = StakingRewards(addresses.synthetixFarm);
    }

    function testKillRevive() external {
        (ILpWrapper wrapper, StakingRewards farm, ICLPool pool) = build(200);
        Actions[] memory actions = new Actions[](11);
        actions[0] = Actions.DEPOSIT;
        actions[1] = Actions.KILL_GAUGE;
        actions[2] = Actions.DEPOSIT;
        actions[3] = Actions.DEPOSIT;
        actions[4] = Actions.DEPOSIT;
        actions[5] = Actions.DEPOSIT;
        actions[6] = Actions.IDLE;
        actions[7] = Actions.WITHDRAW;
        actions[8] = Actions.WITHDRAW;
        actions[9] = Actions.WITHDRAW;
        actions[10] = Actions.IDLE;

        _execute(wrapper, farm, pool, actions);
    }

    function testKillRevive2() external {
        (ILpWrapper wrapper, StakingRewards farm, ICLPool pool) = build(200);
        Actions[] memory actions = new Actions[](22);
        actions[0] = Actions.DEPOSIT;
        actions[1] = Actions.KILL_GAUGE;
        actions[2] = Actions.DEPOSIT;
        actions[3] = Actions.DEPOSIT;
        actions[4] = Actions.DEPOSIT;
        actions[5] = Actions.DEPOSIT;
        actions[6] = Actions.IDLE;
        actions[7] = Actions.WITHDRAW;
        actions[8] = Actions.WITHDRAW;
        actions[9] = Actions.WITHDRAW;
        actions[10] = Actions.IDLE;

        actions[11] = Actions.DEPOSIT;
        actions[12] = Actions.REVIVE_GAUGE;
        actions[13] = Actions.DEPOSIT;
        actions[14] = Actions.DEPOSIT;
        actions[15] = Actions.DEPOSIT;
        actions[16] = Actions.DEPOSIT;
        actions[17] = Actions.IDLE;
        actions[18] = Actions.WITHDRAW;
        actions[19] = Actions.WITHDRAW;
        actions[20] = Actions.WITHDRAW;
        actions[21] = Actions.IDLE;

        _execute(wrapper, farm, pool, actions);
    }

    function testMultipleRebalances8() external {
        (ILpWrapper wrapper, StakingRewards farm, ICLPool pool) = build(200);
        Actions[] memory actions = new Actions[](48);
        actions[0] = Actions.DEPOSIT;
        actions[1] = Actions.SWAP_DUST;
        actions[2] = Actions.IDLE;
        actions[3] = Actions.DEPOSIT;
        actions[4] = Actions.REBALANCE;
        actions[5] = Actions.KILL_GAUGE;
        actions[6] = Actions.SWAP_LEFT_5;
        actions[7] = Actions.REBALANCE;
        actions[8] = Actions.SWAP_LEFT_25;
        actions[9] = Actions.IDLE;
        actions[10] = Actions.REBALANCE;
        actions[11] = Actions.DEPOSIT;
        actions[12] = Actions.SWAP_LEFT_50;
        actions[13] = Actions.IDLE;
        actions[14] = Actions.ADD_REWARDS;
        actions[15] = Actions.SWAP_RIGHT_50;
        actions[16] = Actions.IDLE;
        actions[17] = Actions.REVIVE_GAUGE;
        actions[18] = Actions.SWAP_RIGHT_50;
        actions[19] = Actions.IDLE;
        actions[20] = Actions.WITHDRAW;
        actions[21] = Actions.SWAP_RIGHT_50;
        actions[22] = Actions.IDLE;
        actions[23] = Actions.REBALANCE;
        actions[24] = Actions.DEPOSIT;
        actions[25] = Actions.SWAP_DUST;
        actions[26] = Actions.IDLE;
        actions[27] = Actions.DEPOSIT;
        actions[28] = Actions.REBALANCE;
        actions[29] = Actions.KILL_GAUGE;
        actions[30] = Actions.SWAP_LEFT_5;
        actions[31] = Actions.REBALANCE;
        actions[32] = Actions.SWAP_LEFT_25;
        actions[33] = Actions.IDLE;
        actions[34] = Actions.REBALANCE;
        actions[35] = Actions.DEPOSIT;
        actions[36] = Actions.SWAP_LEFT_50;
        actions[37] = Actions.IDLE;
        actions[38] = Actions.ADD_REWARDS;
        actions[39] = Actions.SWAP_RIGHT_50;
        actions[40] = Actions.IDLE;
        actions[41] = Actions.REVIVE_GAUGE;
        actions[42] = Actions.SWAP_RIGHT_50;
        actions[43] = Actions.IDLE;
        actions[44] = Actions.WITHDRAW;
        actions[45] = Actions.SWAP_RIGHT_50;
        actions[46] = Actions.IDLE;
        actions[47] = Actions.REBALANCE;
        _execute(wrapper, farm, pool, actions);
    }
}
