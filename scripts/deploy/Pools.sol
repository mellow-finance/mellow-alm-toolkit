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
    uint256 constant ONE_USD_AMOUNT_6 = 10 ** 6; // 1 USD
    uint256 constant ONE_USD_EUR_AMOUNT_6 = uint256(100 * 10 ** 6) / 105; // 1 USD
    uint256 constant ONE_USD_AMOUNT_18 = 10 ** 18; // 1 USD
    uint256 constant ONE_USD_ETH_AMOUNT = uint256(10 ** 18) / 3880; // 1 ETH/3950 ~ 1 USD
    uint256 constant ONE_USD_WSTETH_AMOUNT = uint256(10 ** 18) / 4600; // 1 WSTETH/4600 ~ 1 USD
    uint256 constant ONE_USD_OP_AMOUNT = uint256(100 * 10 ** 18) / 237; // 1 OP ~ 2.56 USD
    uint256 constant ONE_USD_BTC_AMOUNT = uint256(10 ** 8) / 104000; // 1 BTC/104000 ~ 1 USD

    uint256 constant TICK_NEIGHBORHOOD_DEFAULT = 0;
    uint256 constant MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT = 0;
    uint32 constant SLIPPAGE_D9_DEFAULT = 5 * 1e5; // 5 * 1e-4 = 0.05%

    function getPoolDeployParams(CoreDeployment memory contracts)
        internal
        view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        if (block.chainid == 10) {
            poolDeployParams = _optimismPoolDeployParams(contracts);
        } else if (block.chainid == 8453) {
            poolDeployParams = _basePoolDeployParams(contracts);
        } else {
            revert("Unsupported chain");
        }

        for (uint256 i = 0; i < poolDeployParams.length; i++) {
            poolDeployParams[i].strategyParams.tickSpacing = poolDeployParams[i].pool.tickSpacing();
        }
    }

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
        uint256 totalLiquidity = Q128 - 1;
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
        console2.log("target amounts", amount0, amount1);
        uint256 capital0D6 = amount0.mulDiv(D6, poolDeployParams.maxAmount0);
        uint256 capital1D6 = amount1.mulDiv(D6, poolDeployParams.maxAmount1);
        uint256 capitalD6 = capital0D6 + capital1D6;
        console2.log("target capitals", capital0D6, capital0D6);

        /// @dev capital utilization [1, 2], 1 means just one of token amounts was used, 2 - both in equal
        uint256 utilizationD6 = 2 * D6
            - (capital0D6 > capital1D6 ? (capital0D6 - capital1D6) : (capital1D6 - capital0D6)).mulDiv(
                D6, capitalD6
            );
        console2.log("capital utilizationD6", utilizationD6);

        /// @dev capital in USD for Q128 of liquidity

        uint256 liquidityPerOneUSD = totalLiquidity.mulDiv(D6, capitalD6); // return liquidity/USD relation
        uint256 initialLiquidity = liquidityPerOneUSD.mulDiv(utilizationD6, D6);  // return liquidity/initCapital relation

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
        console2.log("maxAmounts", poolDeployParams.maxAmount0, poolDeployParams.maxAmount1);
        console2.log("initialTotalSupply", initialLiquidity);
        console2.log("totalSupplyLimit", poolDeployParams.totalSupplyLimit);

        return poolDeployParams;
    }

    function _optimismPoolDeployParams(CoreDeployment memory contracts)
        internal
        view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        poolDeployParams = new IVeloDeployFactory.DeployParams[](3);
        /*
            CL100-USDC/WETH ($5M TVL) with a $0.5M cap: 0x478946BcD4a5a22b316470F5486fAfb928C0bA25
            CL1-wstETH/WETH ($4M TVL) with a $0.4M cap: 0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4
            CL50-WETH/OP ($50k TVL migrating from the CL200 with $2M) with a $0.5M cap: 0x84a67CD00EB244edCa2288346ADD251A783243c8
            --------------------------------------------------------------------------------------------------|
                               VELO_FACTORY = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F
            ------------------------------------------------------------------------------------------------------------------------------|
                                                    address | width|  TS |   t0   |     t1 | limit | strategy | lookback | maxAge | delta |
            -------------------------------------------------------------------------------|-------|----------|----------|--------|-------|
            [0]  0x478946BcD4a5a22b316470F5486fAfb928C0bA25 | 4200 | 100 | usdc   |   weth |  500k | lazySync |   30     | 1 hour |  42   |
            [1]  0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4 |  280 |   1 | wsteth |   weth |  400k |  tamper  |   30     | 1 hour |   5   |
            [2]  0x84a67CD00EB244edCa2288346ADD251A783243c8 | 6000 |  50 | weth   |     op |  500k | lazySync |   30     | 1 hour |  60   |
            ------------------------------------------------------------------------------------------------------------------------------|
        */

        uint256 ID = 0;
        //---------------------------------------------------------------------------------------
        //    [0]  0x478946BcD4a5a22b316470F5486fAfb928C0bA25 | 4200 | 100 | usdc   |   weth |  500k | lazySync |   30     | 1 hour |  42   |
        poolDeployParams[ID].pool = ICLPool(0x478946BcD4a5a22b316470F5486fAfb928C0bA25);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 4200;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30;  // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 42; // 1% of position
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [1]  0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4 |  280 |   1 | wsteth |   weth |  400k |  tamper  |   30     | 1 hour |   5   |
        poolDeployParams[ID].pool = ICLPool(0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 280;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_WSTETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30;  // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 5; // 1% of position
        _setInitialAndLimitSupply(400000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [2]  0x84a67CD00EB244edCa2288346ADD251A783243c8 | 6000 |  50 | weth   |     op |  500k | lazySync |   30     | 1 hour |  60   |
        poolDeployParams[ID].pool = ICLPool(0x84a67CD00EB244edCa2288346ADD251A783243c8);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_OP_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30;  // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
    }

    function _basePoolDeployParams(CoreDeployment memory contracts)
        internal
        view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        poolDeployParams = new IVeloDeployFactory.DeployParams[](4);

        IVeloOracle.SecurityParams memory SECURITY_PARAMS_DEFAULT = IVeloOracle.SecurityParams({
            lookback: 2, // Maximum number of historical data points to consider for analysis
            maxAge: 1 hours, // Maximum age of observations to be used in the analysis
            maxAllowedDelta: 1 // Maximum allowed change between data points to be considered valid
        });

        /*
        CL100-USDC/WETH ($40M TVL) with a $0.5M cap: 0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59

        CL1-wstETH/WETH ($19M TVL) with a $0.5M cap: 0x861A2922bE165a5Bd41b1E482B49216b465e1B5F

        CL1-EURC/USDC ($1M TVL migrating from the CL50 with $4M) with a $0.5M cap: 0xc5E51044eB7318950B1aFb044FccFb25782C48c1

        CL100-WETH/cbBTC ($38M TVL) with a $0.5M cap 0x70aCDF2Ad0bf2402C957154f944c19Ef4e1cbAE1
            ----------------------------------------------------------------------------------------------|
                                  AERO_FACTORY = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A               |
            ---------------------------------------------------------------------------------------------------|
                                                     address | width|  TS |   t0   |     t1 | limit | strategy |
            --------------------------------------------------------------------------------|-------|-----|----|
            [0]   0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59 | 4000 | 100 |  weth  |  usdc  |  500k |   lazy   |
            [1]   0x861A2922bE165a5Bd41b1E482B49216b465e1B5F |    1 |   1 |  weth  |  wsteth|  500k |  tamper  |
            [2]   0xc5E51044eB7318950B1aFb044FccFb25782C48c1 | 1000 |   1 |  eurc  |  usdc  |  500k |  tamper  |
            [3]   0x70aCDF2Ad0bf2402C957154f944c19Ef4e1cbAE1 | 4000 | 100 |  weth  | cbbtc  |  500k |   lazy   |
            ---------------------------------------------------------------------------------------------------|
        */
        uint256 ID = 0;

        IVeloOracle.SecurityParams memory securityParams = SECURITY_PARAMS_DEFAULT;
        //---------------------------------------------------------------------------------------
        //    [0]   0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59 | 4000 | 100 |  weth  |  usdc  |  500k |   lazy   |
        poolDeployParams[ID].pool = ICLPool(0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 4000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        securityParams = SECURITY_PARAMS_DEFAULT;
        securityParams.maxAllowedDelta = 10; // 0.1%
        poolDeployParams[ID].securityParams = securityParams;
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [1]   0x861A2922bE165a5Bd41b1E482B49216b465e1B5F |    1 |   1 |  weth  |  wsteth|  500k |  tamper  |
        poolDeployParams[ID].pool = ICLPool(0x861A2922bE165a5Bd41b1E482B49216b465e1B5F);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 200;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_WSTETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        securityParams = SECURITY_PARAMS_DEFAULT;
        securityParams.maxAllowedDelta = 1; // 0.1%
        poolDeployParams[ID].securityParams = securityParams;
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [2]   0xc5E51044eB7318950B1aFb044FccFb25782C48c1 | 1000 |   1 |  eurc  |  usdc  |  500k |  tamper  |
        poolDeployParams[ID].pool = ICLPool(0xc5E51044eB7318950B1aFb044FccFb25782C48c1);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 200; // 1.0%
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_EUR_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        securityParams = SECURITY_PARAMS_DEFAULT;
        securityParams.maxAllowedDelta = 1; // 0.1%
        poolDeployParams[ID].securityParams = securityParams;
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [3]   0x70aCDF2Ad0bf2402C957154f944c19Ef4e1cbAE1 | 4000 | 100 |  weth  | cbbtc  |  500k |   lazy   |
        poolDeployParams[ID].pool = ICLPool(0x70aCDF2Ad0bf2402C957154f944c19Ef4e1cbAE1);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 4000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        securityParams = SECURITY_PARAMS_DEFAULT;
        securityParams.maxAllowedDelta = 10; // 0.1%
        poolDeployParams[ID].securityParams = securityParams;
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
    }
}
