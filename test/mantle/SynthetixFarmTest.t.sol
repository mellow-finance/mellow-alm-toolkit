// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Constants.sol";

contract Integration is Test {
    using SafeERC20 for IERC20;
    using Constants for Integration;

    uint24 public constant FEE = 2500;

    INonfungiblePositionManager public positionManager =
        INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER);

    IAgniFactory public factory = IAgniFactory(Constants.AGNI_FACTORY);
    address public owner = address(Constants.DEPLOYER);

    function mint(
        address token0,
        address token1,
        uint24 fee,
        int24 width,
        uint128 liquidity
    ) public returns (uint256) {
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
        mintParams.recipient = owner;
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
        deal(token0, owner, mintParams.amount0Desired);
        deal(token1, owner, mintParams.amount1Desired);
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
        return tokenId;
    }

    function movePrice(bool flag) public {
        if (flag) {
            uint256 amountIn = 1e6 * 1e6;
            deal(Constants.USDC, owner, amountIn);
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
                    recipient: owner,
                    sqrtPriceLimitX96: 0,
                    amountOutMinimum: 0,
                    amountIn: amountIn
                })
            );
        } else {
            uint256 amountIn = 500 ether;
            deal(Constants.WETH, owner, amountIn);
            IERC20(Constants.WETH).safeIncreaseAllowance(
                Constants.AGNI_SWAP_ROUTER,
                amountIn
            );
            ISwapRouter(Constants.AGNI_SWAP_ROUTER).exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: Constants.WETH,
                    tokenOut: Constants.USDC,
                    fee: FEE,
                    deadline: type(uint256).max,
                    recipient: owner,
                    sqrtPriceLimitX96: 0,
                    amountOutMinimum: 0,
                    amountIn: amountIn
                })
            );
        }
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
        (uint160 sqrtRatioX96, , , , , , ) = pool.slot0();
        vm.stopPrank();
        vm.startPrank(address(core));
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
        vm.startPrank(owner);
    }

    function addPosition(
        uint256 tokenId,
        uint256 liquidityAmount0,
        uint256 liquidityAmount1
    ) public {
        vm.stopPrank();
        vm.startPrank(address(core));

        IERC20(pool.token0()).safeIncreaseAllowance(
            address(positionManager),
            liquidityAmount0
        );
        IERC20(pool.token1()).safeIncreaseAllowance(
            address(positionManager),
            liquidityAmount1
        );
        positionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: liquidityAmount0,
                amount1Desired: liquidityAmount1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint256).max
            })
        );
        vm.stopPrank();

        vm.startPrank(owner);
    }

    function determineSwapAmounts(
        PulseAgniBot bot,
        uint256 id
    ) public returns (PulseAgniBot.SwapParams memory) {
        ICore.NftsInfo memory info = core.nfts(id);
        (bool flag, ICore.TargetNftsInfo memory target) = core
            .strategyModule()
            .getTargets(info, core.ammModule(), core.oracle());
        uint256 tokenId = info.tokenIds[0];
        if (tokenId == 0) revert("Invalid token id");
        if (!flag) revert("Rebalance is not necessary");
        (
            uint256 amount0,
            uint256 amount1,
            uint256 liquidityAmount0,
            uint256 liquidityAmount1
        ) = removePosition(tokenId);

        PulseAgniBot.SwapParams memory swapParams = bot
            .calculateSwapAmountsPreciselySingle(
                PulseAgniBot.SingleIntervalData({
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

    struct Data {
        uint256[] liq0;
        uint256[] liq1;
        uint256 amount0;
        uint256 amount1;
        uint160[] sqrtLowerRatiosX96;
        uint160[] sqrtUpperRatiosX96;
        uint256[] ratiosX96;
        uint256 priceX96;
        uint256 cumulative;
    }

    function determineSwapAmountsMultiple(
        PulseAgniBot bot,
        uint256[] memory ids
    ) public returns (PulseAgniBot.SwapParams memory) {
        Data memory data;

        data.liq0 = new uint256[](ids.length);
        data.liq1 = new uint256[](ids.length);

        data.sqrtLowerRatiosX96 = new uint160[](ids.length);
        data.sqrtUpperRatiosX96 = new uint160[](ids.length);
        data.ratiosX96 = new uint256[](ids.length);
        {
            (uint160 sqrtPriceX96, , , , , , ) = IAgniPool(
                core.nfts(ids[0]).pool
            ).slot0();
            data.priceX96 = FullMath.mulDiv(
                sqrtPriceX96,
                sqrtPriceX96,
                2 ** 96
            );
        }
        data.cumulative = 0;
        for (uint256 i = 0; i < ids.length; i++) {
            ICore.NftsInfo memory info = core.nfts(ids[i]);
            (bool flag, ICore.TargetNftsInfo memory target) = core
                .strategyModule()
                .getTargets(info, core.ammModule(), core.oracle());

            uint256 tokenId = info.tokenIds[0];
            if (tokenId == 0) revert("Invalid token id");
            if (!flag) revert("Rebalance is not necessary");
            uint256 amount0_;
            uint256 amount1_;
            (amount0_, amount1_, data.liq0[i], data.liq1[i]) = removePosition(
                tokenId
            );
            data.amount0 += amount0_;
            data.amount1 += amount1_;
            data.sqrtLowerRatiosX96[i] = TickMath.getSqrtRatioAtTick(
                target.lowerTicks[0]
            );
            data.sqrtUpperRatiosX96[i] = TickMath.getSqrtRatioAtTick(
                target.upperTicks[0]
            );
            data.ratiosX96[i] =
                FullMath.mulDiv(amount0_, data.priceX96, 2 ** 96) +
                amount1_;
            data.cumulative += data.ratiosX96[i];
        }

        for (uint256 i = 0; i < data.ratiosX96.length; i++) {
            data.ratiosX96[i] = FullMath.mulDiv(
                data.ratiosX96[i],
                2 ** 96,
                data.cumulative
            );
            console2.log("Ratios 0:", (data.ratiosX96[i] * 100) / 2 ** 96);
        }

        data.cumulative = 2 ** 96;
        for (uint256 i = 0; i < data.ratiosX96.length; i++) {
            if (data.ratiosX96[i] > data.cumulative) {
                data.ratiosX96[i] = data.cumulative;
            }
            data.cumulative -= data.ratiosX96[i];
            if (i + 1 == data.ratiosX96.length) {
                data.ratiosX96[i] += data.cumulative;
            }
        }

        for (uint256 i = 0; i < data.ratiosX96.length; i++) {
            console2.log("Ratios:", (data.ratiosX96[i] * 100) / 2 ** 96);
        }

        PulseAgniBot.SwapParams memory swapParams = bot
            .calculateSwapAmountsPreciselyMultiple(
                PulseAgniBot.MultipleIntervalsData({
                    amount0: data.amount0,
                    amount1: data.amount1,
                    ratiosX96: data.ratiosX96,
                    sqrtLowerRatiosX96: data.sqrtLowerRatiosX96,
                    sqrtUpperRatiosX96: data.sqrtUpperRatiosX96,
                    pool: IAgniPool(core.nfts(ids[0]).pool)
                })
            );

        for (uint256 i = 0; i < ids.length; i++) {
            ICore.NftsInfo memory nftInfo = core.nfts(ids[i]);
            addPosition(nftInfo.tokenIds[0], data.liq0[i], data.liq1[i]);
        }
        return swapParams;
    }

    AgniAmmModule public ammModule;
    PulseStrategyModule public strategyModule;
    AgniOracle public oracle;
    AgniDepositWithdrawModule public dwModule;
    LpWrapper public lpWrapper;

    address public depositor = address(bytes20(keccak256("depositor")));
    IAgniPool public pool =
        IAgniPool(factory.getPool(Constants.USDC, Constants.WETH, FEE));

    Core public core;

    address public farm;
    StakingRewards public stakingRewards;

    function test() external {
        vm.startPrank(owner);
        {
            pool.increaseObservationCardinalityNext(10);
            {
                (
                    ,
                    ,
                    ,
                    uint16 observationCardinality,
                    uint16 observationCardinalityNext,
                    ,

                ) = pool.slot0();
                console2.log(
                    observationCardinality,
                    observationCardinalityNext
                );
            }
            uint256 amountIn = 1e3 * 1e6;
            deal(Constants.USDC, owner, amountIn);
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
                    recipient: owner,
                    sqrtPriceLimitX96: 0,
                    amountOutMinimum: 0,
                    amountIn: amountIn
                })
            );

            {
                (
                    ,
                    ,
                    ,
                    uint16 observationCardinality,
                    uint16 observationCardinalityNext,
                    ,

                ) = pool.slot0();
                console2.log(
                    observationCardinality,
                    observationCardinalityNext
                );
            }
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
            owner
        );

        dwModule = new AgniDepositWithdrawModule(
            INonfungiblePositionManager(positionManager),
            ammModule
        );

        lpWrapper = new LpWrapper(core, dwModule, "lp wrapper", "LPWR");

        ICore.DepositParams memory depositParams;

        depositParams.tokenIds = new uint256[](1);
        depositParams.tokenIds[0] = mint(
            Constants.USDC,
            Constants.WETH,
            FEE,
            pool.tickSpacing() * 8,
            1e9
        );
        depositParams.owner = owner;
        depositParams.farm = address(0);

        depositParams.strategyParams = abi.encode(
            PulseStrategyModule.StrategyParams({
                tickNeighborhood: pool.tickSpacing() * 2,
                tickSpacing: pool.tickSpacing()
            })
        );
        depositParams.securityParams = new bytes(0);

        depositParams.slippageD4 = 100;
        positionManager.approve(address(core), depositParams.tokenIds[0]);
        {
            uint256 nftId = core.deposit(depositParams);
            core.withdraw(nftId, owner);
        }
        positionManager.approve(address(core), depositParams.tokenIds[0]);
        stakingRewards = new StakingRewards(
            owner,
            owner,
            address(lpWrapper), // replace with AGNI address
            address(lpWrapper)
        );

        depositParams.owner = address(lpWrapper);
        depositParams.vault = address(stakingRewards);

        uint256 nftId2 = core.deposit(depositParams);

        lpWrapper.initialize(nftId2, 5e5);

        PulseAgniBot bot = new PulseAgniBot(
            IQuoterV2(Constants.AGNI_QUOTER_V2),
            ISwapRouter(Constants.AGNI_SWAP_ROUTER),
            positionManager
        );

        deal(Constants.USDC, depositor, 1e6 * 1e6);
        deal(Constants.WETH, depositor, 500 ether);

        vm.stopPrank();
        vm.startPrank(depositor);

        IERC20(Constants.USDC).safeApprove(
            address(lpWrapper),
            type(uint256).max
        );
        IERC20(Constants.WETH).safeApprove(
            address(lpWrapper),
            type(uint256).max
        );
        {
            (, , uint256 lpAmount) = lpWrapper.deposit(
                1e6,
                500 ether,
                1e3,
                depositor
            );
            require(lpAmount > 0, "Invalid lp amount");
            console2.log("Actual lp amount:", lpAmount);
            lpWrapper.approve(address(stakingRewards), type(uint256).max);
            stakingRewards.stake(lpWrapper.balanceOf(depositor), depositor);
        }
        vm.stopPrank();
        vm.startPrank(owner);

        for (uint256 i = 0; i < 2; i++) {
            {
                vm.stopPrank();
                vm.startPrank(depositor);
                stakingRewards.withdraw(
                    stakingRewards.balanceOf(depositor) / 2
                );
                (
                    uint256 amount0,
                    uint256 amount1,
                    uint256 actualAmountLp
                ) = lpWrapper.withdraw(1e6, 0, 0, depositor);

                console2.log(
                    "Actual withdrawal amounts for depositor:",
                    amount0,
                    amount1,
                    actualAmountLp
                );

                vm.stopPrank();
                vm.startPrank(owner);
            }

            ICore.TargetNftsInfo memory target;
            while (true) {
                movePrice(true);
                uint256[] memory ids = new uint256[](1);
                ids[0] = lpWrapper.tokenId();
                bool flag;
                (flag, target) = core.strategyModule().getTargets(
                    core.nfts(lpWrapper.tokenId()),
                    core.ammModule(),
                    core.oracle()
                );
                skip(5 * 60);
                if (flag) break;
            }

            PulseAgniBot.SwapParams memory swapParams = determineSwapAmounts(
                bot,
                lpWrapper.tokenId()
            );
            ICore.RebalanceParams memory rebalanceParams;

            rebalanceParams.ids = new uint256[](1);
            rebalanceParams.ids[0] = lpWrapper.tokenId();
            rebalanceParams.callback = address(bot);
            ISwapRouter.ExactInputSingleParams[]
                memory ammParams = new ISwapRouter.ExactInputSingleParams[](1);
            ammParams[0] = ISwapRouter.ExactInputSingleParams({
                tokenIn: swapParams.tokenIn,
                tokenOut: swapParams.tokenOut,
                fee: swapParams.fee,
                amountIn: swapParams.amountIn,
                amountOutMinimum: (swapParams.expectedAmountOut * 9999) / 10000,
                deadline: type(uint256).max,
                recipient: address(bot),
                sqrtPriceLimitX96: 0
            });
            rebalanceParams.data = abi.encode(ammParams);

            core.rebalance(rebalanceParams);
            {
                ICore.NftsInfo memory info = core.nfts(lpWrapper.tokenId());
                uint160 sqrtPriceX96;
                (sqrtPriceX96, , , , , , ) = pool.slot0();

                (uint256 amount0, uint256 amount1) = PositionValue.total(
                    positionManager,
                    info.tokenIds[0],
                    sqrtPriceX96,
                    IAgniPool(info.pool)
                );
                uint256 priceX96 = FullMath.mulDiv(
                    sqrtPriceX96,
                    sqrtPriceX96,
                    2 ** 96
                );
                uint256 capital = FullMath.mulDiv(amount0, priceX96, 2 ** 96) +
                    amount1;
                console2.log("Capital usdc:", capital);
                console2.log(
                    "New position params:",
                    vm.toString(info.tokenIds[0])
                );
            }
        }

        vm.stopPrank();
    }
}
