// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Constants.sol";

contract Fixture is Test {
    using SafeERC20 for IERC20;

    uint24 public constant FEE = 2500;

    INonfungiblePositionManager public positionManager =
        INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER);
    IAgniFactory public factory = IAgniFactory(Constants.AGNI_FACTORY);
    IAgniPool public pool =
        IAgniPool(factory.getPool(Constants.USDC, Constants.WETH, FEE));

    AgniAmmModule public ammModule;
    PulseStrategyModule public strategyModule;
    AgniOracle public oracle;
    AgniDepositWithdrawModule public dwModule;
    LpWrapper public lpWrapper;
    Core public core;
    address public farm;
    StakingRewards public stakingRewards;
    PulseAgniBot public bot;

    function mint(
        address token0,
        address token1,
        uint24 fee,
        int24 width,
        uint128 liquidity
    ) public returns (uint256) {
        vm.startPrank(Constants.OWNER);
        if (token0 > token1) (token0, token1) = (token1, token0);
        (uint160 sqrtRatioX96, int24 spotTick, , , , , ) = pool.slot0();
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
        mintParams.fee = fee;
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

    function movePrice() public {
        movePrice(1);
    }

    function movePrice(uint256 coefficient) public {
        vm.startPrank(Constants.OWNER);
        uint256 amountIn = 1e5 * 1e6 * coefficient;
        deal(Constants.USDC, Constants.OWNER, amountIn);
        IERC20(Constants.USDC).safeIncreaseAllowance(
            Constants.AGNI_SWAP_ROUTER,
            amountIn
        );
        ISwapRouter(Constants.AGNI_SWAP_ROUTER).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: Constants.USDC,
                tokenOut: Constants.WETH,
                fee: FEE,
                deadline: type(uint256).max,
                recipient: Constants.OWNER,
                sqrtPriceLimitX96: 0,
                amountOutMinimum: 0,
                amountIn: amountIn
            })
        );
        vm.stopPrank();
    }

    function removePosition(
        uint256 tokenId
    )
        public
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 liquidityAmount0,
            uint256 liquidityAmount1
        )
    {
        vm.startPrank(address(core));
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();

        (, , , , , , , uint128 liquidity, , , , ) = positionManager.positions(
            tokenId
        );
        (amount0, amount1) = PositionValue.total(
            positionManager,
            tokenId,
            sqrtRatioX96,
            pool
        );

        (liquidityAmount0, liquidityAmount1) = positionManager
            .decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: type(uint256).max
                })
            );

        positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                recipient: address(core),
                tokenId: tokenId,
                amount0Max: uint128(liquidityAmount0),
                amount1Max: uint128(liquidityAmount1)
            })
        );

        vm.stopPrank();
    }

    function addPosition(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1
    ) public {
        vm.startPrank(address(core));
        IERC20(pool.token0()).safeIncreaseAllowance(
            address(positionManager),
            amount0
        );
        IERC20(pool.token1()).safeIncreaseAllowance(
            address(positionManager),
            amount1
        );
        positionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint256).max
            })
        );
        vm.stopPrank();
    }

    function determineSwapAmounts(
        uint256 id
    ) public returns (PulseAgniBot.SwapParams memory) {
        vm.startPrank(Constants.OWNER);
        ICore.PositionInfo memory info = core.position(id);
        (bool flag, ICore.TargetPositionInfo memory target) = core
            .strategyModule()
            .getTargets(info, core.ammModule(), core.oracle());
        uint256 tokenId = info.tokenIds[0];
        if (tokenId == 0) revert("Invalid token id");
        if (!flag) revert("Rebalance is not necessary");
        vm.stopPrank();

        (
            uint256 amount0,
            uint256 amount1,
            uint256 liquidityAmount0,
            uint256 liquidityAmount1
        ) = removePosition(tokenId);

        PulseAgniBot.SwapParams memory swapParams = bot
            .calculateSwapAmountsPreciselySingle(
                IPulseAgniBot.SingleIntervalData({
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

        addPosition(tokenId, liquidityAmount0, liquidityAmount1);

        return swapParams;
    }

    function setUp() external {
        vm.startPrank(Constants.OWNER);
        {
            uint256 amountIn = 1e3 * 1e6;
            deal(Constants.USDC, Constants.OWNER, amountIn);
            IERC20(Constants.USDC).safeIncreaseAllowance(
                Constants.AGNI_SWAP_ROUTER,
                amountIn
            );
            ISwapRouter(Constants.AGNI_SWAP_ROUTER).exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: Constants.USDC,
                    tokenOut: Constants.WETH,
                    fee: FEE,
                    deadline: type(uint256).max,
                    recipient: Constants.OWNER,
                    sqrtPriceLimitX96: 0,
                    amountOutMinimum: 0,
                    amountIn: amountIn
                })
            );
        }

        ammModule = new AgniAmmModule(
            INonfungiblePositionManager(positionManager)
        );
        strategyModule = new PulseStrategyModule();
        oracle = new AgniOracle();
        core = new Core(
            ammModule,
            strategyModule,
            oracle,
            address(positionManager),
            Constants.OWNER
        );

        dwModule = new AgniDepositWithdrawModule(
            INonfungiblePositionManager(positionManager),
            ammModule
        );

        lpWrapper = new LpWrapper(
            core,
            dwModule,
            "lp wrapper",
            "LPWR",
            Constants.OWNER
        );
        stakingRewards = new StakingRewards(
            Constants.OWNER,
            Constants.OWNER,
            address(Constants.USDT), // random reward address
            address(lpWrapper)
        );

        bot = new PulseAgniBot(
            IQuoterV2(Constants.AGNI_QUOTER_V2),
            ISwapRouter(Constants.AGNI_SWAP_ROUTER),
            positionManager
        );

        vm.stopPrank();
    }
}
