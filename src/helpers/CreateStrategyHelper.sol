// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "src/oracles/VeloOracle.sol";
import "src/utils/VeloDeployFactory.sol";
import "src/libraries/external/LiquidityAmounts.sol";

contract CreateStrategyHelper {

    using SafeERC20 for IERC20;

    struct PoolParameter {
        ICLPool pool;
        int24 width;
        uint256 maxAmount0;
        uint256 maxAmount1;
        IVeloOracle.SecurityParams securityParams;
    }

    uint128 constant MIN_INITIAL_LIQUDITY = 1000;
    int24 immutable tickNeighborhood = 0;

    ICLFactory immutable CL_FACTORY = ICLFactory(0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F);
    INonfungiblePositionManager immutable NONFUNGIBLE_POSITION_MANAGER = INonfungiblePositionManager(0x416b433906b1B72FA758e166e239c43d68dC6F29);
    VeloDeployFactory immutable deployFactory;

    constructor() {}

    function createStrategy(
        PoolParameter memory poolParameter
    )
        external
        returns (
            VeloDeployFactory.PoolAddresses memory poolAddresses,
            uint256 tokenId
        )
    {
        tokenId = _mintInitialPosition(poolParameter);

        NONFUNGIBLE_POSITION_MANAGER.approve(address(deployFactory), tokenId);

        return (
            deployFactory.createStrategy(
                IVeloDeployFactory.DeployParams({
                    tickNeighborhood: tickNeighborhood,
                    slippageD9: 5 * 1e5,
                    tokenId: tokenId,
                    securityParams: abi.encode(poolParameter.securityParams),
                    strategyType: IPulseStrategyModule.StrategyType.LazySyncing
                })
            ),
            tokenId
        );
    }

    function _mintInitialPosition(
        PoolParameter memory poolParameter
    ) private returns (uint256 tokenIdMinted) {

        ICLPool pool = poolParameter.pool;

        require(CL_FACTORY.isPair(address(pool)), "pool does not belong to factoy");

        IERC20 token0 = IERC20(ICLPool(pool).token0());
        IERC20 token1 = IERC20(ICLPool(pool).token1());
        int24 tickSpacing = pool.tickSpacing();

        (
            uint160 sqrtPriceX96,
            int24 tick,
            ,
            uint16 observationCardinality,
            ,
        ) = pool.slot0();

        if (observationCardinality < 100) {
            pool.increaseObservationCardinalityNext(100);
        }

        IPulseStrategyModule.StrategyParams
            memory strategyParams = IPulseStrategyModule.StrategyParams({
                tickNeighborhood: tickNeighborhood,
                tickSpacing: tickSpacing,
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                width: poolParameter.width
            });

        IVeloDeployFactory.ImmutableParams memory params = deployFactory.getImmutableParams();
        IPulseStrategyModule strategyModule = IPulseStrategyModule(params.strategyModule);
        (,ICore.TargetPositionInfo memory target) = strategyModule.calculateTarget(tick, 0, 0, strategyParams);

        (int24 tickLower, int24 tickUpper) = (target.lowerTicks[0], target.upperTicks[0]);

        uint128 actualLiqudity = LiquidityAmounts.getMaxLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            poolParameter.maxAmount0,
            poolParameter.maxAmount1
        );

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper), 
            actualLiqudity);

        require(amount0 < poolParameter.maxAmount0, "too high liqudity for amount0");
        require(amount1 < poolParameter.maxAmount1, "too high liqudity for amount1");
        require(amount0 > 0, "too low liqudity for amount0");
        require(amount1 > 0, "too low liqudity for amount1");

        token0.safeApprove(address(pool), amount0);
        token1.safeApprove(address(pool), amount1);

        token0.safeApprove(address(NONFUNGIBLE_POSITION_MANAGER), amount0);
        token1.safeApprove(address(NONFUNGIBLE_POSITION_MANAGER), amount1);

        token0.safeTransferFrom(
            msg.sender,
            address(this),
            amount0
        );
        token1.safeTransferFrom(
            msg.sender,
            address(this),
            amount1
        );

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

}
