// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "src/oracles/VeloOracle.sol";
import "src/interfaces/utils/IVeloDeployFactory.sol";
import "src/libraries/external/LiquidityAmounts.sol";

contract CreateStrategyHelper {
    using SafeERC20 for IERC20;

    struct PoolParameter {
        ICLPool pool;
        int24 width;
        uint256 maxAmount0;
        uint256 maxAmount1;
    }

    uint32 constant SLIPPAGE_D9 = 5 * 1e5;
    uint32 constant MAX_AGE = 1 hours;
    uint16 constant MAX_LOOKBACK = 10;
    uint256 constant MIN_AMOUNT_WEI = 1000;
    uint128 constant MIN_INITIAL_LIQUDITY = 1000;
    uint16 constant MIN_OBSERVATION_CARDINALITY = 100;
    int24 constant TICK_NEIGHBORHOOD = 0;
    IStrategyModule.StrategyType constant STRATEGY_TYPE =
        IStrategyModule.StrategyType.LazySyncing;

    address public immutable deployer;
    IVeloDeployFactory public immutable deployFactory;
    ICLFactory public immutable poolFactory;
    INonfungiblePositionManager public immutable positionManager;

    constructor(address deployFactoryAddress, address deployer_) {
        deployer = deployer_;
        deployFactory = IVeloDeployFactory(deployFactoryAddress);
        positionManager = INonfungiblePositionManager(
            deployFactory.getImmutableParams().veloModule.positionManager()
        );
        poolFactory = ICLFactory(positionManager.factory());
    }

    function createStrategy(
        PoolParameter calldata poolParameter
    )
        external
        returns (
            IVeloDeployFactory.PoolAddresses memory poolAddresses,
            uint256 tokenId
        )
    {
        require(msg.sender == deployer, "forbidden");
        require(
            poolFactory.isPool(address(poolParameter.pool)),
            "pool does not belong to the factory"
        );

        tokenId = _mintInitialPosition(poolParameter);

        positionManager.approve(address(deployFactory), tokenId);

        return (
            deployFactory.createStrategy(
                IVeloDeployFactory.DeployParams({
                    tickNeighborhood: TICK_NEIGHBORHOOD,
                    slippageD9: SLIPPAGE_D9,
                    tokenId: tokenId,
                    securityParams: _getSecurityParam(
                        poolParameter.pool.tickSpacing()
                    ),
                    strategyType: STRATEGY_TYPE
                })
            ),
            tokenId
        );
    }

    function _mintInitialPosition(
        PoolParameter calldata poolParameter
    ) private returns (uint256 tokenIdMinted) {
        ICLPool pool = poolParameter.pool;

        IERC20 token0 = IERC20(ICLPool(pool).token0());
        IERC20 token1 = IERC20(ICLPool(pool).token1());
        int24 tickSpacing = pool.tickSpacing();

        (, , , , uint16 observationCardinalityNext, ) = pool.slot0();

        if (observationCardinalityNext < MIN_OBSERVATION_CARDINALITY) {
            pool.increaseObservationCardinalityNext(
                MIN_OBSERVATION_CARDINALITY
            );
        }

        (
            uint256 amount0,
            uint256 amount1,
            int24 tickLower,
            int24 tickUpper
        ) = _getPositionParam(poolParameter);

        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);

        token0.safeIncreaseAllowance(address(positionManager), amount0);
        token1.safeIncreaseAllowance(address(positionManager), amount1);

        (uint256 tokenId, uint128 liquidity, , ) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                tickLower: tickLower,
                tickUpper: tickUpper,
                tickSpacing: tickSpacing,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp + 1,
                sqrtPriceX96: 0
            })
        );

        require(tokenId != 0, "null tokenId");
        require(liquidity != 0, "zero liquidity");

        return tokenId;
    }

    function _getSecurityParam(
        int24 tickSpacing
    ) private pure returns (IOracle.SecurityParams memory securityParam) {
        int24 maxAllowedDelta = tickSpacing / 10; // 10% of tickSpacing
        securityParam = IOracle.SecurityParams({
            lookback: MAX_LOOKBACK,
            maxAllowedDelta: maxAllowedDelta < int24(1)
                ? int24(1)
                : maxAllowedDelta,
            maxAge: MAX_AGE
        });
    }

    function _getPositionParam(
        PoolParameter calldata poolParameter
    )
        private
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            int24 tickLower,
            int24 tickUpper
        )
    {
        (uint160 sqrtPriceX96, int24 tick, , , , ) = poolParameter.pool.slot0();

        IPulseStrategyModule.StrategyParams
            memory strategyParams = IStrategyModule.StrategyParams({
                tickNeighborhood: TICK_NEIGHBORHOOD,
                tickSpacing: poolParameter.pool.tickSpacing(),
                strategyType: STRATEGY_TYPE,
                width: poolParameter.width,
                maxLiquidityRatioDeviationX96: 0
            });

        IVeloDeployFactory.ImmutableParams memory params = deployFactory
            .getImmutableParams();
        IPulseStrategyModule strategyModule = IPulseStrategyModule(
            params.strategyModule
        );
        (, ICore.TargetPositionInfo memory target) = strategyModule
            .calculateTarget(tick, 0, 0, strategyParams);

        (tickLower, tickUpper) = (target.lowerTicks[0], target.upperTicks[0]);
        (amount0, amount1) = _getAmounts(
            poolParameter.maxAmount0,
            poolParameter.maxAmount1,
            sqrtPriceX96,
            tickLower,
            tickUpper
        );
    }

    function _getAmounts(
        uint256 maxAmount0,
        uint256 maxAmount1,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) private pure returns (uint256 amount0, uint256 amount1) {
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint128 actualLiqudity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            maxAmount0,
            maxAmount1
        );

        require(actualLiqudity > MIN_INITIAL_LIQUDITY, "too low liqudity");

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            actualLiqudity
        );

        require(amount0 < maxAmount0, "too high liqudity for amount0");
        require(amount1 < maxAmount1, "too high liqudity for amount1");
        require(amount0 > MIN_AMOUNT_WEI, "too low liqudity for amount0");
        require(amount1 > MIN_AMOUNT_WEI, "too low liqudity for amount1");
    }
}
