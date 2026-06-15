// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "../../test/Imports.sol";
import "./Constants.sol";

import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import "src/interfaces/utils/IVeloDeployFactory.sol";

struct CoreDeployment {
    Core core;
    IVeloAmmModule ammModule;
    IVeloDepositWithdrawModule depositWithdrawModule;
    IVeloOracle oracle;
    IPulseStrategyModule strategyModule;
    VeloDeployFactory deployFactory;
    ILpWrapper lpWrapperImplementation;
}

contract PoolParameters {
    using Math for uint256;

    uint256 constant D6 = 10 ** 6;
    uint256 constant Q32 = 2 ** 96;
    uint256 constant Q96 = 2 ** 96;
    uint256 constant Q128 = 2 ** 128;

    uint256 constant MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT = 0;
    uint32 constant SLIPPAGE_D9_DEFAULT = 5 * 1e5; // 5 * 1e-4 = 0.05%

    uint256 constant ETH_USD_PRICE_D6 = 2150 * 1e6;
    uint256 constant USDC_USD_PRICE_D6 = 1 * 1e6;
    
    /// @dev returns liquidity for 1 USD pushed into width range in given pool
    function _getLiquidityCost(
        IVeloDeployFactory.DeployParams memory poolDeployParams,
        CoreDeployment memory contracts
    ) internal view returns (uint256, uint256) {
        (uint160 sqrtPriceX96, int24 tick) =
            contracts.oracle.getOraclePrice(address(poolDeployParams.pool));
        (, ICore.TargetPositionInfo memory target) = contracts.strategyModule.calculateTarget(
            sqrtPriceX96, tick, new IAmmModule.AmmPosition[](0), poolDeployParams.strategyParams
        );

        uint256 amount0;
        uint256 amount1;
        uint256 totalLiquidity = Q128 - 1; // 1000 ether;//
        for (uint256 i = 0; i < target.lowerTicks.length; i++) {
            (uint256 amount0_, uint256 amount1_) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(target.lowerTicks[i]),
                TickMath.getSqrtRatioAtTick(target.upperTicks[i]),
                uint128(totalLiquidity.mulDiv(target.liquidityRatiosX96[i], Q96))
            );
            amount0 += amount0_;
            amount1 += amount1_;
        }
        // console2.log("target amounts", amount0, amount1);
        uint256 capital0D6 = amount0.mulDiv(D6, poolDeployParams.maxAmount0);
        uint256 capital1D6 = amount1.mulDiv(D6, poolDeployParams.maxAmount1);
        uint256 capitalD6 = capital0D6 + capital1D6;
        //console2.log("target capitals", capital0D6, capital1D6);

        /// @dev capital utilization [1, 2], 1 means just one of token amounts was used, 2 - both in equal
        uint256 utilizationD6 = 2 * D6
            - (capital0D6 > capital1D6 ? (capital0D6 - capital1D6) : (capital1D6 - capital0D6)).mulDiv(
                D6, capitalD6
            );
        // console2.log("capital utilizationD6", utilizationD6);

        /// @dev capital in USD for Q128 of liquidity

        uint256 liquidityPerOneUSD = totalLiquidity.mulDiv(D6, capitalD6); // return liquidity/USD relation
        uint256 initialLiquidity = liquidityPerOneUSD.mulDiv(utilizationD6, D6); // return liquidity/initCapital relation

        // how much liquidity per 1 USD of assets
        return (initialLiquidity, liquidityPerOneUSD);
    }

    function _setInitialAndLimitSupply(
        uint256 totalSupplyLimitUSD,
        IVeloDeployFactory.DeployParams memory poolDeployParams,
        CoreDeployment memory contracts
    ) internal view returns (IVeloDeployFactory.DeployParams memory) {
        /// @dev liquidity amount per 1 USD assets cost
        (uint256 initialLiquidity, uint256 oneUsdLiquidity) =
            _getLiquidityCost(poolDeployParams, contracts);
        poolDeployParams.initialTotalSupply = initialLiquidity;
        poolDeployParams.totalSupplyLimit = oneUsdLiquidity * totalSupplyLimitUSD;
        // console2.log("maxAmounts", poolDeployParams.maxAmount0, poolDeployParams.maxAmount1);
        // console2.log("initialTotalSupply", initialLiquidity);
        // console2.log("totalSupplyLimit", poolDeployParams.totalSupplyLimit);

        return poolDeployParams;
    }

    function getPoolDeployParams(CoreDeployment memory contracts)
        internal
        view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        console2.log("chainId", block.chainid);

         if (block.chainid == 8453) {
            poolDeployParams = _basePoolDeployParams(contracts);
        }else {
            revert("Unsupported chain");
        }

        for (uint256 i = 0; i < poolDeployParams.length; i++) {
            poolDeployParams[i].strategyParams.tickSpacing = poolDeployParams[i].pool.tickSpacing();
        }
    }

    function _basePoolDeployParams(CoreDeployment memory contracts)
        internal
        view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {   
        IVeloDeployFactory.DeployParams memory params;
        poolDeployParams = new IVeloDeployFactory.DeployParams[](100);
        uint256 ID;
        /*
            --------------------------------------------------------------------------------------------------|
                               AERO_FACTORY = 0xf8f2eB4940CFE7d13603DDDD87f123820Fc061Ef
            ------------------------------------------------------------------------------------------------------------------------------|
                                                    address | width|  TS |   t0   |     t1 | limit | strategy | lookback | maxAge | delta |
            ------------------------------------------------------------------------------------------------------------------------------|
            [0]  0x493E74Eda2720e127BAcCC1A19B2D567Bc14aB43 |   10 |  10 |  WETH  | USDC   | 500k  | lazySync |   30     | 1 hour |  42   |
            ------------------------------------------------------------------------------------------------------------------------------|
        */
        params.pool = ICLPool(0x493E74Eda2720e127BAcCC1A19B2D567Bc14aB43);
        params.strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        params.strategyParams.tickSpacing = params.pool.tickSpacing();
        params.strategyParams.tickNeighborhood = 0;
        params.strategyParams.width = 10;
        params.strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
       params.maxAmount0 = 10
            ** (IERC20Metadata(params.pool.token0()).decimals() + 6) / ETH_USD_PRICE_D6;
        params.maxAmount1 = 10 ** (IERC20Metadata(params.pool.token1()).decimals() + 6) / USDC_USD_PRICE_D6;
        params.slippageD9 = SLIPPAGE_D9_DEFAULT;
        params.securityParams.lookback = 30; // ~1min
        params.securityParams.maxAge = 1 hours;
        params.securityParams.maxAllowedDelta = 10; // 1% of position
        _setInitialAndLimitSupply(10, params, contracts);
        poolDeployParams[ID++] = params;

        assembly {
            mstore(poolDeployParams, ID)
        }
    }
                                                    
}