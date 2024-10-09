// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../unit/Constants.sol";

import {SwapRouter} from "../contracts/periphery/SwapRouter.sol";
import {QuoterV2} from "../contracts/periphery/lens/QuoterV2.sol";

contract Fixture is Test {
    using SafeERC20 for IERC20;

    int24 constant MAX_ALLOWED_DELTA = 100;
    uint32 constant MAX_AGE = 1 hours;
    uint128 INITIAL_LIQUIDITY = 1 ether;

    int24 public constant TICK_SPACING = 200;
    uint256 public constant Q96 = 2 ** 96;

    INonfungiblePositionManager public positionManager =
        INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER);
    ICLFactory public factory = ICLFactory(Constants.VELO_FACTORY);
    ICLPool public pool =
        ICLPool(factory.getPool(Constants.OP, Constants.WETH, TICK_SPACING));

    VeloAmmModule public ammModule;
    PulseStrategyModule public strategyModule;
    VeloOracle public oracle;
    VeloDepositWithdrawModule public dwModule;
    LpWrapper public lpWrapper;
    Core public core;
    VeloDeployFactoryHelper public helper;
    VeloDeployFactory public veloFactory;
    address public farm;
    StakingRewards public stakingRewards;
    PulseVeloBot public bot;

    ISwapRouter public swapRouter =
        ISwapRouter(
            address(new SwapRouter(positionManager.factory(), Constants.WETH))
        );

    IQuoterV2 public quoterV2 =
        IQuoterV2(
            address(new QuoterV2(positionManager.factory(), Constants.WETH))
        );

    function mint(
        address token0,
        address token1,
        int24 tickSpacing,
        int24 width,
        uint128 liquidity
    ) public returns (uint256) {
        vm.startPrank(Constants.OWNER);
        if (token0 > token1) (token0, token1) = (token1, token0);
        (uint160 sqrtRatioX96, int24 spotTick, , , , ) = pool.slot0();
        {
            int24 remainder = spotTick % pool.tickSpacing();
            if (remainder < 0) remainder += pool.tickSpacing();
            spotTick -= remainder;
        }
        INonfungiblePositionManager.MintParams memory mintParams;
        mintParams.tickLower = spotTick - width / 2;
        mintParams.tickUpper = mintParams.tickLower + width;
        mintParams.recipient = Constants.OWNER;
        mintParams.deadline = type(uint256).max;
        mintParams.token0 = token0;
        mintParams.token1 = token1;
        mintParams.tickSpacing = tickSpacing;
        {
            uint160 sqrtLowerRatioX96 = TickMath.getSqrtRatioAtTick(
                mintParams.tickLower
            );
            uint160 sqrtUpperRatioX96 = TickMath.getSqrtRatioAtTick(
                mintParams.tickUpper
            );
            (
                mintParams.amount0Desired,
                mintParams.amount1Desired
            ) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                sqrtLowerRatioX96,
                sqrtUpperRatioX96,
                liquidity
            );
        }
        deal(token0, Constants.OWNER, mintParams.amount0Desired);
        deal(token1, Constants.OWNER, mintParams.amount1Desired);
        IERC20(token0).safeIncreaseAllowance(
            address(positionManager),
            mintParams.amount0Desired
        );
        IERC20(token1).safeIncreaseAllowance(
            address(positionManager),
            mintParams.amount1Desired
        );
        (uint256 tokenId, uint128 actualLiquidity, , ) = positionManager.mint(
            mintParams
        );
        require((liquidity * 99) / 100 <= actualLiquidity && tokenId > 0);
        vm.stopPrank();
        return tokenId;
    }

    function movePrice(int24 targetTick) public {
        int24 spotTick;
        (, spotTick, , , , ) = pool.slot0();
        uint256 usdcAmount = IERC20(Constants.OP).balanceOf(address(pool));
        uint256 wethAmount = IERC20(Constants.WETH).balanceOf(address(pool));
        if (spotTick < targetTick) {
            while (spotTick < targetTick) {
                _swapAmount(usdcAmount, 1);
                (, spotTick, , , , ) = pool.slot0();
            }
        } else {
            while (spotTick > targetTick) {
                _swapAmount(wethAmount, 0);
                (, spotTick, , , , ) = pool.slot0();
            }
        }

        while (spotTick != targetTick) {
            if (spotTick < targetTick) {
                while (spotTick < targetTick) {
                    _swapAmount(usdcAmount, 1);
                    (, spotTick, , , , ) = pool.slot0();
                }
                usdcAmount >>= 1;
            } else {
                while (spotTick > targetTick) {
                    _swapAmount(wethAmount, 0);
                    (, spotTick, , , , ) = pool.slot0();
                }
                wethAmount >>= 1;
            }
        }
    }

    function movePrice() public {
        movePrice(uint256(1));
    }

    function movePrice(uint256 coefficient) public {
        vm.startPrank(Constants.OWNER);
        uint256 amountIn = 1e6 * 1e6 * coefficient;
        deal(Constants.OP, Constants.OWNER, amountIn);
        IERC20(Constants.OP).safeIncreaseAllowance(
            address(swapRouter),
            amountIn
        );
        swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: Constants.OP,
                tokenOut: Constants.WETH,
                tickSpacing: TICK_SPACING,
                deadline: type(uint256).max,
                recipient: Constants.OWNER,
                sqrtPriceLimitX96: 0,
                amountOutMinimum: 0,
                amountIn: amountIn
            })
        );
        vm.stopPrank();
    }

    function _swapAmount(uint256 amountIn, uint256 tokenInIndex) private {
        if (amountIn == 0) revert("Insufficient amount for swap");
        address[] memory tokens = new address[](2);
        tokens[0] = Constants.WETH;
        tokens[1] = Constants.OP;
        address tokenIn = tokens[tokenInIndex];
        address tokenOut = tokens[tokenInIndex ^ 1];
        deal(tokenIn, Constants.DEPLOYER, amountIn);
        IERC20(tokenIn).safeIncreaseAllowance(address(swapRouter), amountIn);
        ISwapRouter(swapRouter).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                tickSpacing: TICK_SPACING,
                recipient: Constants.DEPLOYER,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0,
                deadline: type(uint256).max
            })
        );
        skip(24 * 3600);
    }

    function addLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public {
        (uint160 sqrtRatioX96, , , , , ) = pool.slot0();
        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );
        amount0 *= 2;
        amount1 *= 2;
        deal(Constants.WETH, address(Constants.DEPLOYER), amount0);
        deal(Constants.OP, address(Constants.DEPLOYER), amount1);
        IERC20(Constants.WETH).safeIncreaseAllowance(
            address(positionManager),
            amount0
        );
        IERC20(Constants.OP).safeIncreaseAllowance(
            address(positionManager),
            amount1
        );
        positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: Constants.WETH,
                token1: Constants.OP,
                tickSpacing: TICK_SPACING,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: type(uint256).max,
                sqrtPriceX96: 0
            })
        );
    }

    function normalizePool() public {
        pool.increaseObservationCardinalityNext(2);
        {
            int24 lowerTick = -800000;
            int24 upperTick = 800000;
            addLiquidity(lowerTick, upperTick, 2500 ether);
        }

        (, int24 targetTick, , , , , ) = IUniswapV3Pool(
            0x85149247691df622eaF1a8Bd0CaFd40BC45154a9
        ).slot0();

        _swapAmount(2621439999999999988840005632, 0);
        movePrice(targetTick);

        targetTick -= targetTick % TICK_SPACING;

        {
            (uint160 sqrtRatioX96, , , , , ) = pool.slot0();
            uint256 priceX96 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, Q96);
            uint256 usdcAmount = 5e12;
            uint256 wethAmount = FullMath.mulDiv(usdcAmount, Q96, priceX96);

            for (int24 i = 1; i <= 20; i++) {
                int24 lowerTick = targetTick - i * TICK_SPACING;
                int24 upperTick = targetTick + i * TICK_SPACING;
                uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
                    sqrtRatioX96,
                    TickMath.getSqrtRatioAtTick(lowerTick),
                    TickMath.getSqrtRatioAtTick(upperTick),
                    wethAmount,
                    usdcAmount
                );
                addLiquidity(lowerTick, upperTick, liquidity);
            }
        }

        skip(3 * 24 * 3600);
    }

    function determineSwapAmounts(
        uint256 id
    ) public returns (PulseVeloBot.SwapParams memory) {
        vm.startPrank(Constants.OWNER);
        ICore.ManagedPositionInfo memory info = core.managedPositionAt(id);
        (bool flag, ICore.TargetPositionInfo memory target) = core
            .strategyModule()
            .getTargets(info, core.ammModule(), core.oracle());
        uint256 tokenId = info.ammPositionIds[0];
        if (tokenId == 0) revert("Invalid token id");
        if (!flag) revert("Rebalance is not necessary");
        vm.stopPrank();

        (uint160 sqrtPriceX96, , , , , ) = pool.slot0();
        (uint256 amount0, uint256 amount1) = ammModule.tvl(
            tokenId,
            sqrtPriceX96,
            info.callbackParams,
            new bytes(0)
        );

        PulseVeloBot.SwapParams memory swapParams = bot
            .calculateSwapAmountsPreciselySingle(
                IPulseVeloBot.SingleIntervalData({
                    amount0: amount0,
                    amount1: amount1,
                    sqrtLowerRatioX96: TickMath.getSqrtRatioAtTick(
                        target.lowerTicks[0]
                    ),
                    sqrtUpperRatioX96: TickMath.getSqrtRatioAtTick(
                        target.upperTicks[0]
                    ),
                    pool: pool
                })
            );

        return swapParams;
    }

    function setUp() external {
        vm.startPrank(Constants.DEPLOYER);
        normalizePool();
        vm.stopPrank();
        vm.startPrank(Constants.OWNER);
        {
            uint256 amountIn = 1e3 * 1e6;
            deal(Constants.OP, Constants.OWNER, amountIn);
            IERC20(Constants.OP).safeIncreaseAllowance(
                address(swapRouter),
                amountIn
            );
            swapRouter.exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: Constants.OP,
                    tokenOut: Constants.WETH,
                    tickSpacing: TICK_SPACING,
                    deadline: type(uint256).max,
                    recipient: Constants.OWNER,
                    sqrtPriceLimitX96: 0,
                    amountOutMinimum: 0,
                    amountIn: amountIn
                })
            );
        }

        ammModule = new VeloAmmModule(
            INonfungiblePositionManager(positionManager),
            Constants.SELECTOR_IS_POOL
        );
        strategyModule = new PulseStrategyModule();
        oracle = new VeloOracle();
        core = new Core(ammModule, strategyModule, oracle, Constants.OWNER);
        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    feeD9: 1e8,
                    treasury: Constants.PROTOCOL_TREASURY
                })
            )
        );

        dwModule = new VeloDepositWithdrawModule(
            INonfungiblePositionManager(positionManager)
        );

        helper = new VeloDeployFactoryHelper(Constants.WETH);
        veloFactory = new VeloDeployFactory(
            Constants.OWNER,
            core,
            dwModule,
            helper
        );

        _createStrategy();

        stakingRewards = new StakingRewards(
            Constants.OWNER,
            Constants.OWNER,
            address(Constants.VELO),
            address(lpWrapper)
        );

        bot = new PulseVeloBot(quoterV2, swapRouter, positionManager);

        vm.stopPrank();
    }

    function _createStrategy() private {
        pool.increaseObservationCardinalityNext(2);

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 20,
            INITIAL_LIQUIDITY
        );

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

        IVeloDeployFactory.PoolAddresses memory addresses = veloFactory
            .createStrategy(
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

        lpWrapper = LpWrapper(payable(addresses.lpWrapper));
        farm = addresses.synthetixFarm;

        vm.stopPrank();
    }
}
