// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../src/UniIntent.sol";
import "../../src/bots/UniIntentBot.sol";

import "../../src/libraries/external/PositionValue.sol";

contract UniIntentTest is Test {
    using SafeERC20 for IERC20;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    INonfungiblePositionManager public positionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    IUniswapV3Factory public factory =
        IUniswapV3Factory(positionManager.factory());
    address public swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public quoter = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;

    address public owner = address(1234123);

    function mint(
        address token0,
        address token1,
        uint24 fee,
        int24 width,
        uint128 liquidity
    ) public returns (uint256) {
        if (token0 > token1) (token0, token1) = (token1, token0);
        IUniswapV3Pool pool = IUniswapV3Pool(
            factory.getPool(token0, token1, fee)
        );
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
            deal(USDC, owner, amountIn);
            IERC20(USDC).safeIncreaseAllowance(swapRouter, amountIn);
            ISwapRouter(swapRouter).exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: USDC,
                    tokenOut: WETH,
                    fee: 500,
                    deadline: type(uint256).max,
                    recipient: owner,
                    sqrtPriceLimitX96: 0,
                    amountOutMinimum: 0,
                    amountIn: amountIn
                })
            );
        } else {
            uint256 amountIn = 500 ether;
            deal(WETH, owner, amountIn);
            IERC20(WETH).safeIncreaseAllowance(swapRouter, amountIn);
            ISwapRouter(swapRouter).exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: WETH,
                    tokenOut: USDC,
                    fee: 500,
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
        UniIntent intent,
        uint256 tokenId,
        IUniswapV3Pool pool
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
        vm.startPrank(address(intent));
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
                recipient: address(intent),
                tokenId: tokenId,
                amount0Max: uint128(liquidityAmount0),
                amount1Max: uint128(liquidityAmount1)
            })
        );

        vm.stopPrank();
        vm.startPrank(owner);
    }

    function addPosition(
        UniIntent intent,
        uint256 tokenId,
        IUniswapV3Pool pool,
        uint256 liquidityAmount0,
        uint256 liquidityAmount1
    ) public {
        vm.stopPrank();
        vm.startPrank(address(intent));

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
        UniIntent intent,
        UniIntentBot bot,
        uint256 id
    ) public returns (UniIntentBot.SwapParams memory) {
        IUniIntent.NftInfo memory nftInfo = intent.nfts(id);
        IUniswapV3Pool pool = IUniswapV3Pool(nftInfo.pool);
        (, int24 tick, , , , , ) = pool.slot0();
        (bool flag, IUniIntent.TargetNftInfo memory target) = intent.getTarget(
            nftInfo,
            tick
        );
        uint256 tokenId = nftInfo.tokenId;
        if (tokenId == 0) revert("Invalid token id");
        if (!flag) revert("Rebalance is not necessary");
        (
            uint256 amount0,
            uint256 amount1,
            uint256 liquidityAmount0,
            uint256 liquidityAmount1
        ) = removePosition(intent, tokenId, pool);

        UniIntentBot.SwapParams memory swapParams = bot
            .calculateSwapAmountsPreciselySingle(
                UniIntentBot.SingleIntervalData({
                    amount0: amount0,
                    amount1: amount1,
                    sqrtLowerRatioX96: TickMath.getSqrtRatioAtTick(
                        target.tickLower
                    ),
                    sqrtUpperRatioX96: TickMath.getSqrtRatioAtTick(
                        target.tickUpper
                    ),
                    pool: pool
                })
            );

        addPosition(intent, tokenId, pool, liquidityAmount0, liquidityAmount1);

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
        UniIntent intent,
        UniIntentBot bot,
        uint256[] memory ids
    ) public returns (UniIntentBot.SwapParams memory) {
        Data memory data;

        data.liq0 = new uint256[](ids.length);
        data.liq1 = new uint256[](ids.length);

        data.sqrtLowerRatiosX96 = new uint160[](ids.length);
        data.sqrtUpperRatiosX96 = new uint160[](ids.length);
        data.ratiosX96 = new uint256[](ids.length);
        {
            (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(
                intent.nfts(ids[0]).pool
            ).slot0();
            data.priceX96 = FullMath.mulDiv(
                sqrtPriceX96,
                sqrtPriceX96,
                2 ** 96
            );
        }
        data.cumulative = 0;
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 amount0_;
            uint256 amount1_;
            uint256 id = ids[i];
            IUniIntent.NftInfo memory nftInfo = intent.nfts(id);
            IUniswapV3Pool pool = IUniswapV3Pool(nftInfo.pool);
            (, int24 tick, , , , , ) = pool.slot0();
            (bool flag, IUniIntent.TargetNftInfo memory target) = intent
                .getTarget(nftInfo, tick);
            uint256 tokenId = nftInfo.tokenId;
            if (tokenId == 0) revert("Invalid token id");
            if (!flag) revert("Rebalance is not necessary");
            (amount0_, amount1_, data.liq0[i], data.liq1[i]) = removePosition(
                intent,
                tokenId,
                pool
            );
            data.amount0 += amount0_;
            data.amount1 += amount1_;
            data.sqrtLowerRatiosX96[i] = TickMath.getSqrtRatioAtTick(
                target.tickLower
            );
            data.sqrtUpperRatiosX96[i] = TickMath.getSqrtRatioAtTick(
                target.tickUpper
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

        UniIntentBot.SwapParams memory swapParams = bot
            .calculateSwapAmountsPreciselyMultiple(
                UniIntentBot.MultipleIntervalsData({
                    amount0: data.amount0,
                    amount1: data.amount1,
                    ratiosX96: data.ratiosX96,
                    sqrtLowerRatiosX96: data.sqrtLowerRatiosX96,
                    sqrtUpperRatiosX96: data.sqrtUpperRatiosX96,
                    pool: IUniswapV3Pool(intent.nfts(ids[0]).pool)
                })
            );

        for (uint256 i = 0; i < ids.length; i++) {
            IUniIntent.NftInfo memory nftInfo = intent.nfts(ids[i]);
            addPosition(
                intent,
                nftInfo.tokenId,
                IUniswapV3Pool(nftInfo.pool),
                data.liq0[i],
                data.liq1[i]
            );
        }
        return swapParams;
    }

    function testLarge() external {
        vm.startPrank(owner);
        UniIntent intent = new UniIntent(positionManager, factory, owner);

        IUniIntent.DepositParams memory depositParams;
        uint32[] memory timespans = new uint32[](2);
        timespans[0] = 20;
        timespans[1] = 30;
        depositParams.tokenId = mint(USDC, WETH, 500, 120, 1e19);
        depositParams.owner = owner;
        depositParams.tickNeighborhood = 10;
        depositParams.slippageD4 = 50;
        depositParams.maxDeviation = 30;
        depositParams.minLiquidityGross = 0;
        depositParams.timespans = timespans;
        positionManager.approve(address(intent), depositParams.tokenId);
        uint256 nftId = intent.deposit(depositParams);
        intent.withdraw(nftId, owner);
        positionManager.approve(address(intent), depositParams.tokenId);
        uint256 nftId2 = intent.deposit(depositParams);
        IUniswapV3Pool pool = IUniswapV3Pool(factory.getPool(USDC, WETH, 500));

        UniIntentBot bot = new UniIntentBot(
            IQuoterV2(quoter),
            ISwapRouter(swapRouter),
            positionManager
        );

        for (uint256 i = 0; i < 10; i++) {
            IUniIntent.TargetNftInfo memory target;
            while (true) {
                movePrice(true);
                uint256[] memory ids = new uint256[](1);
                ids[0] = nftId2;
                (, int24 tick, , , , , ) = pool.slot0();
                bool flag;
                (flag, target) = intent.getTarget(intent.nfts(nftId2), tick);
                skip(5 * 60);
                if (flag) break;
            }

            UniIntentBot.SwapParams memory swapParams = determineSwapAmounts(
                intent,
                bot,
                nftId2
            );
            IUniIntent.RebalanceParams memory rebalanceParams;

            rebalanceParams.ids = new uint256[](1);
            rebalanceParams.ids[0] = nftId2;
            rebalanceParams.offchainTicks = new int24[](2);
            (, rebalanceParams.offchainTicks[0], , , , , ) = pool.slot0();
            (, rebalanceParams.offchainTicks[1], , , , , ) = pool.slot0();
            rebalanceParams.callback = address(bot);
            ISwapRouter.ExactInputSingleParams[]
                memory uniswapParams = new ISwapRouter.ExactInputSingleParams[](
                    1
                );
            uniswapParams[0] = ISwapRouter.ExactInputSingleParams({
                tokenIn: swapParams.tokenIn,
                tokenOut: swapParams.tokenOut,
                fee: swapParams.fee,
                amountIn: swapParams.amountIn,
                amountOutMinimum: (swapParams.expectedAmountOut * 9999) / 10000,
                deadline: type(uint256).max,
                recipient: address(bot),
                sqrtPriceLimitX96: 0
            });
            rebalanceParams.data = abi.encode(uniswapParams);

            intent.rebalance(rebalanceParams);
            {
                IUniIntent.NftInfo memory info = intent.nfts(nftId2);
                console2.log(
                    "Spot tick before rebalance:",
                    vm.toString(rebalanceParams.offchainTicks[0])
                );
                uint160 sqrtPriceX96;
                (
                    sqrtPriceX96,
                    rebalanceParams.offchainTicks[0],
                    ,
                    ,
                    ,
                    ,

                ) = pool.slot0();
                console2.log(
                    "Spot tick after rebalance:",
                    vm.toString(rebalanceParams.offchainTicks[0])
                );
                (uint256 amount0, uint256 amount1) = PositionValue.total(
                    positionManager,
                    info.tokenId,
                    sqrtPriceX96,
                    IUniswapV3Pool(info.pool)
                );
                uint256 priceX96 = FullMath.mulDiv(
                    sqrtPriceX96,
                    sqrtPriceX96,
                    2 ** 96
                );
                uint256 capital = FullMath.mulDiv(amount0, priceX96, 2 ** 96) +
                    amount1;
                console2.log(
                    "Capital weth:",
                    capital /
                        10 **
                            IERC20Metadata(IUniswapV3Pool(info.pool).token1())
                                .decimals()
                );
                console2.log(
                    "New position params:",
                    vm.toString(info.tickLower),
                    vm.toString(info.tickUpper),
                    vm.toString(info.tokenId)
                );
            }
        }

        vm.stopPrank();
    }

    function testSmall() external {
        vm.startPrank(owner);
        UniIntent intent = new UniIntent(positionManager, factory, owner);

        IUniIntent.DepositParams memory depositParams;
        uint32[] memory timespans = new uint32[](2);
        timespans[0] = 20;
        timespans[1] = 30;
        depositParams.tokenId = mint(USDC, WETH, 500, 120, 1e18);
        depositParams.owner = owner;
        depositParams.tickNeighborhood = 10;
        depositParams.slippageD4 = 5;
        depositParams.maxDeviation = 30;
        depositParams.minLiquidityGross = 0;
        depositParams.timespans = timespans;
        positionManager.approve(address(intent), depositParams.tokenId);
        uint256 nftId = intent.deposit(depositParams);
        intent.withdraw(nftId, owner);
        positionManager.approve(address(intent), depositParams.tokenId);
        uint256 nftId2 = intent.deposit(depositParams);
        IUniswapV3Pool pool = IUniswapV3Pool(factory.getPool(USDC, WETH, 500));

        UniIntentBot bot = new UniIntentBot(
            IQuoterV2(quoter),
            ISwapRouter(swapRouter),
            positionManager
        );

        for (uint256 i = 0; i < 10; i++) {
            IUniIntent.TargetNftInfo memory target;
            while (true) {
                movePrice(true);
                uint256[] memory ids = new uint256[](1);
                ids[0] = nftId2;
                (, int24 tick, , , , , ) = pool.slot0();
                bool flag;
                (flag, target) = intent.getTarget(intent.nfts(nftId2), tick);
                skip(5 * 60);
                if (flag) break;
            }

            UniIntentBot.SwapParams memory swapParams = determineSwapAmounts(
                intent,
                bot,
                nftId2
            );
            IUniIntent.RebalanceParams memory rebalanceParams;

            rebalanceParams.ids = new uint256[](1);
            rebalanceParams.ids[0] = nftId2;
            rebalanceParams.offchainTicks = new int24[](1);
            (, rebalanceParams.offchainTicks[0], , , , , ) = pool.slot0();
            rebalanceParams.callback = address(bot);
            ISwapRouter.ExactInputSingleParams[]
                memory uniswapParams = new ISwapRouter.ExactInputSingleParams[](
                    1
                );
            uniswapParams[0] = ISwapRouter.ExactInputSingleParams({
                tokenIn: swapParams.tokenIn,
                tokenOut: swapParams.tokenOut,
                fee: swapParams.fee,
                amountIn: swapParams.amountIn,
                amountOutMinimum: (swapParams.expectedAmountOut * 9999) / 10000,
                deadline: type(uint256).max,
                recipient: address(bot),
                sqrtPriceLimitX96: 0
            });
            rebalanceParams.data = abi.encode(uniswapParams);

            intent.rebalance(rebalanceParams);
            {
                IUniIntent.NftInfo memory info = intent.nfts(nftId2);
                console2.log(
                    "Spot tick before rebalance:",
                    vm.toString(rebalanceParams.offchainTicks[0])
                );
                uint160 sqrtPriceX96;
                (
                    sqrtPriceX96,
                    rebalanceParams.offchainTicks[0],
                    ,
                    ,
                    ,
                    ,

                ) = pool.slot0();
                console2.log(
                    "Spot tick after rebalance:",
                    vm.toString(rebalanceParams.offchainTicks[0])
                );
                (uint256 amount0, uint256 amount1) = PositionValue.total(
                    positionManager,
                    info.tokenId,
                    sqrtPriceX96,
                    IUniswapV3Pool(info.pool)
                );
                uint256 priceX96 = FullMath.mulDiv(
                    sqrtPriceX96,
                    sqrtPriceX96,
                    2 ** 96
                );
                uint256 capital = FullMath.mulDiv(amount0, priceX96, 2 ** 96) +
                    amount1;
                console2.log(
                    "Capital weth:",
                    capital /
                        10 **
                            IERC20Metadata(IUniswapV3Pool(info.pool).token1())
                                .decimals()
                );
                console2.log(
                    "New position params:",
                    vm.toString(info.tickLower),
                    vm.toString(info.tickUpper),
                    vm.toString(info.tokenId)
                );
            }
        }

        vm.stopPrank();
    }

    function _testSmallMultiple() external {
        vm.startPrank(owner);
        UniIntent intent = new UniIntent(positionManager, factory, owner);

        IUniIntent.DepositParams memory depositParams;
        uint32[] memory timespans = new uint32[](2);
        timespans[0] = 20;
        timespans[1] = 30;
        depositParams.tokenId = mint(USDC, WETH, 500, 120, 1e18);
        depositParams.owner = owner;
        depositParams.tickNeighborhood = 10;
        depositParams.slippageD4 = 30;
        depositParams.maxDeviation = 30;
        depositParams.minLiquidityGross = 0;
        depositParams.timespans = timespans;
        positionManager.approve(address(intent), depositParams.tokenId);
        uint256 nftId = intent.deposit(depositParams);

        depositParams.tokenId = mint(USDC, WETH, 500, 240, 1e18);
        positionManager.approve(address(intent), depositParams.tokenId);
        uint256 nftId2 = intent.deposit(depositParams);
        IUniswapV3Pool pool = IUniswapV3Pool(factory.getPool(USDC, WETH, 500));

        UniIntentBot bot = new UniIntentBot(
            IQuoterV2(quoter),
            ISwapRouter(swapRouter),
            positionManager
        );

        for (uint256 i = 0; i < 10; i++) {
            IUniIntent.TargetNftInfo memory target;
            while (true) {
                movePrice(true);
                (, int24 tick, , , , , ) = pool.slot0();
                bool flag;
                (flag, target) = intent.getTarget(intent.nfts(nftId2), tick);
                skip(5 * 60);
                if (flag) break;
            }
            uint256[] memory ids = new uint256[](2);
            ids[0] = nftId;
            ids[1] = nftId2;

            UniIntentBot.SwapParams
                memory swapParams = determineSwapAmountsMultiple(
                    intent,
                    bot,
                    ids
                );
            IUniIntent.RebalanceParams memory rebalanceParams;

            rebalanceParams.ids = ids;
            rebalanceParams.offchainTicks = new int24[](2);
            (, rebalanceParams.offchainTicks[0], , , , , ) = pool.slot0();
            (, rebalanceParams.offchainTicks[1], , , , , ) = pool.slot0();
            rebalanceParams.callback = address(bot);
            ISwapRouter.ExactInputSingleParams[]
                memory uniswapParams = new ISwapRouter.ExactInputSingleParams[](
                    1
                );
            uniswapParams[0] = ISwapRouter.ExactInputSingleParams({
                tokenIn: swapParams.tokenIn,
                tokenOut: swapParams.tokenOut,
                fee: swapParams.fee,
                amountIn: swapParams.amountIn,
                amountOutMinimum: (swapParams.expectedAmountOut * 9999) / 10000,
                deadline: type(uint256).max,
                recipient: address(bot),
                sqrtPriceLimitX96: 0
            });
            rebalanceParams.data = abi.encode(uniswapParams);

            intent.rebalance(rebalanceParams);
            {
                IUniIntent.NftInfo memory info = intent.nfts(nftId2);
                console2.log(
                    "Spot tick before rebalance:",
                    vm.toString(rebalanceParams.offchainTicks[0])
                );
                uint160 sqrtPriceX96;
                (
                    sqrtPriceX96,
                    rebalanceParams.offchainTicks[0],
                    ,
                    ,
                    ,
                    ,

                ) = pool.slot0();
                console2.log(
                    "Spot tick after rebalance:",
                    vm.toString(rebalanceParams.offchainTicks[0])
                );
                (uint256 amount0, uint256 amount1) = PositionValue.total(
                    positionManager,
                    info.tokenId,
                    sqrtPriceX96,
                    IUniswapV3Pool(info.pool)
                );
                uint256 priceX96 = FullMath.mulDiv(
                    sqrtPriceX96,
                    sqrtPriceX96,
                    2 ** 96
                );
                uint256 capital = FullMath.mulDiv(amount0, priceX96, 2 ** 96) +
                    amount1;
                console2.log(
                    "Capital weth:",
                    capital /
                        10 **
                            IERC20Metadata(IUniswapV3Pool(info.pool).token1())
                                .decimals()
                );
                console2.log(
                    "New position params:",
                    vm.toString(info.tickLower),
                    vm.toString(info.tickUpper),
                    vm.toString(info.tokenId)
                );
            }
        }

        vm.stopPrank();
    }
}
