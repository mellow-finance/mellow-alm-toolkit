// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "src/oracles/VeloOracle.sol";
import "src/utils/VeloDeployFactory.sol";
import "src/libraries/external/LiquidityAmounts.sol";

contract CreateStrategyHelper {
    struct PoolParameter {
        ICLPool pool;
        ICLFactory factory;
        address token0;
        address token1;
        int24 tickSpacing;
        int24 width;
        IVeloOracle.SecurityParams securityParams;
    }

    uint128 constant MIN_INITIAL_LIQUDITY = 1000;

    INonfungiblePositionManager NONFUNGIBLE_POSITION_MANAGER;
    VeloDeployFactory deployFactory;

    constructor(
        INonfungiblePositionManager nft_,
        VeloDeployFactory deployFactory_
    ) {
        NONFUNGIBLE_POSITION_MANAGER = nft_;
        deployFactory = deployFactory_;
    }

    function createStrategy(
        PoolParameter memory poolParameter,
        uint256 minAmount
    )
        external
        returns (
            VeloDeployFactory.PoolAddresses memory poolAddresses,
            uint256 tokenId
        )
    {
        tokenId = _mintInitialPosition(poolParameter, minAmount);

        NONFUNGIBLE_POSITION_MANAGER.approve(address(deployFactory), tokenId);

        return (
            deployFactory.createStrategy(
                IVeloDeployFactory.DeployParams({
                    tickNeighborhood: 0,
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
        PoolParameter memory poolParameter,
        uint256 minAmount
    ) private returns (uint256 tokenIdMinted) {
        require(
            poolParameter.factory.getPool(
                poolParameter.token0,
                poolParameter.token1,
                poolParameter.pool.tickSpacing()
            ) == address(poolParameter.pool),
            "pool does not belong to the factory"
        );
        require(
            poolParameter.pool.token0() == poolParameter.token0,
            "wrong token0"
        );
        require(
            poolParameter.pool.token1() == poolParameter.token1,
            "wrong token1"
        );
        require(
            poolParameter.pool.tickSpacing() == poolParameter.tickSpacing,
            "wrong pool tickSpacing"
        );

        (
            uint160 sqrtPriceX96,
            ,
            ,
            uint16 observationCardinality,
            ,

        ) = poolParameter.pool.slot0();
        if (observationCardinality < 100) {
            poolParameter.pool.increaseObservationCardinalityNext(100);
        }

        _init(poolParameter);

        uint128 actualLiqudity = MIN_INITIAL_LIQUDITY / 2;
        uint256 amount0;
        uint256 amount1;
        (int24 tickLower, int24 tickUpper) = _getTickRange(poolParameter);

        /// @dev looking for minimal acceptable liqudity
        do {
            actualLiqudity *= 2;
            (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                actualLiqudity
            );
            require(
                actualLiqudity < type(uint128).max / 10000,
                "too high liqudity"
            );
        } while (amount0 < minAmount || amount1 < minAmount);

        require(amount0 > 0, "too low liqudity for amount0");
        require(amount1 > 0, "too low liqudity for amount1");

        IERC20(poolParameter.token0).transferFrom(
            msg.sender,
            address(this),
            amount0
        );
        IERC20(poolParameter.token1).transferFrom(
            msg.sender,
            address(this),
            amount1
        );

        (uint256 tokenId, uint128 liquidity, , ) = NONFUNGIBLE_POSITION_MANAGER
            .mint(
                INonfungiblePositionManager.MintParams({
                    token0: poolParameter.token0,
                    token1: poolParameter.token1,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    tickSpacing: poolParameter.tickSpacing,
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

    function _init(PoolParameter memory poolParameter) private {
        IERC20 token0 = IERC20(poolParameter.token0);
        IERC20 token1 = IERC20(poolParameter.token1);
        token0.approve(address(poolParameter.pool), type(uint256).max);
        token0.approve(
            address(NONFUNGIBLE_POSITION_MANAGER),
            type(uint256).max
        );
        token1.approve(address(poolParameter.pool), type(uint256).max);
        token1.approve(
            address(NONFUNGIBLE_POSITION_MANAGER),
            type(uint256).max
        );
    }

    function _getTickRange(
        PoolParameter memory poolParameter
    ) private view returns (int24 tickLower, int24 tickUpper) {
        (, int24 tick, , , , ) = poolParameter.pool.slot0();
        tickLower = tick - poolParameter.width / 2;
        int24 remainder = tickLower % poolParameter.tickSpacing;
        if (remainder < 0) remainder += poolParameter.tickSpacing;
        tickLower -= remainder;
        tickUpper = tickLower + poolParameter.width;
        if (
            tickUpper < tick ||
            _max(tick - tickLower, tickUpper - tick) >
            _max(
                tick - (tickLower + poolParameter.tickSpacing),
                (tickUpper + poolParameter.tickSpacing) - tick
            )
        ) {
            tickLower += poolParameter.tickSpacing;
            tickUpper += poolParameter.tickSpacing;
        }
    }

    function _max(int24 a, int24 b) private pure returns (int24) {
        if (a < b) return b;
        return a;
    }
}
