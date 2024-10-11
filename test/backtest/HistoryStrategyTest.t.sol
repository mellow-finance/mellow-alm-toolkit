// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import "../../test/velo-prod/integration/IntegrationTest.t.sol";
import "../../src/modules/strategies/PulseStrategyModule.sol";
import "../../src/bots/PulseVeloBot.sol";

struct SwapTransaction {
    int256 amount0;
    int256 amount1;
    uint256 block;
    uint160 sqrtPriceX96;
    uint128 liquidity;
    int24 tickLower;
    int24 tickUpper;
    bytes32 txHash;
}

contract HistoryTest is Test {
    using SafeERC20 for ERC20;
    uint256 constant Q96 = 2 ** 96;
    uint256 constant Q128 = 2 ** 128;
    uint32 public immutable MELLOW_PROTOCOL_FEE = 1e8;
    address public immutable MELLOW_PROTOCOL_TREASURY =
        address(bytes20((keccak256("treasury"))));

    ICLFactory public factory;
    INonfungiblePositionManager public immutable manager =
        INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER);
    IVeloOracle private oracle;
    IPulseStrategyModule private strategyModule;
    IVeloDeployFactoryHelper private velotrDeployFactoryHelper;
    IVeloAmmModule private ammModule;
    IVeloDepositWithdrawModule private veloDepositWithdrawModule;
    ICore private core;
    VeloDeployFactory private veloDeployFactory;
    IPulseVeloBot private pulseVeloBot;

    IPulseStrategyModule.StrategyParams public strategyParams;
    ICLPool private pool;
    ERC20 private token0;
    ERC20 private token1;
    uint256 public tokenId;
    uint256 public totalValueInToken0;
    uint256 public totalValueInToken1;
    uint256 public totalValueInToken0Last;
    uint256 public totalValueInToken1Last;
    uint256 public fee0;
    uint256 public fee1;
    uint256 public fee0Cummulative;
    uint256 public fee1Cummulative;

    event call(address from);
    event Balances(uint256 amount0, uint256 amount1);
    event poolToken(address pool, address token0, address token1);
    event Transaction(
        uint256 tp,
        int256 amount0,
        int256 amount1,
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    );

    constructor(
        address pool_,
        address oracle_,
        address strategyModule_,
        address velotrDeployFactoryHelper_,
        address ammModule_,
        address veloDepositWithdrawModule_,
        address pulseVeloBot_
    ) {
        oracle = IVeloOracle(oracle_);
        strategyModule = IPulseStrategyModule(strategyModule_);
        velotrDeployFactoryHelper = IVeloDeployFactoryHelper(
            velotrDeployFactoryHelper_
        );
        ammModule = IVeloAmmModule(ammModule_);
        veloDepositWithdrawModule = IVeloDepositWithdrawModule(
            veloDepositWithdrawModule_
        );
        core = new Core(ammModule, strategyModule, oracle, address(this));
        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    feeD9: 1e8,
                    treasury: Constants.PROTOCOL_TREASURY
                })
            )
        );
        core.setOperatorFlag(false);
        veloDeployFactory = new VeloDeployFactory(
            address(this),
            core,
            veloDepositWithdrawModule,
            velotrDeployFactoryHelper
        );
        pulseVeloBot = IPulseVeloBot(pulseVeloBot_);
        pool = ICLPool(pool_); //ICLPool(factory.getPool(Constants.USDC, Constants.WETH, 30000));
        factory = ICLFactory(pool.factory());
        pool.increaseObservationCardinalityNext(100);
        token0 = ERC20(pool.token0());
        token1 = ERC20(pool.token1());
        emit poolToken(address(pool), address(token0), address(token1));
    }

    function setUpStrategy(int24 width) public {
        _setUpPool();
        if (tokenId != 0) {
            revert("strategy is alredy set up");
        }
        init();
        int24 tickSpacing = pool.tickSpacing();

        (uint160 sqrtPriceX96, int24 tick, , , , ) = pool.slot0();

        int24 tickLower = tickSpacing * (tick / tickSpacing);
        int24 tickUpper = tickLower + tickSpacing;
        if (width > 1) {
            tickLower -= tickSpacing * (width / 2);
            tickUpper += tickSpacing * (width / 2);
            tickLower -= tickSpacing * (width % 2);
        }
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmount1(
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            10 ** ERC20(pool.token1()).decimals()
        );
        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity + 1
            );

        (tokenId, liquidity, , ) = manager.mint(
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
                recipient: address(this),
                deadline: block.timestamp,
                sqrtPriceX96: 0
            })
        );
        manager.approve(address(veloDeployFactory), tokenId);

        veloDeployFactory.updateMutableParams(
            IVeloDeployFactory.MutableParams({
                lpWrapperAdmin: address(this),
                lpWrapperManager: address(0),
                farmOwner: address(this),
                farmOperator: address(this),
                minInitialLiquidity: liquidity - 1
            })
        );
        veloDeployFactory.createStrategy(
            IVeloDeployFactory.DeployParams({
                tickNeighborhood: 0,
                slippageD9: 1e8,
                tokenId: tokenId,
                securityParams: abi.encode(
                    IVeloOracle.SecurityParams({
                        lookback: 1,
                        maxAge: 1 days,
                        maxAllowedDelta: 1000
                    })
                ),
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing
            })
        );
    }

    function _setUpPool() private {
        (uint160 sqrtPriceX96, int24 tick, , , , ) = pool.slot0();
        tick = tick - (tick % pool.tickSpacing());
        int24 tickLower = tick - 10000;
        int24 tickUpper = tick + 10000;

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            10000 * 10 ** ERC20(pool.token0()).decimals(),
            10000 * 10 ** ERC20(pool.token1()).decimals()
        );
        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity + 1
            );

        /// @dev mint fake position to cover all range
        (uint256 tokenId_, uint256 liquidity_, , ) = manager.mint(
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
                recipient: address(this),
                deadline: block.timestamp,
                sqrtPriceX96: 0
            })
        );
        console2.log("fake", tokenId_, liquidity_);
    }

    function init() public {
        if (address(this).balance > 0) {
            IWETH9(Constants.WETH).deposit{value: address(this).balance}();
        }
        token0.approve(address(this), type(uint256).max);
        token0.approve(address(pool), type(uint256).max);
        token0.approve(address(manager), type(uint256).max);
        token1.approve(address(this), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);
        token1.approve(address(manager), type(uint256).max);
        emit Balances(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        require(msg.sender == address(pool), "Unauthorized swap callback");
        address recipient = abi.decode(data, (address));
        if (amount0Delta > 0) {
            token0.safeTransferFrom(
                recipient,
                address(pool),
                uint256(amount0Delta)
            );
        }
        if (amount1Delta > 0) {
            token1.safeTransferFrom(
                recipient,
                address(pool),
                uint256(amount1Delta)
            );
        }
    }

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external {
        require(msg.sender == address(pool), "Unauthorized mint callback");
        address sender = abi.decode(data, (address));
        if (amount0Owed > 0) {
            token0.safeTransferFrom(sender, address(pool), amount0Owed);
        }
        if (amount1Owed > 0) {
            token1.safeTransferFrom(sender, address(pool), amount1Owed);
        }
    }

    function _swapAmount(
        int256 amount0,
        int256 amount1
    ) private returns (bool result) {
        bool zeroForOne = amount0 > 0 ? true : false;
        int256 amountSpecified = zeroForOne ? amount0 : amount1;
        uint160 sqrtPriceLimitX96 = zeroForOne
            ? TickMath.MIN_SQRT_RATIO + 1
            : TickMath.MAX_SQRT_RATIO - 1;
        result = true;
        try
            pool.swap(
                address(this),
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96,
                abi.encode(address(this))
            )
        {} catch {
            result = false;
        }
        return result;
    }

    function _swapToPrice(
        uint160 sqrtPriceLimitX96
    ) private returns (bool result) {
        (uint160 sqrtPrice, , , , , ) = pool.slot0();
        bool zeroForOne = sqrtPriceLimitX96 < sqrtPrice ? true : false;

        result = true;
        try
            pool.swap(
                address(this),
                zeroForOne,
                type(int256).max,
                sqrtPriceLimitX96,
                abi.encode(address(this))
            )
        {} catch {
            result = false;
        }
        return result;
    }

    function _mint(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    ) private returns (bool result) {
        result = true;
        try
            pool.mint(
                address(this),
                tickLower,
                tickUpper,
                liquidity,
                abi.encode(address(this))
            )
        {} catch {
            result = false;
        }
        return result;
    }

    function _burn(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    ) private returns (bool result) {
        result = true;
        try pool.burn(tickLower, tickUpper, liquidity) {} catch {
            result = false;
        }
        return result;
    }

    function poolTransaction(
        SwapTransaction[] memory transactions
    ) public returns (uint256 successfulTransactions) {
        for (uint256 i = 0; i < transactions.length; i++) {
            if (_swapToPrice(transactions[i].sqrtPriceX96)) {
                successfulTransactions++;
                _rebalance();
            }
        }
        return successfulTransactions;
    }

    function _getFeeGrowthInside(
        int24 tickCurrent,
        int24 tickLower,
        int24 tickUpper
    )
        private
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        if (tickLower > tickUpper) {
            (tickLower, tickUpper) = (tickUpper, tickLower);
        }

        (
            ,
            ,
            ,
            uint256 lowerFeeGrowthOutside0X128,
            uint256 lowerFeeGrowthOutside1X128,
            ,
            ,
            ,
            ,

        ) = pool.ticks(tickLower);
        (
            ,
            ,
            ,
            uint256 upperFeeGrowthOutside0X128,
            uint256 upperFeeGrowthOutside1X128,
            ,
            ,
            ,
            ,

        ) = pool.ticks(tickUpper);

        if (tickCurrent < tickLower) {
            feeGrowthInside0X128 = lowerFeeGrowthOutside0X128 >
                upperFeeGrowthOutside0X128
                ? lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128
                : 0;
            feeGrowthInside1X128 = lowerFeeGrowthOutside1X128 >
                upperFeeGrowthOutside1X128
                ? lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128
                : 0;
        } else if (tickCurrent < tickUpper) {
            uint256 feeGrowthGlobal0X128 = pool.feeGrowthGlobal0X128();
            uint256 feeGrowthGlobal1X128 = pool.feeGrowthGlobal1X128();
            uint256 delta0 = lowerFeeGrowthOutside0X128 +
                upperFeeGrowthOutside0X128;
            feeGrowthInside0X128 = delta0 > feeGrowthGlobal0X128
                ? feeGrowthGlobal0X128
                : feeGrowthGlobal0X128 - delta0;
            uint256 delta1 = lowerFeeGrowthOutside1X128 +
                upperFeeGrowthOutside1X128;
            feeGrowthInside1X128 = delta1 > feeGrowthGlobal1X128
                ? feeGrowthGlobal1X128
                : feeGrowthGlobal1X128 - delta1;
        } else {
            feeGrowthInside0X128 = upperFeeGrowthOutside0X128 >
                lowerFeeGrowthOutside0X128
                ? upperFeeGrowthOutside0X128 - lowerFeeGrowthOutside0X128
                : 0;
            feeGrowthInside1X128 = upperFeeGrowthOutside1X128 >
                lowerFeeGrowthOutside1X128
                ? upperFeeGrowthOutside1X128 - lowerFeeGrowthOutside1X128
                : 0;
        }
    }

    function _positionView() private {
        (
            ,
            ,
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            ,

        ) = manager.positions(tokenId);

        (uint160 sqrtPriceX96, int24 tick, , , , ) = pool.slot0();
        (
            uint256 feeGrowthInside0X128,
            uint256 feeGrowthInside1X128
        ) = _getFeeGrowthInside(tick, tickLower, tickUpper);

        fee0 = feeGrowthInside0X128 > feeGrowthInside0LastX128
            ? Math.mulDiv(
                liquidity,
                feeGrowthInside0X128 - feeGrowthInside0LastX128,
                Q128
            )
            : 0;
        fee1 = feeGrowthInside1X128 > feeGrowthInside1LastX128
            ? Math.mulDiv(
                liquidity,
                feeGrowthInside1X128 - feeGrowthInside1LastX128,
                Q128
            )
            : 0;
        (totalValueInToken0Last, totalValueInToken1Last) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );
    }

    function _rebalance() private {
        _positionView();
        try
            core.rebalance(
                ICore.RebalanceParams({
                    ids: new uint256[](1),
                    callback: address(pulseVeloBot),
                    data: abi.encode(
                        new ISwapRouter.ExactInputSingleParams[](0)
                    )
                })
            )
        {
            ICore.ManagedPositionInfo memory position = core.managedPositionAt(
                0
            );
            uint256 tokenIdNew = position.ammPositionIds[0];
            if (tokenIdNew != tokenId) {
                tokenId = tokenIdNew;
                fee0Cummulative += fee0;
                fee1Cummulative += fee1;
                fee0 = 0;
                fee1 = 0;
            }
        } catch {}
    }
}
