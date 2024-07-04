// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import "src/Core.sol";
import "src/bots/PulseVeloBot.sol";
import "src/modules/velo/VeloAmmModule.sol";
import "src/modules/velo/VeloDepositWithdrawModule.sol";
import "src/modules/strategies/PulseStrategyModule.sol";
import "src/oracles/VeloOracle.sol";
import "src/utils/VeloDeployFactoryHelper.sol";
import "src/utils/VeloDeployFactory.sol";
import "src/interfaces/external/velo/external/IWETH9.sol";

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

    function createStrategy(PoolParameter memory poolParameter) external {
        uint256 tokenId = _mintInitialPosition(poolParameter);

        NONFUNGIBLE_POSITION_MANAGER.approve(address(deployFactory), tokenId);

        int24 maxAllowedDelta = 1;
        int24 tickSpacing = poolParameter.pool.tickSpacing();

        if (tickSpacing == 100) maxAllowedDelta = 50;
        if (tickSpacing == 200) maxAllowedDelta = 100;

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

        (, , , uint16 observationCardinality, , ) = poolParameter.pool.slot0();
        if (observationCardinality < 100) {
            poolParameter.pool.increaseObservationCardinalityNext(100);
        }

        _init(poolParameter);

        (uint160 sqrtPriceX96, int24 tick, , , , ) = poolParameter.pool.slot0();

        int24 tickLower = tick - (tick % poolParameter.tickSpacing);
        int24 tickUpper = tickLower + poolParameter.tickSpacing;
        if (poolParameter.width > 1) {
            tickLower -= poolParameter.tickSpacing * (poolParameter.width / 2);
            tickUpper += poolParameter.tickSpacing * (poolParameter.width / 2);
            tickLower -= poolParameter.tickSpacing * (poolParameter.width % 2);
        }

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                MIN_INITIAL_LIQUDITY * 2
            );

        amount0 = amount0 > 0 ? amount0 : 1;
        amount1 = amount1 > 0 ? amount1 : 1;

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

        (
            uint256 tokenId_,
            uint128 liquidity_,
            ,

        ) = NONFUNGIBLE_POSITION_MANAGER.mint(
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
            
        require(tokenId_ != 0, "null tokenId");
        require(liquidity_ != 0, "zero liquidity");

        tokenIdMinted = tokenId_;
        return tokenIdMinted;
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
}
