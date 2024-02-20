// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../src/Core.sol";
import "../../src/bots/PulseUniBot.sol";

import "../../src/modules/univ3/UniV3AmmModule.sol";
import "../../src/modules/strategies/PulseStrategyModule.sol";
import "../../src/oracles/UniV3Oracle.sol";

import "../../src/interfaces/external/univ3/IUniswapV3Factory.sol";
import "../../src/interfaces/external/univ3/IUniswapV3Pool.sol";
import "../../src/interfaces/external/univ3/INonfungiblePositionManager.sol";

import "../../src/libraries/external/PositionValue.sol";
import "../../src/libraries/external/LiquidityAmounts.sol";

contract UniIntentTest is Test {
    using SafeERC20 for IERC20;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    INonfungiblePositionManager public positionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    IUniswapV3Factory public factory =
        IUniswapV3Factory(positionManager.factory());
    address public swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public quoter = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;

    address public owner = address(0x7ee9247b6199877F86703644c97784495549aC5E);

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
            deal(USDT, owner, amountIn);
            IERC20(USDT).safeIncreaseAllowance(swapRouter, amountIn);
            ISwapRouter(swapRouter).exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: USDT,
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
                    tokenOut: USDT,
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
        Core intent,
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
        Core intent,
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
        Core core,
        PulseUniBot bot,
        uint256 id
    ) public returns (PulseUniBot.SwapParams memory) {
        ICore.NftsInfo memory info = core.nfts(id);
        IUniswapV3Pool pool = IUniswapV3Pool(info.pool);
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
        ) = removePosition(core, tokenId, pool);

        PulseUniBot.SwapParams memory swapParams = bot
            .calculateSwapAmountsPreciselySingle(
                PulseUniBot.SingleIntervalData({
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

        addPosition(core, tokenId, pool, liquidityAmount0, liquidityAmount1);

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
        Core core,
        PulseUniBot bot,
        uint256[] memory ids
    ) public returns (PulseUniBot.SwapParams memory) {
        Data memory data;

        data.liq0 = new uint256[](ids.length);
        data.liq1 = new uint256[](ids.length);

        data.sqrtLowerRatiosX96 = new uint160[](ids.length);
        data.sqrtUpperRatiosX96 = new uint160[](ids.length);
        data.ratiosX96 = new uint256[](ids.length);
        {
            (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(
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
            IUniswapV3Pool pool = IUniswapV3Pool(info.pool);
            (bool flag, ICore.TargetNftsInfo memory target) = core
                .strategyModule()
                .getTargets(info, core.ammModule(), core.oracle());

            uint256 tokenId = info.tokenIds[0];
            if (tokenId == 0) revert("Invalid token id");
            if (!flag) revert("Rebalance is not necessary");
            uint256 amount0_;
            uint256 amount1_;
            (amount0_, amount1_, data.liq0[i], data.liq1[i]) = removePosition(
                core,
                tokenId,
                pool
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

        PulseUniBot.SwapParams memory swapParams = bot
            .calculateSwapAmountsPreciselyMultiple(
                PulseUniBot.MultipleIntervalsData({
                    amount0: data.amount0,
                    amount1: data.amount1,
                    ratiosX96: data.ratiosX96,
                    sqrtLowerRatiosX96: data.sqrtLowerRatiosX96,
                    sqrtUpperRatiosX96: data.sqrtUpperRatiosX96,
                    pool: IUniswapV3Pool(core.nfts(ids[0]).pool)
                })
            );

        for (uint256 i = 0; i < ids.length; i++) {
            ICore.NftsInfo memory nftInfo = core.nfts(ids[i]);
            addPosition(
                core,
                nftInfo.tokenIds[0],
                IUniswapV3Pool(nftInfo.pool),
                data.liq0[i],
                data.liq1[i]
            );
        }
        return swapParams;
    }

    UniV3AmmModule public ammModule;
    PulseStrategyModule public strategyModule;
    UniV3Oracle public oracle;

    function test() external {
        vm.startPrank(owner);

        ammModule = new UniV3AmmModule(
            INonfungiblePositionManager(positionManager)
        );
        strategyModule = new PulseStrategyModule();
        oracle = new UniV3Oracle();
        Core core = new Core(
            ammModule,
            strategyModule,
            oracle,
            address(positionManager),
            owner
        );

        ICore.DepositParams memory depositParams;
        uint32[] memory timespans = new uint32[](2);
        timespans[0] = 20;
        timespans[1] = 30;
        depositParams.tokenIds = new uint256[](1);
        depositParams.tokenIds[0] = mint(USDT, WETH, 500, 120, 1e17);
        depositParams.owner = owner;

        depositParams.strategyParams = abi.encode(
            PulseStrategyModule.StrategyParams({
                tickNeighborhood: 20,
                tickSpacing: 10,
                lazyMode: false
            })
        );
        depositParams.securityParams = abi.encode(
            UniV3Oracle.SecurityParams({
                anomalyLookback: 5,
                anomalyOrder: 3,
                anomalyFactorD9: 2e9
            })
        );

        depositParams.slippageD4 = 10;
        positionManager.approve(address(core), depositParams.tokenIds[0]);
        uint256 nftId = core.deposit(depositParams);
        core.withdraw(nftId, owner);
        positionManager.approve(address(core), depositParams.tokenIds[0]);
        uint256 nftId2 = core.deposit(depositParams);
        IUniswapV3Pool pool = IUniswapV3Pool(factory.getPool(USDT, WETH, 500));

        PulseUniBot bot = new PulseUniBot(
            IQuoterV2(quoter),
            ISwapRouter(swapRouter),
            positionManager
        );

        for (uint256 i = 0; i < 2; i++) {
            ICore.TargetNftsInfo memory target;
            while (true) {
                movePrice(true);
                uint256[] memory ids = new uint256[](1);
                ids[0] = nftId2;
                bool flag;
                (flag, target) = core.strategyModule().getTargets(
                    core.nfts(nftId2),
                    core.ammModule(),
                    core.oracle()
                );
                skip(5 * 60);
                if (flag) break;
            }

            PulseUniBot.SwapParams memory swapParams = determineSwapAmounts(
                core,
                bot,
                nftId2
            );
            ICore.RebalanceParams memory rebalanceParams;

            rebalanceParams.ids = new uint256[](1);
            rebalanceParams.ids[0] = nftId2;
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

            core.rebalance(rebalanceParams);
            {
                ICore.NftsInfo memory info = core.nfts(nftId2);
                uint160 sqrtPriceX96;
                (sqrtPriceX96, , , , , , ) = pool.slot0();

                (uint256 amount0, uint256 amount1) = PositionValue.total(
                    positionManager,
                    info.tokenIds[0],
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
                    "Capital usdt:",
                    capital /
                        10 **
                            IERC20Metadata(IUniswapV3Pool(info.pool).token1())
                                .decimals()
                );
                console2.log(
                    "New position params:",
                    vm.toString(info.tokenIds[0])
                );
            }
        }

        vm.stopPrank();
    }
}
