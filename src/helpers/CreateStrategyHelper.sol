// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

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
    }

    uint128 constant MIN_INITIAL_LIQUDITY = 1000;

    INonfungiblePositionManager NONFUNGIBLE_POSITION_MANAGER;
    VeloDeployFactory deployFactory;
    address deployerAddress;

    constructor(
        INonfungiblePositionManager nft_,
        VeloDeployFactory deployFactory_,
        address deployerAddress_
    ) {
        NONFUNGIBLE_POSITION_MANAGER = nft_;
        deployFactory = deployFactory_;
        deployerAddress = deployerAddress_;
    }

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

        int24 maxAllowedDelta = 1;
        int24 tickSpacing = poolParameter.pool.tickSpacing();

        if (tickSpacing == 100) maxAllowedDelta = 50;
        if (tickSpacing == 200) maxAllowedDelta = 100;

        return (
            deployFactory.createStrategy(
                IVeloDeployFactory.DeployParams({
                    tickNeighborhood: 0,
                    slippageD9: 5 * 1e5,
                    tokenId: tokenId,
                    securityParams: abi.encode(
                        IVeloOracle.SecurityParams({
                            lookback: 10,
                            maxAllowedDelta: maxAllowedDelta,
                            maxAge: 7 days
                        })
                    ),
                    strategyType: IPulseStrategyModule.StrategyType.LazySyncing
                })
            ),
            tokenId
        );
    }

    function _mintInitialPosition(
        PoolParameter memory poolParameter
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
            int24 tick,
            ,
            uint16 observationCardinality,
            ,

        ) = poolParameter.pool.slot0();
        if (observationCardinality < 100) {
            poolParameter.pool.increaseObservationCardinalityNext(100);
        }

        _init(poolParameter);

        int24 tickLower = 0;
        int24 tickUpper = 0;
        {
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
        console2.log("tickCurr : ", tick);
        console2.log("tickLower: ", tickLower);
        console2.log("tickUpper: ", tickUpper);

        uint128 actualLiqudity = MIN_INITIAL_LIQUDITY / 2;
        uint256 amount0;
        uint256 amount1;

        /// @dev looking for minimal acceptable liqudity
        do {
            actualLiqudity *= 2;
            (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                actualLiqudity
            );
            console2.log(amount0, amount1);
            require(
                actualLiqudity < type(uint128).max / 10000,
                "too high liqudity"
            );
        } while (amount0 < 10 || amount1 < 10);

        require(amount0 > 0, "too low liqudity for amount0");
        require(amount1 > 0, "too low liqudity for amount1");
        console2.log("Actual Liqudity: ", actualLiqudity);

        IERC20(poolParameter.token0).transferFrom(
            deployerAddress,
            address(this),
            amount0
        );
        IERC20(poolParameter.token1).transferFrom(
            deployerAddress,
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

    function _max(int24 a, int24 b) private pure returns (int24) {
        if (a < b) return b;
        return a;
    }
}
