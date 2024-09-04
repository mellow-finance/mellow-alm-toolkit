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

    uint32 immutable SLIPPAGE_D9 = 5 * 1e5;
    uint32 immutable MAX_AGE = 1 hours;
    uint128 immutable MIN_INITIAL_LIQUDITY = 1000;
    int24 immutable TICK_NEIGHBEORHOOD = 0;
    IPulseStrategyModule.StrategyType immutable STRATEGY_TYPE = IPulseStrategyModule.StrategyType.LazySyncing;

    ICLFactory immutable CL_FACTORY =
        ICLFactory(0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F);

    INonfungiblePositionManager immutable NONFUNGIBLE_POSITION_MANAGER =
        INonfungiblePositionManager(0x416b433906b1B72FA758e166e239c43d68dC6F29);

    IVeloDeployFactory immutable deployFactory;

    constructor(address deployFactoryAddress) {
        deployFactory = IVeloDeployFactory(deployFactoryAddress);
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
        require(
            CL_FACTORY.isPair(address(poolParameter.pool)),
            "pool does not belong to the factory"
        );

        tokenId = _mintInitialPosition(poolParameter);

        NONFUNGIBLE_POSITION_MANAGER.approve(address(deployFactory), tokenId);

        return (
            deployFactory.createStrategy(
                IVeloDeployFactory.DeployParams({
                    tickNeighborhood: TICK_NEIGHBEORHOOD,
                    slippageD9: SLIPPAGE_D9,
                    tokenId: tokenId,
                    securityParams: abi.encode(
                        _getSecurityParam(poolParameter.pool.tickSpacing())
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

        (, , , uint16 observationCardinality, , ) = pool.slot0();

        if (observationCardinality < 100) {
            pool.increaseObservationCardinalityNext(100);
        }

        (
            uint256 amount0,
            uint256 amount1,
            int24 tickLower,
            int24 tickUpper
        ) = _getPositionParam(poolParameter);

        token0.safeApprove(address(NONFUNGIBLE_POSITION_MANAGER), amount0);
        token1.safeApprove(address(NONFUNGIBLE_POSITION_MANAGER), amount1);

        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);

        (uint256 tokenId, uint128 liquidity, , ) = NONFUNGIBLE_POSITION_MANAGER
            .mint(
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
                    deadline: block.timestamp + 3000,
                    sqrtPriceX96: 0
                })
            );

        require(tokenId != 0, "null tokenId");
        require(liquidity != 0, "zero liquidity");

        return tokenId;
    }

    function _getSecurityParam(
        int24 tickSpacing
    ) private pure returns (IVeloOracle.SecurityParams memory securityParam) {
        int24 maxAllowedDelta = tickSpacing / 10; // 10% of tickSpacing
        securityParam = IVeloOracle.SecurityParams({
            lookback: 10,
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
            memory strategyParams = IPulseStrategyModule.StrategyParams({
                tickNeighborhood: TICK_NEIGHBEORHOOD,
                tickSpacing: poolParameter.pool.tickSpacing(),
                strategyType: STRATEGY_TYPE,
                width: poolParameter.width
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
        uint128 actualLiqudity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            maxAmount0,
            maxAmount1
        );

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            actualLiqudity
        );
        
        require(amount0 < maxAmount0, "too high liqudity for amount0");
        require(amount1 < maxAmount1, "too high liqudity for amount1");
        require(amount0 > 0, "too low liqudity for amount0");
        require(amount1 > 0, "too low liqudity for amount1");
    }
}
