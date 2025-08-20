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
    uint256 constant ONE_USD_EUR_AMOUNT_6 = uint256(100 * 10 ** 6) / 114; // 1 USD
    uint256 constant ONE_USD_AMOUNT_18 = 10 ** 18; // 1 USD
    uint256 constant ONE_USD_ETH_AMOUNT = uint256(10 ** 18) / 3700; // 1 ETH/1,548 ~ 1 USD
    uint256 constant ONE_USD_WEETH_AMOUNT = uint256(10 ** 18) / 1675; // 1 ETH/2150 ~ 1 USD
    uint256 constant ONE_USD_WSTETH_AMOUNT = uint256(10 ** 18) / 3170; // 1 WSTETH/3321 ~ 1 USD
    uint256 constant ONE_USD_OP_AMOUNT = uint256(100 * 10 ** 18) / 62; // 1 OP ~ 1.14 USD
    uint256 constant ONE_USD_AERO_AMOUNT = uint256(100 * 10 ** 18) / 59; // 1 AERO ~ 0.89 USD
    uint256 constant ONE_USD_VELO_AMOUNT = uint256(100 * 10 ** 18) / 5; // 1 VELO ~ 0.046 USD
    uint256 constant ONE_USD_BTC_AMOUNT_8 = uint256(10 ** 8) / 104500; // 1 BTC/81685 ~ 1 USD
    uint256 constant ONE_USD_BTC_AMOUNT_18 = uint256(10 ** 18) / 118000; // 1 BTC/82500 ~ 1 USD

    uint256 constant ONE_USD_USOL_AMOUNT = uint256(10 ** 18) / 201; // 1 USOL ~ 201.6 USD
    uint256 constant ONE_USD_VVV_AMOUNT = uint256(100 * 10 ** 18) / 573; // 1 VVV ~ 5.73 USD
    uint256 constant ONE_USD_AIXBT_AMOUNT = uint256(100 * 10 ** 18) / 29; // 1 AIXBT ~ 0.291914 USD
    uint256 constant ONE_USD_VIRT_AMOUNT = uint256(100 * 10 ** 18) / 132; // 1 VIRT ~ 1.320 USD
    uint256 constant ONE_USD_ASTR_AMOUNT = uint256(100 * 10 ** 18) / 4; // 1 ASTR ~ 0.039 USD
    uint256 constant ONE_USD_MODE_AMOUNT = uint256(100 * 10 ** 18) / 1; // 1 ASTR ~ 0.011 USD
    uint256 constant ONE_USD_WLD_AMOUNT = uint256(100 * 10 ** 18) / 80; // 1 WILD ~ 0.80 USD
    uint256 constant ONE_USD_KAITO_AMOUNT = uint256(100 * 10 ** 18) / 134; // 1 KAITO ~ 1.34 USD
    uint256 constant ONE_USD_BRETT_AMOUNT = uint256(1000 * 10 ** 18) / 33; // 1 BRETT ~ 0.03320 USD
    uint256 constant ONE_USD_DEGEN_AMOUNT = uint256(10000 * 10 ** 18) / 33; // 1 DEGEN ~ 0.003268 USD
    uint256 constant ONE_USD_BNKR_AMOUNT = uint256(100000 * 10 ** 18) / 24; // 1 BNKR ~ 0.0002380 USD
    uint256 constant ONE_USD_MORPHO_AMOUNT = uint256(100 * 10 ** 18) / 130; // 1 MORPHO ~ 1.3 USD
    uint256 constant ONE_USD_TOSHI_AMOUNT = uint256(100000 * 10 ** 18) / 37; // 1 TOSHI ~ 0.0003670 USD
    uint256 constant ONE_USD_B3_AMOUNT = uint256(10000 * 10 ** 18) / 57; // 1 B3 ~ 0.0057 USD
    uint256 constant ONE_USD_uSUI_AMOUNT = uint256(100 * 10 ** 18) / 218; // 2.18
    uint256 constant ONE_USD_uXRP_AMOUNT = uint256(100 * 10 ** 18) / 200; // 2.00
    uint256 constant ONE_USD_uSOL_AMOUNT = uint256(10 ** 18) / 117; // 117
    uint256 constant ONE_USD_AAVE_AMOUNT = uint256(10 ** 18) / 174;
    uint256 constant ONE_USD_PROMPT_AMOUNT = uint256(100 * 10 ** 18) / 29;
    uint256 constant ONE_USD_ZORA_AMOUNT = uint256(1000 * 10 ** 18) / 10;
    uint256 constant ONE_USD_SUPR_AMOUNT = uint256(10000 * 10 ** 18) / 35; // 0.00352

    uint256 constant ONE_USD_MAMO_AMOUNT = uint256(100 * 10 ** 18) / 14; // 0.1439
    uint256 constant ONE_USD_cbLTC_AMOUNT = uint256(100 * 10 ** 18) / 11405; // 114.05
    uint256 constant ONE_USD_cbADA_AMOUNT = uint256(100 * 10 ** 18) / 87; // 0.8705
    uint256 constant ONE_USD_cbDOGE_AMOUNT = uint256(100 * 10 ** 18) / 26; // 0.2667
    uint256 constant ONE_USD_cbXRP_AMOUNT = uint256(100 * 10 ** 6) / 349; // 3.49
    uint256 constant ONE_USD_WELL_AMOUNT = uint256(1000 * 10 ** 18) / 39; // 0.03915
    uint256 constant ONE_USD_REI_AMOUNT = uint256(100 * 10 ** 18) / 11; // 0.1163
    uint256 constant ONE_USD_CLANKER_AMOUNT = uint256(100 * 10 ** 18) / 3581; // 35.81
    uint256 constant ONE_USD_KTA_AMOUNT = uint256(100 * 10 ** 18) / 85; // 0.8495
    uint256 constant ONE_USD_GAME_AMOUNT = uint256(1000 * 10 ** 18) / 42; // 0.04284
    uint256 constant ONE_USD_GIZA_AMOUNT = uint256(10000 * 10 ** 18) / 1462; // 0.1462
    uint256 constant ONE_USD_SPX_AMOUNT = uint256(100 * 10 ** 8) / 184; // 1.84
    uint256 constant ONE_USD_HOME_AMOUNT = uint256(10000 * 10 ** 18) / 297; // 0.0297
    uint256 constant ONE_USD_Anon_AMOUNT = uint256(100 * 10 ** 18) / 291; // 2.91
    uint256 constant ONE_USD_DOGE_AMOUNT = uint256(10000 * 10 ** 8) / 2653; // 0.2653

    uint256 constant ETH_USD_PRICE_D6 = 4255 * 1e6;
    uint256 constant BTC_USD_PRICE_D6 = 122000 * 1e6;
    uint256 constant CELO_USD_PRICE_D6 = 0.3425 * 1e6;
    uint256 constant LSK_USD_PRICE_D6 = 0.4521 * 1e6;

    uint256 constant MAMO_USD_PRICE_D6 = 0.1439 * 1e6;
    uint256 constant cbLTC_USD_PRICE_D6 = 114.05 * 1e6;
    uint256 constant cbADA_USD_PRICE_D6 = 0.8705 * 1e6;
    uint256 constant cbDOGE_USD_PRICE_D6 = 0.2667 * 1e6;
    uint256 constant cbXRP_USD_PRICE_D6 = 3.49 * 1e6;
    uint256 constant WELL_USD_PRICE_D6 = 0.03915 * 1e6;
    uint256 constant REI_USD_PRICE_D6 = 0.1163 * 1e6;
    uint256 constant CLANKER_USD_PRICE_D6 = 35.81 * 1e6;
    uint256 constant KTA_USD_PRICE_D6 = 0.8495 * 1e6;
    uint256 constant GAME_USD_PRICE_D6 = 0.04284 * 1e6;
    uint256 constant GIZA_USD_PRICE_D6 = 0.1462 * 1e6;
    uint256 constant SPX_USD_PRICE_D6 = 1.84 * 1e6;
    uint256 constant HOME_USD_PRICE_D6 = 0.0297 * 1e6;
    uint256 constant Anon_USD_PRICE_D6 = 2.91 * 1e6;
    uint256 constant DEGEN_USD_PRICE_D6 = 0.003268 * 1e6;

    uint256 constant mooBIFI_USD_PRICE_D6 = 237.05 * 1e6;
    uint256 constant wstUSR_USD_PRICE_D6 = 1.10 * 1e6;

    uint256 constant ONE_USD_DOG_AMOUNT = uint256(100000 * 10 ** 18) / 64; // 0.0006419
    uint256 constant ONE_USD_KLIMA_AMOUNT = uint256(100 * 10 ** 9) / 22; // 0.22
    uint256 constant ONE_USD_RIZE_AMOUNT = uint256(1000 * 10 ** 18) / 46; // 0.045 USD
    uint256 constant ONE_USD_COOKIE_AMOUNT = uint256(100 * 10 ** 18) / 24; //0.24 USD
    uint256 constant ONE_USD_LSETH_AMOUNT = uint256(10 ** 18) / 2685; // 2685 USD
    uint256 constant ONE_USD_BSDETH_AMOUNT = uint256(10 ** 18) / 2556; // 2556 USD
    uint256 constant ONE_USD_RLP_AMOUNT = uint256(100 * 10 ** 18) / 120; // 1.2 USD
    uint256 constant ONE_USD_wstUSR_AMOUNT = uint256(100 * 10 ** 18) / 108; // 1.08 USD
    uint256 constant ONE_USD_RFL_AMOUNT = uint256(100 * 10 ** 18) / 22; // 0.222115 USD

    uint256 constant ONE_USD_CELO_AMOUNT = uint256(100 * 10 ** 18) / 32; // 1 CELO ~ 0.2893 USD

    uint256 constant TICK_NEIGHBORHOOD_DEFAULT = 0;
    uint256 constant MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT = 0;
    uint32 constant SLIPPAGE_D9_DEFAULT = 5 * 1e5; // 5 * 1e-4 = 0.05%

    function _oneUSDAmount(address token, uint256 priceD6) internal view returns (uint256) {
        return 10 ** (IERC20Metadata(token).decimals() + 6) / priceD6;
    }

    function getPoolDeployParams(CoreDeployment memory contracts)
        internal
        view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        console2.log("chainId", block.chainid);

        if (block.chainid == 10) {
            poolDeployParams = _optimismPoolDeployParams(contracts);
        } else if (block.chainid == 8453) {
            poolDeployParams = _basePoolDeployParams(contracts);
        } else if (block.chainid == 1868) {
            poolDeployParams = _soneiumPoolDeployParams(contracts);
        } else if (block.chainid == 34443) {
            poolDeployParams = _modePoolDeployParams(contracts);
        } else if (block.chainid == 57073) {
            poolDeployParams = _inkPoolDeployParams(contracts);
        } else if (block.chainid == 1923) {
            poolDeployParams = _swellPoolDeployParams(contracts);
        } else if (block.chainid == 130) {
            poolDeployParams = _uniPoolDeployParams(contracts);
        } else if (block.chainid == 5330) {
            poolDeployParams = _superPoolDeployParams(contracts);
        } else if (block.chainid == 42220) {
            poolDeployParams = _celoPoolDeployParams(contracts);
        } else if (block.chainid == 1135) {
            poolDeployParams = _liskPoolDeployParams(contracts);
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

    function _optimismPoolDeployParams(CoreDeployment memory contracts)
        internal
        view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        poolDeployParams = new IVeloDeployFactory.DeployParams[](22);
        /*
            --------------------------------------------------------------------------------------------------|
                               VELO_FACTORY = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F
            ------------------------------------------------------------------------------------------------------------------------------|
                                                    address | width|  TS |   t0   |     t1 | limit | strategy | lookback | maxAge | delta |
            -------------------------------------------------------------------------------|-------|----------|----------|--------|-------|
            [0]  0x478946BcD4a5a22b316470F5486fAfb928C0bA25 | 4200 | 100 | usdc   |   weth |  500k | lazySync |   30     | 1 hour |  42   |
            [1]  0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4 |  280 |   1 | wsteth |   weth |  400k |  tamper  |   30     | 1 hour |   5   |
            [2]  0x84a67CD00EB244edCa2288346ADD251A783243c8 | 6000 |  50 | weth   |     op |  500k | lazySync |   30     | 1 hour |  60   |

            [3]  0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60 | 6400 | 200 | weth   |     op |  500k | lazySync |   30     | 1 hour |  64   |
            [4]  0xeBD5311beA1948e1441333976EadCFE5fBda777C | 9600 | 200 | usdc   |     op |  100k | lazySync |   30     | 1 hour |  96   |
            [5]  0x39eD27D101Aa4b7cE1cb4293B877954B8b5e14e5 |14400 | 200 | weth   |   velo |  100k | lazySync |   30     | 1 hour | 144   |
            [6]  0x319C0DD36284ac24A6b2beE73929f699b9f48c38 | 2400 | 100 | weth   |   wbtc |  200k | lazySync |   30     | 1 hour |  24   |
            [7]  0x2FA71491F8070FA644d97b4782dB5734854c0f6F |    3 |   1 | usdc   | usdc.e |  100k | lazySync |   30     | 1 hour |   1   |
            [8]  0xEE1baC98527a9fDd57fcCf967817215B083cE1F0 | 8800 | 200 | usdc   | wsteth |  100k | lazySync |   30     | 1 hour |  88   |
            [9]  0x8949A8E02998d76D7a703cAC9eE7e0f529828011 |   80 |   1 | wbtc   |   tbtc |  300k | lazySync |   30     | 1 hour |   8   |
            [10] 0x3C01ec09D15D5450FC702DC4353b17Cd2978d8a5 |  160 |   1 | usdc   |   sUSC |  500k |  tamper  |   30     | 1 hour |   5   |
            [11] 0xf9e06512342997AB79694a077132cE3F380144cD |   48 |   1 | weth   |   reth |  300k | lazyDesc |   30     | 1 hour |   5   |

            [12] 0x7cfc2Da3ba598ef4De692905feDcA32565AB836E |12000 | 200 | usdc   |   velo |   70k | lazySync |   30     | 1 hour | 120   |
            [13] 0x4e5541815227E3272C405886149F45D2F437C7Ff |16000 | 200 | usdc   |    wld |   70k | lazySync |   30     | 1 hour | 160   |

            [14] 0x84Ce89B4f6F67E523A81A82f9f2F14D84B726F6B |  12  |   1 | USDC   |   USDT |  130k |  tamper  |   30     | 1 hour |   1   |

            [15] 0x4DA46c6AFe7322b66EFEfda1f702605Cbe08E0Bd |  12  |   1 | USDT0  |   USDT | 3000k |  tamper  |   30     | 1 hour |   1   |
            [16] 0xa9F987869bfe56D3a2Ece2e79df55684D0bBCd8b | 4800 | 100 | USDT0  |   WETH |  153k | lazySync |   30     | 1 hour |   48  |

            [17] 0xec3d9098BD40ec741676fc04D4bd26BCCF592aa3 | 6000 | 200 | WETH   |   tBTC |   65K | lazySync |   30     | 1 hour |   60  |
            [18] 0xe5cF854f63152067059AFd38e03FEFb6CBE25Df3 | 6000 | 200 | wstETH |   OP   |   20K | lazySync |   30     | 1 hour |   60  |
            [19] 0xf7f575F2c0f6C99fa9EfE1bDE9E11fA10BE4FEF9 |  12  |   1 | USDT0  |   USDC |  100K |  tamper  |   30     | 1 hour |    1  |

            [20] 0x173cDC71e29d5Cffa6D090AD99f555a24B8831f9 | 20000| 200 | USDC   |mooBIFI |   50K | lazySync |   30     | 1 hour |    1  |
            [21] 0x5483484F876218908CA435F08222751F7f7b2a3b |  12  |   1 | USDC   |  oUSDT |   80K |  tamper  |   30     | 1 hour |    1  |
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
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
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
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
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
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
        //[3]  0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60 | 6400 | 200 | weth   |     op |  500k | lazySync |   30     | 1 hour |  64   |
        poolDeployParams[ID].pool = ICLPool(0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6400;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_OP_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 64; // 1% of position
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
        //    [4]  0xeBD5311beA1948e1441333976EadCFE5fBda777C | 9600 | 200 | usdc   |     op |  100k | lazySync |   30     | 1 hour |  96   |
        poolDeployParams[ID].pool = ICLPool(0xeBD5311beA1948e1441333976EadCFE5fBda777C);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 9600;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_OP_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 96; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //    [5]  0x39eD27D101Aa4b7cE1cb4293B877954B8b5e14e5 |14400 | 200 | weth   |   velo |  100k | lazySync |   30     | 1 hour | 144   |
        poolDeployParams[ID].pool = ICLPool(0x39eD27D101Aa4b7cE1cb4293B877954B8b5e14e5);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 14400;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_VELO_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 144; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //    [6]  0x319C0DD36284ac24A6b2beE73929f699b9f48c38 | 2400 | 100 | weth   |   wbtc |  200k | lazySync |   30     | 1 hour |  24   |
        poolDeployParams[ID].pool = ICLPool(0x319C0DD36284ac24A6b2beE73929f699b9f48c38);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 2400;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 24; // 1% of position
        _setInitialAndLimitSupply(200000, poolDeployParams[ID], contracts);
        ID++;
        //    [7]  0x2FA71491F8070FA644d97b4782dB5734854c0f6F |    3 |   1 | usdc   | usdc.e |  100k | lazySync |   30     | 1 hour |   1   |
        poolDeployParams[ID].pool = ICLPool(0x2FA71491F8070FA644d97b4782dB5734854c0f6F);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 3;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 1; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //    [8]  0xEE1baC98527a9fDd57fcCf967817215B083cE1F0 | 8800 | 200 | usdc   | wsteth |  100k | lazySync |   30     | 1 hour |  88   |
        poolDeployParams[ID].pool = ICLPool(0xEE1baC98527a9fDd57fcCf967817215B083cE1F0);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 8800;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_WSTETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 88; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //    [9]  0x8949A8E02998d76D7a703cAC9eE7e0f529828011 |   80 |   1 | wbtc   |   tbtc |  300k | lazySync |   30     | 1 hour |   8   |
        poolDeployParams[ID].pool = ICLPool(0x8949A8E02998d76D7a703cAC9eE7e0f529828011);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 80;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_18;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 8; // 1% of position
        _setInitialAndLimitSupply(300000, poolDeployParams[ID], contracts);
        ID++;
        //    [10] 0x3C01ec09D15D5450FC702DC4353b17Cd2978d8a5 |  160 |   1 | usdc   |   sUSC |  500k |  tamper  |   30     | 1 hour |   5   |
        poolDeployParams[ID].pool = ICLPool(0x3C01ec09D15D5450FC702DC4353b17Cd2978d8a5);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 160;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_18;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 5; // 1% of position
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
        //    [11] 0xf9e06512342997AB79694a077132cE3F380144cD |   48 |   1 | weth   |   reth |  300k | lazyDesc |   30     | 1 hour |   5   |
        poolDeployParams[ID].pool = ICLPool(0xf9e06512342997AB79694a077132cE3F380144cD);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazyDescending;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 48;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 5; // 1% of position
        _setInitialAndLimitSupply(300000, poolDeployParams[ID], contracts);
        ID++;
        //    [12] 0x7cfc2Da3ba598ef4De692905feDcA32565AB836E |12000 | 200 | usdc   |   velo |   70k | lazySync |   30     | 1 hour | 120   |
        poolDeployParams[ID].pool = ICLPool(0x7cfc2Da3ba598ef4De692905feDcA32565AB836E);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_VELO_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 120; // 1% of position
        _setInitialAndLimitSupply(70000, poolDeployParams[ID], contracts);
        ID++;
        //    [13] 0x4e5541815227E3272C405886149F45D2F437C7Ff |16000 | 200 | usdc   |    wld |   70k | lazySync |   30     | 1 hour | 160   |
        poolDeployParams[ID].pool = ICLPool(0x4e5541815227E3272C405886149F45D2F437C7Ff);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 16000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_WLD_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 160; // 1% of position
        _setInitialAndLimitSupply(70000, poolDeployParams[ID], contracts);
        ID++;
        //   [14] 0x84Ce89B4f6F67E523A81A82f9f2F14D84B726F6B |  12  |   1 | USDC   |   USDT |  130k |  tamper  |   30     | 1 hour |   1   |
        poolDeployParams[ID].pool = ICLPool(0x84Ce89B4f6F67E523A81A82f9f2F14D84B726F6B);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 1; // 1% of position
        _setInitialAndLimitSupply(130000, poolDeployParams[ID], contracts);
        ID++;
        //    [15] 0x4DA46c6AFe7322b66EFEfda1f702605Cbe08E0Bd |  12  |   1 | USDT0  |   USDT | 3000k |  tamper  |   30     | 1 hour |   1   |
        poolDeployParams[ID].pool = ICLPool(0x4DA46c6AFe7322b66EFEfda1f702605Cbe08E0Bd);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 1; // 1% of position
        _setInitialAndLimitSupply(3000000, poolDeployParams[ID], contracts);
        ID++;
        //    [16] 0xa9F987869bfe56D3a2Ece2e79df55684D0bBCd8b | 6000 | 100 | USDT0  |   WETH |  153k | lazySync |   30     | 1 hour |   60  |
        poolDeployParams[ID].pool = ICLPool(0xa9F987869bfe56D3a2Ece2e79df55684D0bBCd8b);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 4800;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 48; // 1% of position
        _setInitialAndLimitSupply(153000, poolDeployParams[ID], contracts);
        ID++;
        //    [17] 0xec3d9098BD40ec741676fc04D4bd26BCCF592aa3 | 6000 | 200 | WETH   |   tBTC |   65K | lazySync |   30     | 1 hour |   60  |
        poolDeployParams[ID].pool = ICLPool(0xec3d9098BD40ec741676fc04D4bd26BCCF592aa3);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_18;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(65000, poolDeployParams[ID], contracts);
        ID++;
        //    [18] 0xe5cF854f63152067059AFd38e03FEFb6CBE25Df3 | 6000 | 200 | wstETH |   OP   |   20K | lazySync |   30     | 1 hour |   60  |
        poolDeployParams[ID].pool = ICLPool(0xe5cF854f63152067059AFd38e03FEFb6CBE25Df3);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_WSTETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_OP_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(20000, poolDeployParams[ID], contracts);
        ID++;
        //    [19] 0xf7f575F2c0f6C99fa9EfE1bDE9E11fA10BE4FEF9 |  12  |   1 | USDT0  |   USDC |  100K |  tamper  |   30     | 1 hour |    1  |
        poolDeployParams[ID].pool = ICLPool(0xf7f575F2c0f6C99fa9EfE1bDE9E11fA10BE4FEF9);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 1; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //    [20] 0x173cDC71e29d5Cffa6D090AD99f555a24B8831f9 | 20000| 200 | USDC   |mooBIFI |  50K | lazySync |   30     | 1 hour |    1  |
        poolDeployParams[ID].pool = ICLPool(0x173cDC71e29d5Cffa6D090AD99f555a24B8831f9);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 =
            _oneUSDAmount(address(poolDeployParams[ID].pool.token1()), mooBIFI_USD_PRICE_D6);
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(50000, poolDeployParams[ID], contracts);
        ID++;
        //    [21] 0x5483484F876218908CA435F08222751F7f7b2a3b |  12  |   1 | USDC   |  oUSDT |  80K |  tamper  |   30     | 1 hour |    1  |
        poolDeployParams[ID].pool = ICLPool(0x5483484F876218908CA435F08222751F7f7b2a3b);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 1; // 1% of position
        _setInitialAndLimitSupply(80000, poolDeployParams[ID], contracts);
        ID++;
    }

    function _basePoolDeployParams(CoreDeployment memory contracts)
        internal
        view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        poolDeployParams = new IVeloDeployFactory.DeployParams[](69);
        /*
            ----------------------------------------------------------------------------------------------|
                                  AERO_FACTORY = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A               |
            ---------------------------------------------------------------------------------------------------|---------------------------|
                                                     address | width|  TS |   t0   |     t1 | limit | strategy | lookback | maxAge | delta |
            --------------------------------------------------------------------------------|-------|----------|----------|--------|-------|
            [0]   0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59 | 4000 | 100 |  weth  |  usdc  |  500k |   lazy   |
            [1]   0x861A2922bE165a5Bd41b1E482B49216b465e1B5F |  200 |   1 |  weth  |  wsteth|  500k |  tamper  |
            [2]   0xc5E51044eB7318950B1aFb044FccFb25782C48c1 | 1000 |   1 |  eurc  |  usdc  |  500k |  tamper  |
            [3]   0x70aCDF2Ad0bf2402C957154f944c19Ef4e1cbAE1 | 4000 | 100 |  weth  | cbbtc  |  500k |   lazy   |

            [4]   0x82321f3BEB69f503380D6B233857d5C43562e2D0 | 19200| 200 |  weth  |  aero  | 1000k | lazySync |   30     | 1 hour | 192   |
            [5]   0x47cA96Ea59C13F72745928887f84C9F52C3D7348 |  128 |   1 |  cbETH |  weth  | 1000k |  tamper  |   30     | 1 hour |   5   |
            [6]   0x4e962BB3889Bf030368F56810A9c96B83CB3E778 |  800 | 100 |  usdc  | cbbtc  | 1000k | lazySync |   30     | 1 hour |   8   |
            [7]   0xa41Bc0AFfbA7Fd420d186b84899d7ab2aC57fcD1 |   12 |   1 |  usdc  |  usdt  |  500k |  tamper  |   30     | 1 hour |   1   |
            [8]   0x0225Ba893D5f8Ecd6d2022f9dEC59b34F61098A1 | 9600 | 200 |  weth  |  usol  |  500k | lazySync |   30     | 1 hour |  96   |
            [9]   0xC200F21EfE67c7F41B81A854c26F9cdA80593065 | 20800| 200 |  virt  |  weth  | 1000k | lazySync |   30     | 1 hour | 208   |
            [10]  0x22A52bB644f855ebD5ca2edB643FF70222D70C31 | 20800| 200 |  weth  |  aixbt |  500k | lazySync |   30     | 1 hour | 208   |
            [11]  0x7eC6C9D993D9832Aa654593f2Dbc21303650Bc6c | 20800| 200 |  weth  |   vvv  |  500k | lazySync |   30     | 1 hour | 208   |

            [12]  0x4d9199269D4F89a367965e90d07D6F4AF7750eD0 | 6000 | 100 |  OETHb | cbBTC  |   60k | lazySync |   30     | 1 hour |  60   |
            [13]  0x3f0296BF652e19bca772EC3dF08b32732F93014A | 20000| 100 |  virt  |  weth  |   80k | lazySync |   30     | 1 hour | 200   |
            [14]  0x56b92E5B391DbFb8b8028AC95A4b97f52ffEB416 | 20000| 100 |  weth  | KAITO  |  300k | lazySync |   30     | 1 hour | 200   |
            [15]  0x93617b2909a7c207E4180dE0E667ea80c9BdfE9e | 6000 | 100 |  weth  | oUSDT  |  100k | lazySync |   30     | 1 hour |  60   |

            [16]  0xE846373C1a92B167b4E9cd5d8E4d6B1Db9E90EC7 | 1000 |  50 |  EURC  | USDC  |  2800k |  tamper  |   30     | 1 hour |  60   |
            [17]  0xbD3cd0D9d429b41F0a2e1C026552Bd598294d5E0 |  128 |   1 |  weETH | WETH  |   480k |  tamper  |   30     | 1 hour |  60   |
            [18]  0x4e829F8A5213c42535AB84AA40BD4aDCCE9cBa02 | 20000| 200 |  WETH  | BRETT |  1400k | lazySync |   30     | 1 hour |  60   |
            [19]  0x9785eF59E2b499fB741674ecf6fAF912Df7b3C1b |  5000| 100 |  WETH  |  USDT |   280k | lazySync |   30     | 1 hour |  60   |
            [20]  0xaFB62448929664Bfccb0aAe22f232520e765bA88 | 20000| 200 |  WETH  | DEGEN |    80k | lazySync |   30     | 1 hour |  60   |
            [21]  0xCDD442e2De893c07146B2F1072f8e077559f9aa4 | 20000| 200 |  BNKR  |  WETH |    30k | lazySync |   30     | 1 hour |  60   |
            [22]  0xB5F0b4aE66C14F7EFaA9aA1468E8FC536A3E288c | 20000| 200 |  WETH  | MORPHO|  1200k | lazySync |   30     | 1 hour |  60   |
            [23]  0x7501bc8Bb51616F79bfA524E464fb7B41f0B10fB |  100 |  50 | msUSD  |  USDC |  1200k |  tamper  |   30     | 1 hour |  60   |
            [24]  0x74E4c08Bb50619b70550733D32b7e60424E9628e | 20000| 200 | WETH   | TOSHI |    80k | lazySync |   30     | 1 hour |  60   |
            [25]  0xB099C658e784b41EE435d48a8eb67e8f27285C93 | 20000| 100 | WETH   |   B3  |  1000k | lazySync |   30     | 1 hour |  60   |

            [26]  0x5C45b0F48c326f79b56709d8F63CE2beE7697106 | 10000| 200 | WETH   |  uSUI |   535k | lazySync |   30     | 1 hour |  60   |
            [27]  0x61C6e9E93592e535Efc1BEE07f491A517e98f6d0 | 10000| 200 | uXRP   |  WETH |   205k | lazySync |   30     | 1 hour |  60   |
            [28]  0xC900eA56B5227aE2d95c288a2597B278Cbf741dd | 10000| 200 | uSOL   | cbBTC |   155k | lazySync |   30     | 1 hour |  60   |

            [29]  0x3f53f1Fd5b7723DDf38D93a584D280B9b94C3111 | 19200| 100 | ZORA   | USDC  |   189k | lazySync |   30     | 1 hour |  100  |
            [30]  0xdFe5F275020def30993f042174Fc2D335678b626 | 19200| 200 | AERO   | cbBTC |   369k | lazySync |   30     | 1 hour |  100  |
            [31]  0x41D60eD9C8327EA0c6b16a44343c177E0402FeeA | 19200| 100 | PROMPT | cbBTC |   141k | lazySync |   30     | 1 hour |  100  |
            [32]  0x3e66e55e97ce60096f74b7C475e8249f2D31a9fb | 8000 | 2000| USDC   | cbBTC |  1000k | lazySync |   30     | 1 hour |  100  |
            [33]  0x5d4e504EB4c526995E0cC7A6E327FDa75D8B52b5 | 6400 | 100 | WETH   | EURC  |  540k  | lazySync |   30     | 1 hour |  100  |
            [34]  0x4a79B0168296c0eF7b8F314973B82aD406a29f1B | 10000| 200 | WETH   | AAVE  |  1000k | lazySync |   30     | 1 hour |  100  |
            [35]  0x138aceE5573fA09e7F215965ff60898cc33c6330 |  128 |   1 |  tBTC  | cbBTC |  1000k |  tamper  |   30     | 1 hour |  12   |
            [36]  0xA44D3Bb767d953711EA4Bce8C0F01f4d7D299aF6 |  128 |   1 |  cbBTC |  LBTC |  1000k |  tamper  |   30     | 1 hour |  12   |

            [37]  0x088c39ee29fC30DF8Adc394e9f7dEa33E3A26507 | 19200| 200 | WETH   |doginme|   100k | lazySync |   30     | 1 hour |  100  |
            [38]  0x2DB199a5D0EffAe36236E13FDb62aa43Eb3e14eC | 19200| 200 | USDC   | KLIMA |    10k | lazySync |   30     | 1 hour |  100  |
            [39]  0xEa5cb64754Ad7aA24F7A6BBe3b724F29B4f822B8 | 19200| 200 | USDC   | RIZE  |   180k | lazySync |   30     | 1 hour |  100  |
            [40]  0xE8833415Bd6Aee9c0c7B6aaD7DC80421C3F28ca1 | 19200| 200 | USDC   | COOKIE|   200k | lazySync |   30     | 1 hour |  100  |
            [41]  0x4D69971CCd4A636c403a3C1B00c85e99bB9B5606 | 6400 | 100 | WETH   |  USD+ |   300k | lazySync |   30     | 1 hour |  100  |
            [42]  0x04f8375dAd560480D6639B9600CD88ca594E2293 |   48 |   1 | WETH   | LsETH |  2500k | lazyDesc |   30     | 1 hour |    2  |
            [43]  0x2ae9DF02539887d4EbcE0230168a302d34784c82 |   48 |   1 | WETH   |bsdETH |   800k | lazyDesc |   30     | 1 hour |    2  |
            
            [44]  0x576607EC0eA744c38124B3C12fD894f97b67143e |  200 |  50 |  USR   | wstUSR|    50k |  tamper  |   30     | 1 hour |  12   |
            [45]  0xf4D5f114d029657Bd55511b359d2A0Ad73620d17 |  200 |  50 |  USR   |    RLP|    50k |  tamper  |   30     | 1 hour |  12   |

            [46]  0x51c230951b82Dbf7b8696B6fCd2be199cC10779f | 10000| 100 |  RFL   |   USDC|    25k | lazySync |   30     | 1 hour |  12   |

            [47]  0x46D710c35BdfB800a18A820712310048Ef8B5256 | 20000| 200 |  WETH  |  KTA  |   350K | lazySync |   30     | 1 hour |  12   |
            [48]  0xBE00fF35AF70E8415D0eB605a286D8A45466A4c1 | 20000| 2000|  USDC  | AERO  |   1.5M | lazySync |   30     | 1 hour |  12   |
            [49]  0x4BA1e3E9280facbAcaFA7baF4aE0b78Bea60beCa | 20000| 200 |  WETH  |  SPX  |   400K | lazySync |   30     | 1 hour |  12   |
            [50]  0xd23FE2DB317e1A96454a2D1c7e8fc0DbF19BB000 | 20000| 200 | CLANKER| WETH  |   100K | lazySync |   30     | 1 hour |  12   |
            [51]  0x4A021bA3ab1F0121e7DF76f345C547db86Cb3468 | 20000| 200 | VIRTUAL| MAMO  |   1.0M | lazySync |   30     | 1 hour |  12   |
            [52]  0x95Ff4985af7ED78421215be100c18a2b987f7E90 | 10000| 100 | cbXRP  |cbBTC  |   650K | lazySync |   30     | 1 hour |  12   |
            [53]  0x363d1607b8DA83d6B6EA76D017CeEcf1316BB08A | 20000| 100 | cbBTC  |cbDOGE |   253K | lazySync |   30     | 1 hour |  12   |
            [54]  0x8782d97C8b25B4d17dBFbaa03f25dC18e51e909D | 20000| 100 | cbADA  |cbBTC  |    30K | lazySync |   30     | 1 hour |  12   |
            [55]  0x6044c817e55A03DAdc5F6b8B7045aF1985aE90fA | 20000| 100 | cbLTC  |cbBTC  |   250K | lazySync |   30     | 1 hour |  12   |
            [56]  0x54cdD0222dF6B3BC17754c2C1B3d7D4203FE3d89 | 20000| 200 | WETH   | REI   |    80K | lazySync |   30     | 1 hour |  12   |
            [57]  0x3Ba9ce0f19cF3CcB631b973c83712C7E6E9585ae | 20000| 200 | WETH   | WELL  |   250K | lazySync |   30     | 1 hour |  12   |
            [58]  0x68a5aEA4DE3D938a755D85d1868Fe79A9C7B6ae1 | 20000| 100 | WETH   | DEGEN |   200K | lazySync |   30     | 1 hour |  12   |
            [59]  0xb862F23ba38c8C65e256782B31E8C08C9aefd612 | 20000| 200 | WETH   | cbADA |   310K | lazySync |   30     | 1 hour |  12   |
            [60]  0x098A4dE96305baFAEA0c0ce07CF6456e2c64982a | 20000| 200 | WETH   | HOME  |   250K | lazySync |   30     | 1 hour |  12   |
            [61]  0xfb338cb462c9e44cAE9f442fEb09e8E904fFed47 | 20000| 200 | WETH   | cbDOGE|   300K | lazySync |   30     | 1 hour |  12   |
            [62]  0x1807af3897aA6419E770D4642dF7B8b06E542C02 | 20000| 100 | WETH   | Anon  |    30K | lazySync |   30     | 1 hour |  12   |
            [63]  0xA6da283cf7D06b2279626E787c329d6aCF7e2994 | 10000| 2000| WETH   | cbXRP |   400K | lazySync |   30     | 1 hour |  12   |
            [64]  0xE2B3aA806e56603a244bFc111c9474F7DeDD03db | 20000| 200 | MAMO   | cbBTC |   800K | lazySync |   30     | 1 hour |  12   |
            [65]  0x2A36148a416cBa81699B555120Bd65f4682BDFD2 | 20000| 200 | GAME   | WETH  |   100K | lazySync |   30     | 1 hour |  12   |
            [66]  0xe077DdFb9E9d9403A8eC42D3023D17e8417ee399 | 20000| 200 | GIZA   | USDC  |   400K | lazySync |   30     | 1 hour |  12   |
            [67]  0xA33f162da19C7273BA1205BFD9D4340dA2446E3a | 4000 | 200 | tBTC   | WETH  |   100K | lazySync |   30     | 1 hour |  12   |
            [68]  0x200681425b0C8D78C6a467512C5D49FA56BaC88A | 20000| 200 | WETH   | cbLTC |   150K | lazySync |   30     | 1 hour |  12   |
            ---------------------------------------------------------------------------------------------------|
        */
        uint256 ID = 0;
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
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 10; // 1% of position
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [1]   0x861A2922bE165a5Bd41b1E482B49216b465e1B5F |  200 |   1 |  weth  |  wsteth|  500k |  tamper  |
        poolDeployParams[ID].pool = ICLPool(0x861A2922bE165a5Bd41b1E482B49216b465e1B5F);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 200;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_WSTETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 1; // 1% of position
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
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 1; // 1% of position
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
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 10; // 1% of position
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //---------------------------------------------------------------------------------------
        //---------------------------------------------------------------------------------------
        //    [4]   0x82321f3BEB69f503380D6B233857d5C43562e2D0 | 19200| 200 |  weth  |  aero  | 1000k | lazySync |   30     | 1 hour | 192   |
        poolDeployParams[ID].pool = ICLPool(0x82321f3BEB69f503380D6B233857d5C43562e2D0);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 19200;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AERO_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 192; // 1% of position
        _setInitialAndLimitSupply(1000000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [5]   0x47cA96Ea59C13F72745928887f84C9F52C3D7348 |  128 |   1 |  cbETH |  weth  | 1000k |  tamper  |   30     | 1 hour |   5   |
        poolDeployParams[ID].pool = ICLPool(0x47cA96Ea59C13F72745928887f84C9F52C3D7348);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 128;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 5; // 1% of position
        _setInitialAndLimitSupply(1000000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [6]   0x4e962BB3889Bf030368F56810A9c96B83CB3E778 |  800 | 100 |  usdc  | cbbtc  | 1000k | lazySync |   30     | 1 hour |   8   |
        poolDeployParams[ID].pool = ICLPool(0x4e962BB3889Bf030368F56810A9c96B83CB3E778);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 800;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 8; // 1% of position
        _setInitialAndLimitSupply(1000000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [7]   0xa41Bc0AFfbA7Fd420d186b84899d7ab2aC57fcD1 |   12 |   1 |  usdc  |  usdt  |  500k |  tamper  |   30     | 1 hour |   1   |
        poolDeployParams[ID].pool = ICLPool(0xa41Bc0AFfbA7Fd420d186b84899d7ab2aC57fcD1);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 1; // 1% of position
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [8]   0x0225Ba893D5f8Ecd6d2022f9dEC59b34F61098A1 | 9600 | 200 |  weth  |  usol  |  500k | lazySync |   30     | 1 hour |  96   |
        poolDeployParams[ID].pool = ICLPool(0x0225Ba893D5f8Ecd6d2022f9dEC59b34F61098A1);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 9600;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_USOL_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 96; // 1% of position
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [9]   0xC200F21EfE67c7F41B81A854c26F9cdA80593065 | 20800| 200 |  virt  |  weth  | 1000k | lazySync |   30     | 1 hour | 208   |
        poolDeployParams[ID].pool = ICLPool(0xC200F21EfE67c7F41B81A854c26F9cdA80593065);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20800;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_VIRT_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 208; // 1% of position
        _setInitialAndLimitSupply(1000000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [10]  0x22A52bB644f855ebD5ca2edB643FF70222D70C31 | 20800| 200 |  weth  |  aixbt |  500k | lazySync |   30     | 1 hour | 208   |
        poolDeployParams[ID].pool = ICLPool(0x22A52bB644f855ebD5ca2edB643FF70222D70C31);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20800;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AIXBT_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 208; // 1% of position
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [11]  0x7eC6C9D993D9832Aa654593f2Dbc21303650Bc6c | 20800| 200 |  weth  |   vvv  |  500k | lazySync |   30     | 1 hour | 208   |
        poolDeployParams[ID].pool = ICLPool(0x7eC6C9D993D9832Aa654593f2Dbc21303650Bc6c);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20800;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_VVV_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 208; // 1% of position
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [12]  0x4d9199269D4F89a367965e90d07D6F4AF7750eD0 | 6000 | 100 | cbBTC  |  OETHb |   60k | lazySync |   30     | 1 hour |  60   |
        poolDeployParams[ID].pool = ICLPool(0x4d9199269D4F89a367965e90d07D6F4AF7750eD0);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(60000, poolDeployParams[ID], contracts);
        ID++;
        //    [13]  0x3f0296BF652e19bca772EC3dF08b32732F93014A | 20000| 100 |  virt  |  weth  |   80k | lazySync |   30     | 1 hour | 200   |
        poolDeployParams[ID].pool = ICLPool(0x3f0296BF652e19bca772EC3dF08b32732F93014A);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_VIRT_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 200; // 1% of position
        _setInitialAndLimitSupply(80000, poolDeployParams[ID], contracts);
        ID++;
        //    [14]  0x56b92E5B391DbFb8b8028AC95A4b97f52ffEB416 | 20000| 100 |  weth  | KAITO  |  300k | lazySync |   30     | 1 hour | 200   |
        poolDeployParams[ID].pool = ICLPool(0x56b92E5B391DbFb8b8028AC95A4b97f52ffEB416);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_KAITO_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 200; // 1% of position
        _setInitialAndLimitSupply(300000, poolDeployParams[ID], contracts);
        ID++;
        //    [15]  0x93617b2909a7c207E4180dE0E667ea80c9BdfE9e | 6000 | 100 | oUSDT  |  weth  |  100k | lazySync |   30     | 1 hour |  60   |
        poolDeployParams[ID].pool = ICLPool(0x93617b2909a7c207E4180dE0E667ea80c9BdfE9e);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //    [16]  0xE846373C1a92B167b4E9cd5d8E4d6B1Db9E90EC7 | 1000 |  50 |  EURC  | USDC  |  2800k |  tamper  |   30     | 1 hour |  60   |
        poolDeployParams[ID].pool = ICLPool(0xE846373C1a92B167b4E9cd5d8E4d6B1Db9E90EC7);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 1000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_EUR_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 10; // 1% of position
        _setInitialAndLimitSupply(2800000, poolDeployParams[ID], contracts);
        ID++;
        //    [17]  0xbD3cd0D9d429b41F0a2e1C026552Bd598294d5E0 |  128 |   1 |  weETH | WETH  |   480k |  tamper  |   30     | 1 hour |  60   |
        poolDeployParams[ID].pool = ICLPool(0xbD3cd0D9d429b41F0a2e1C026552Bd598294d5E0);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 128;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_WEETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(480000, poolDeployParams[ID], contracts);
        ID++;
        //    [18]  0x4e829F8A5213c42535AB84AA40BD4aDCCE9cBa02 | 20000| 200 |  WETH  | BRETT |  1400k | lazySync |   30     | 1 hour |  60   |
        poolDeployParams[ID].pool = ICLPool(0x4e829F8A5213c42535AB84AA40BD4aDCCE9cBa02);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BRETT_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 200; // 1% of position
        _setInitialAndLimitSupply(1400000, poolDeployParams[ID], contracts);
        ID++;
        //    [19]  0x9785eF59E2b499fB741674ecf6fAF912Df7b3C1b | 5000 | 100 |  WETH  |  USDT |   280k | lazySync |   30     | 1 hour |  60   |
        poolDeployParams[ID].pool = ICLPool(0x9785eF59E2b499fB741674ecf6fAF912Df7b3C1b);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 5000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 50; // 1% of position
        _setInitialAndLimitSupply(280000, poolDeployParams[ID], contracts);
        ID++;
        //    [20]  0xaFB62448929664Bfccb0aAe22f232520e765bA88 | 20000 | 200 |  WETH  | DEGEN |    80k | lazySync |   30     | 1 hour |  60   |
        poolDeployParams[ID].pool = ICLPool(0xaFB62448929664Bfccb0aAe22f232520e765bA88);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_DEGEN_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 200; // 1% of position
        _setInitialAndLimitSupply(80000, poolDeployParams[ID], contracts);
        ID++;
        //    [21]  0xCDD442e2De893c07146B2F1072f8e077559f9aa4 | 20000 | 200 |  BNKR  |  WETH |    30k | lazySync |   30     | 1 hour |  60   |
        poolDeployParams[ID].pool = ICLPool(0xCDD442e2De893c07146B2F1072f8e077559f9aa4);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_BNKR_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 200; // 1% of position
        _setInitialAndLimitSupply(30000, poolDeployParams[ID], contracts);
        ID++;
        //    [22]  0xB5F0b4aE66C14F7EFaA9aA1468E8FC536A3E288c | 20000| 200 |  WETH  | MORPHO|  1200k | lazySync |   30     | 1 hour |  60   |
        poolDeployParams[ID].pool = ICLPool(0xB5F0b4aE66C14F7EFaA9aA1468E8FC536A3E288c);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_MORPHO_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 200; // 1% of position
        _setInitialAndLimitSupply(1200000, poolDeployParams[ID], contracts);
        ID++;
        //    [23]  0x7501bc8Bb51616F79bfA524E464fb7B41f0B10fB |  100 |  50 | msUSD  |  USDC |  1200k |  tamper  |   30     | 1 hour |  60   |
        poolDeployParams[ID].pool = ICLPool(0x7501bc8Bb51616F79bfA524E464fb7B41f0B10fB);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 100;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_18;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(1200000, poolDeployParams[ID], contracts);
        ID++;
        //    [24]  0x74E4c08Bb50619b70550733D32b7e60424E9628e | 20000| 200 | WETH   | TOSHI |    80k | lazySync |   30     | 1 hour |  60   |
        poolDeployParams[ID].pool = ICLPool(0x74E4c08Bb50619b70550733D32b7e60424E9628e);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_TOSHI_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 200; // 1% of position
        _setInitialAndLimitSupply(80000, poolDeployParams[ID], contracts);
        ID++;
        //    [25]  0xB099C658e784b41EE435d48a8eb67e8f27285C93 | 20000| 100 | WETH   |   B3  |  1000k | lazySync |   30     | 1 hour |  60   |
        poolDeployParams[ID].pool = ICLPool(0xB099C658e784b41EE435d48a8eb67e8f27285C93);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_B3_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 200; // 1% of position
        _setInitialAndLimitSupply(1000000, poolDeployParams[ID], contracts);
        ID++;
        //    [26]  0x5C45b0F48c326f79b56709d8F63CE2beE7697106 | 10000| 200 | WETH   |  uSUI |   535k | lazySync |   30     | 1 hour |  60   |
        poolDeployParams[ID].pool = ICLPool(0x5C45b0F48c326f79b56709d8F63CE2beE7697106);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 10000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_uSUI_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(535000, poolDeployParams[ID], contracts);
        ID++;
        //    [27]  0x61C6e9E93592e535Efc1BEE07f491A517e98f6d0 | 10000| 200 | uXRP   |  WETH |   205k | lazySync |   30     | 1 hour |  60   |
        poolDeployParams[ID].pool = ICLPool(0x61C6e9E93592e535Efc1BEE07f491A517e98f6d0);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 10000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_uXRP_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(205000, poolDeployParams[ID], contracts);
        ID++;
        //    [28]  0xC900eA56B5227aE2d95c288a2597B278Cbf741dd | 10000| 200 | uSOL   | cbBTC |   155k | lazySync |   30     | 1 hour |  60   |
        poolDeployParams[ID].pool = ICLPool(0xC900eA56B5227aE2d95c288a2597B278Cbf741dd);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 10000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_uSOL_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(155000, poolDeployParams[ID], contracts);
        ID++;

        //    [29]  0x3f53f1Fd5b7723DDf38D93a584D280B9b94C3111 | 19200| 100 | ZORA   | USDC  |   189k | lazySync |   30     | 1 hour |  100  |
        poolDeployParams[ID].pool = ICLPool(0x3f53f1Fd5b7723DDf38D93a584D280B9b94C3111);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 19200;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ZORA_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 192; // 1% of position
        _setInitialAndLimitSupply(189000, poolDeployParams[ID], contracts);
        ID++;
        //    [30]  0xdFe5F275020def30993f042174Fc2D335678b626 | 19200| 200 | AERO   | cbBTC |   369k | lazySync |   30     | 1 hour |  100  |
        poolDeployParams[ID].pool = ICLPool(0xdFe5F275020def30993f042174Fc2D335678b626);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 19200;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AERO_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 192; // 1% of position
        _setInitialAndLimitSupply(369000, poolDeployParams[ID], contracts);
        ID++;
        //    [31]  0x41D60eD9C8327EA0c6b16a44343c177E0402FeeA | 19200| 100 | PROMPT | cbBTC |   141k | lazySync |   30     | 1 hour |  100  |
        poolDeployParams[ID].pool = ICLPool(0x41D60eD9C8327EA0c6b16a44343c177E0402FeeA);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 19200;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_PROMPT_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 192; // 1% of position
        _setInitialAndLimitSupply(141000, poolDeployParams[ID], contracts);
        ID++;
        //    [32]  0x3e66e55e97ce60096f74b7C475e8249f2D31a9fb | 8000 | 2000| USDC   | cbBTC |  1000k | lazySync |   30     | 1 hour |  100  |
        poolDeployParams[ID].pool = ICLPool(0x3e66e55e97ce60096f74b7C475e8249f2D31a9fb);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 8000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 80; // 1% of position
        _setInitialAndLimitSupply(1000000, poolDeployParams[ID], contracts);
        ID++;
        //    [33]  0x5d4e504EB4c526995E0cC7A6E327FDa75D8B52b5 | 6400 | 100 | WETH   | EURC  |  540k  | lazySync |   30     | 1 hour |  100  |
        poolDeployParams[ID].pool = ICLPool(0x5d4e504EB4c526995E0cC7A6E327FDa75D8B52b5);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6400;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_EUR_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 64; // 1% of position
        _setInitialAndLimitSupply(540000, poolDeployParams[ID], contracts);
        ID++;
        //    [34]  0x4a79B0168296c0eF7b8F314973B82aD406a29f1B | 10000| 200 | WETH   | AAVE  |  1000k | lazySync |   30     | 1 hour |  100  |
        poolDeployParams[ID].pool = ICLPool(0x4a79B0168296c0eF7b8F314973B82aD406a29f1B);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 10000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AAVE_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(1000000, poolDeployParams[ID], contracts);
        ID++;

        //    [35]  0x138aceE5573fA09e7F215965ff60898cc33c6330 |  128 |   1 |  tBTC  | cbBTC |  1000k |  tamper  |   30     | 1 hour |   2   |
        poolDeployParams[ID].pool = ICLPool(0x138aceE5573fA09e7F215965ff60898cc33c6330);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 128;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_BTC_AMOUNT_18;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(1000000, poolDeployParams[ID], contracts);
        ID++;
        //    [36]  0xA44D3Bb767d953711EA4Bce8C0F01f4d7D299aF6 |  128 |   1 |  cbBTC |  LBTC |  1000k |  tamper  |   30     | 1 hour |   2   |
        poolDeployParams[ID].pool = ICLPool(0xA44D3Bb767d953711EA4Bce8C0F01f4d7D299aF6);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 128;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(1000000, poolDeployParams[ID], contracts);
        ID++;

        //    [37]  0x088c39ee29fC30DF8Adc394e9f7dEa33E3A26507 | 19200| 200 | WETH   |doginme|   100k | lazySync |   30     | 1 hour |  100  |
        poolDeployParams[ID].pool = ICLPool(0x088c39ee29fC30DF8Adc394e9f7dEa33E3A26507);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 19200;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_DOG_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 192; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //    [38]  0x2DB199a5D0EffAe36236E13FDb62aa43Eb3e14eC | 19200| 200 | USDC   | KLIMA |    10k | lazySync |   30     | 1 hour |  100  |
        poolDeployParams[ID].pool = ICLPool(0x2DB199a5D0EffAe36236E13FDb62aa43Eb3e14eC);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 19200;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_KLIMA_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 192; // 1% of position
        _setInitialAndLimitSupply(10000, poolDeployParams[ID], contracts);
        ID++;
        //    [39]  0xEa5cb64754Ad7aA24F7A6BBe3b724F29B4f822B8 | 19200| 200 | USDC   | RIZE  |   180k | lazySync |   30     | 1 hour |  100  |
        poolDeployParams[ID].pool = ICLPool(0xEa5cb64754Ad7aA24F7A6BBe3b724F29B4f822B8);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 19200;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_RIZE_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 192; // 1% of position
        _setInitialAndLimitSupply(180000, poolDeployParams[ID], contracts);
        ID++;
        //    [40]  0xE8833415Bd6Aee9c0c7B6aaD7DC80421C3F28ca1 | 19200| 200 | USDC   | COOKIE|   200k | lazySync |   30     | 1 hour |  100  |
        poolDeployParams[ID].pool = ICLPool(0xE8833415Bd6Aee9c0c7B6aaD7DC80421C3F28ca1);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 19200;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_COOKIE_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 192; // 1% of position
        _setInitialAndLimitSupply(200000, poolDeployParams[ID], contracts);
        ID++;
        //    [41]  0x4D69971CCd4A636c403a3C1B00c85e99bB9B5606 | 6400 | 100 | WETH   |  USD+ |   300k | lazySync |   30     | 1 hour |  100  |
        poolDeployParams[ID].pool = ICLPool(0x4D69971CCd4A636c403a3C1B00c85e99bB9B5606);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6400;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 64; // 1% of position
        _setInitialAndLimitSupply(300000, poolDeployParams[ID], contracts);
        ID++;
        //    [42]  0x04f8375dAd560480D6639B9600CD88ca594E2293 |   48 |   1 | WETH   | LsETH |  2500k | lazyDesc |   30     | 1 hour |    2  |
        poolDeployParams[ID].pool = ICLPool(0x04f8375dAd560480D6639B9600CD88ca594E2293);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazyDescending;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 48;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_LSETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(2500000, poolDeployParams[ID], contracts);
        ID++;
        //    [43]  0x2ae9DF02539887d4EbcE0230168a302d34784c82 |   48 |   1 | WETH   |bsdETH |   800k | lazyDesc |   30     | 1 hour |    2  |
        poolDeployParams[ID].pool = ICLPool(0x2ae9DF02539887d4EbcE0230168a302d34784c82);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazyDescending;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 48;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BSDETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(800000, poolDeployParams[ID], contracts);
        ID++;
        //    [44]  0x576607EC0eA744c38124B3C12fD894f97b67143e |  200 |  50 |  USR   | wstUSR|    50k |  tamper  |   30     | 1 hour |  2   |
        poolDeployParams[ID].pool = ICLPool(0x576607EC0eA744c38124B3C12fD894f97b67143e);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 200;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_18;
        poolDeployParams[ID].maxAmount1 = ONE_USD_wstUSR_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT * 10;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(50000, poolDeployParams[ID], contracts);
        ID++;
        //    [45]  0xf4D5f114d029657Bd55511b359d2A0Ad73620d17 |  200 |  50 |  USR   |    RLP|    50k |  tamper  |   30     | 1 hour |  2   |
        poolDeployParams[ID].pool = ICLPool(0xf4D5f114d029657Bd55511b359d2A0Ad73620d17);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 200;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_18;
        poolDeployParams[ID].maxAmount1 = ONE_USD_RLP_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT * 10;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(50000, poolDeployParams[ID], contracts);
        ID++;
        //    [46]  0x51c230951b82Dbf7b8696B6fCd2be199cC10779f | 10000| 100 |  RFL   |   USDC|    25k | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0x51c230951b82Dbf7b8696B6fCd2be199cC10779f);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 10000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_RFL_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(25000, poolDeployParams[ID], contracts);
        ID++;

        //    [47]  0x46D710c35BdfB800a18A820712310048Ef8B5256 | 20000| 200 |  WETH  |  KTA  |   350K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0x46D710c35BdfB800a18A820712310048Ef8B5256);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token1()).decimals() + 6) / KTA_USD_PRICE_D6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(350000, poolDeployParams[ID], contracts);
        ID++;
        //    [48]  0xBE00fF35AF70E8415D0eB605a286D8A45466A4c1 | 20000| 2000|  USDC  | AERO  |   1.5M | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0xBE00fF35AF70E8415D0eB605a286D8A45466A4c1);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AERO_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(1500000, poolDeployParams[ID], contracts);
        ID++;
        //    [49]  0x4BA1e3E9280facbAcaFA7baF4aE0b78Bea60beCa | 20000| 200 |  WETH  |  SPX  |   400K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0x4BA1e3E9280facbAcaFA7baF4aE0b78Bea60beCa);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token1()).decimals() + 6) / SPX_USD_PRICE_D6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(400000, poolDeployParams[ID], contracts);
        ID++;
        //    [50]  0xd23FE2DB317e1A96454a2D1c7e8fc0DbF19BB000 | 20000| 200 | CLANKER| WETH  |   100K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0xd23FE2DB317e1A96454a2D1c7e8fc0DbF19BB000);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token0()).decimals() + 6)
            / CLANKER_USD_PRICE_D6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //    [51]  0x4A021bA3ab1F0121e7DF76f345C547db86Cb3468 | 20000| 200 | VIRTUAL| MAMO  |   1.0M | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0x4A021bA3ab1F0121e7DF76f345C547db86Cb3468);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_VIRT_AMOUNT;
        poolDeployParams[ID].maxAmount1 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token1()).decimals() + 6) / MAMO_USD_PRICE_D6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(1000000, poolDeployParams[ID], contracts);
        ID++;
        //    [52]  0x95Ff4985af7ED78421215be100c18a2b987f7E90 | 10000| 100 | cbXRP  |cbBTC  |   650K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0x95Ff4985af7ED78421215be100c18a2b987f7E90);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 10000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token0()).decimals() + 6) / cbXRP_USD_PRICE_D6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(650000, poolDeployParams[ID], contracts);
        ID++;
        //    [53]  0x363d1607b8DA83d6B6EA76D017CeEcf1316BB08A | 20000| 100 | cbBTC  |cbDOGE |   253K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0x363d1607b8DA83d6B6EA76D017CeEcf1316BB08A);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].maxAmount1 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token1()).decimals() + 6) / cbDOGE_USD_PRICE_D6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(253000, poolDeployParams[ID], contracts);
        ID++;
        //    [54]  0x8782d97C8b25B4d17dBFbaa03f25dC18e51e909D | 20000| 100 | cbADA  |cbBTC  |    30K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0x8782d97C8b25B4d17dBFbaa03f25dC18e51e909D);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token0()).decimals() + 6) / cbADA_USD_PRICE_D6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(30000, poolDeployParams[ID], contracts);
        ID++;
        //    [55]  0x6044c817e55A03DAdc5F6b8B7045aF1985aE90fA | 20000| 100 | cbLTC  |cbBTC  |   250K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0x6044c817e55A03DAdc5F6b8B7045aF1985aE90fA);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token0()).decimals() + 6) / cbLTC_USD_PRICE_D6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(250000, poolDeployParams[ID], contracts);
        ID++;
        //    [56]  0x54cdD0222dF6B3BC17754c2C1B3d7D4203FE3d89 | 20000| 200 | WETH   | REI   |    80K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0x54cdD0222dF6B3BC17754c2C1B3d7D4203FE3d89);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token1()).decimals() + 6) / REI_USD_PRICE_D6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(80000, poolDeployParams[ID], contracts);
        ID++;
        //    [57]  0x3Ba9ce0f19cF3CcB631b973c83712C7E6E9585ae | 20000| 200 | WETH   | WELL  |   250K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0x3Ba9ce0f19cF3CcB631b973c83712C7E6E9585ae);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token1()).decimals() + 6) / WELL_USD_PRICE_D6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(250000, poolDeployParams[ID], contracts);
        ID++;
        //    [58]  0x68a5aEA4DE3D938a755D85d1868Fe79A9C7B6ae1 | 20000| 100 | WETH   | DEGEN |   200K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0x68a5aEA4DE3D938a755D85d1868Fe79A9C7B6ae1);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token1()).decimals() + 6) / DEGEN_USD_PRICE_D6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(200000, poolDeployParams[ID], contracts);
        ID++;
        //    [59]  0xb862F23ba38c8C65e256782B31E8C08C9aefd612 | 20000| 200 | WETH   | cbADA |   310K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0xb862F23ba38c8C65e256782B31E8C08C9aefd612);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token1()).decimals() + 6) / cbADA_USD_PRICE_D6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(310000, poolDeployParams[ID], contracts);
        ID++;
        //    [60]  0x098A4dE96305baFAEA0c0ce07CF6456e2c64982a | 20000| 200 | WETH   | HOME  |   250K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0x098A4dE96305baFAEA0c0ce07CF6456e2c64982a);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token1()).decimals() + 6) / HOME_USD_PRICE_D6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(250000, poolDeployParams[ID], contracts);
        ID++;
        //    [61]  0xfb338cb462c9e44cAE9f442fEb09e8E904fFed47 | 20000| 200 | WETH   | cbDOGE|   300K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0xfb338cb462c9e44cAE9f442fEb09e8E904fFed47);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token1()).decimals() + 6) / cbDOGE_USD_PRICE_D6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(300000, poolDeployParams[ID], contracts);
        ID++;
        //    [62]  0x1807af3897aA6419E770D4642dF7B8b06E542C02 | 20000| 100 | WETH   | Anon  |    30K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0x1807af3897aA6419E770D4642dF7B8b06E542C02);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token1()).decimals() + 6) / Anon_USD_PRICE_D6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(30000, poolDeployParams[ID], contracts);
        ID++;
        //    [63]  0xA6da283cf7D06b2279626E787c329d6aCF7e2994 | 10000| 2000| WETH   | cbXRP |   400K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0xA6da283cf7D06b2279626E787c329d6aCF7e2994);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 10000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token1()).decimals() + 6) / cbXRP_USD_PRICE_D6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(400000, poolDeployParams[ID], contracts);
        ID++;
        //    [64]  0xE2B3aA806e56603a244bFc111c9474F7DeDD03db | 20000| 200 | MAMO   | cbBTC |   800K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0xE2B3aA806e56603a244bFc111c9474F7DeDD03db);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token0()).decimals() + 6) / MAMO_USD_PRICE_D6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(800000, poolDeployParams[ID], contracts);
        ID++;
        //    [65]  0x2A36148a416cBa81699B555120Bd65f4682BDFD2 | 20000| 200 | GAME   | WETH  |   100K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0x2A36148a416cBa81699B555120Bd65f4682BDFD2);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token0()).decimals() + 6) / GAME_USD_PRICE_D6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //    [66]  0xe077DdFb9E9d9403A8eC42D3023D17e8417ee399 | 20000| 200 | GIZA   | USDC  |   400K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0xe077DdFb9E9d9403A8eC42D3023D17e8417ee399);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token0()).decimals() + 6) / GIZA_USD_PRICE_D6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(400000, poolDeployParams[ID], contracts);
        ID++;
        //    [67]  0xA33f162da19C7273BA1205BFD9D4340dA2446E3a | 4000 | 200 | tBTC   | WETH  |   100K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0xA33f162da19C7273BA1205BFD9D4340dA2446E3a);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 4000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 40; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //    [68]  0x200681425b0C8D78C6a467512C5D49FA56BaC88A | 20000| 200 | WETH   | cbLTC |   150K | lazySync |   30     | 1 hour |  12   |
        poolDeployParams[ID].pool = ICLPool(0x200681425b0C8D78C6a467512C5D49FA56BaC88A);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 20000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = 10
            ** (IERC20Metadata(poolDeployParams[ID].pool.token1()).decimals() + 6) / cbLTC_USD_PRICE_D6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 100; // 1% of position
        _setInitialAndLimitSupply(150000, poolDeployParams[ID], contracts);
        ID++;
    }

    function _soneiumPoolDeployParams(CoreDeployment memory contracts)
        internal
        view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        poolDeployParams = new IVeloDeployFactory.DeployParams[](11);
        /*
            [0]   0x5441c4c5cc00D33bd9409F742D511Ee01db1667B | 8000 | 100 |  weth  |  usdce | 200k | lazySync |   30     | 1 hour | 80    |
            [1]   0xB44795454376C7127f89B1cC0d56F403E70CA952 | 12000|  50 |  astr  |  weth  | 200k | lazySync |   30     | 1 hour | 120   |
            [2]   0x3844fDD68fD40319f977e9d8f15e7f5d61131ec2 |   12 |   1 |  usdt  |  usdce | 100k | tamper   |   30     | 1 hour | 1     |
            [3]   0xb86BA674b07d3a3e399BAf58B322dD7c35B7c4ab | 8000 | 100 |  usdt  |  weth  | 100k | lazySync |   30     | 1 hour | 80    |
            [4]   0xc2026f3fb6fc51F4EcAE40a88b4509cB6C143ed4 | 12000| 200 |  weth  |  xvelo | 100k | lazySync |   30     | 1 hour | 120   |

            [5]   0x0030f9872caAC56c1E81f699F58991718d6beE04 |   12 |   1 |  USDT0 | USDC.e | 1100k| tamper   |   30     | 1 hour | 120   |
            [6]   0x378fBADc44055075Cc190091a9E890baDF848A52 | 8000 | 100 |  USDT0 |  WETH  | 245k | lazySync |   30     | 1 hour | 120   |

            [7]   0xC6b8E3559feb231d7769c12872FFBE95c3E20Ff7 | 4000 |  50 |  WBTC  |  WETH  | 245k | lazySync |   30     | 1 hour | 120   |
            [8]   0xe424d12BEFA0466AAbEF82CB401534339ff2E838 |   12 |   1 |  oUSDT | USDC.e | 245k |  tamper  |   30     | 1 hour | 120   |
            [9]   0xb45A46AAC62E4C5C31D63ecB5C1BE7b12f7a8d57 |   12 |   1 |  USR   | USDC.e | 100k |  tamper  |   30     | 1 hour | 120   |
            [10]  0x21b3D5D4701A8A56EED9b28e4fefc3902Cc6039C |  200 |  50 | wstUSR |  USR   |  40k |  tamper  |   30     | 1 hour | 120   |
        */
        uint256 ID = 0;

        //---------------------------------------------------------------------------------------
        //    [0]   0x5441c4c5cc00D33bd9409F742D511Ee01db1667B | 8000 | 100 |  weth  |  usdce | 200k | lazySync |   30     | 1 hour | 80    |
        poolDeployParams[ID].pool = ICLPool(0x5441c4c5cc00D33bd9409F742D511Ee01db1667B);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 8000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 80; // 1% of position
        _setInitialAndLimitSupply(200000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [1]   0xB44795454376C7127f89B1cC0d56F403E70CA952 | 12000|  50 |  astr  |  weth  | 200k | lazySync |   30     | 1 hour | 120   |
        poolDeployParams[ID].pool = ICLPool(0xB44795454376C7127f89B1cC0d56F403E70CA952);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ASTR_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 120; // 1% of position
        _setInitialAndLimitSupply(200000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [2]   0x3844fDD68fD40319f977e9d8f15e7f5d61131ec2 |   12 |   1 |  usdt  |  usdce | 100k | tamper   |   30     | 1 hour | 1     |
        poolDeployParams[ID].pool = ICLPool(0x3844fDD68fD40319f977e9d8f15e7f5d61131ec2);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 1; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [3]   0xb86BA674b07d3a3e399BAf58B322dD7c35B7c4ab | 8000 | 100 |  usdt  |  weth  | 100k | lazySync |   30     | 1 hour | 80    |
        poolDeployParams[ID].pool = ICLPool(0xb86BA674b07d3a3e399BAf58B322dD7c35B7c4ab);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 8000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 80; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [4]   0xc2026f3fb6fc51F4EcAE40a88b4509cB6C143ed4 | 12000| 200 |  weth  |  xvelo | 100k | lazySync |   30     | 1 hour | 120   |
        poolDeployParams[ID].pool = ICLPool(0xc2026f3fb6fc51F4EcAE40a88b4509cB6C143ed4);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_VELO_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 120; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [5]   0x0030f9872caAC56c1E81f699F58991718d6beE04 |   12 |   1 |  USDT0 | USDC.e | 1100k| tamper   |   30     | 1 hour | 120   |
        poolDeployParams[ID].pool = ICLPool(0x0030f9872caAC56c1E81f699F58991718d6beE04);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 1; // 1% of position
        _setInitialAndLimitSupply(1100000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [6]   0x378fBADc44055075Cc190091a9E890baDF848A52 | 8000 | 100 |  USDT0 |  WETH  | 245k | lazySync |   30     | 1 hour | 120   |
        poolDeployParams[ID].pool = ICLPool(0x378fBADc44055075Cc190091a9E890baDF848A52);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 8000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 120; // 1% of position
        _setInitialAndLimitSupply(245000, poolDeployParams[ID], contracts);
        ID++;

        //    [7]   0xC6b8E3559feb231d7769c12872FFBE95c3E20Ff7 | 4000 |  50 |  WBTC  |  WETH  |  60k | lazySync |   30     | 1 hour | 120   |
        poolDeployParams[ID].pool = ICLPool(0xC6b8E3559feb231d7769c12872FFBE95c3E20Ff7);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 4000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = _oneUSDAmount(poolDeployParams[ID].pool.token0(), BTC_USD_PRICE_D6);
        poolDeployParams[ID].maxAmount1 = _oneUSDAmount(poolDeployParams[ID].pool.token1(), ETH_USD_PRICE_D6);
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 40; // 1% of position
        _setInitialAndLimitSupply(60000, poolDeployParams[ID], contracts);
        ID++;
        //    [8]   0xe424d12BEFA0466AAbEF82CB401534339ff2E838 |   12 |   1 |  oUSDT | USDC.e | 40k  |  tamper  |   30     | 1 hour | 120   |
        poolDeployParams[ID].pool = ICLPool(0xe424d12BEFA0466AAbEF82CB401534339ff2E838);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 1; // 1% of position
        _setInitialAndLimitSupply(40000, poolDeployParams[ID], contracts);
        ID++;
        //    [9]   0xb45A46AAC62E4C5C31D63ecB5C1BE7b12f7a8d57 |   12 |   1 |  USR   | USDC.e | 100k |  tamper  |   30     | 1 hour | 120   |
        poolDeployParams[ID].pool = ICLPool(0xb45A46AAC62E4C5C31D63ecB5C1BE7b12f7a8d57);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_18;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 1; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //    [10]  0x21b3D5D4701A8A56EED9b28e4fefc3902Cc6039C |  200 |  50 | wstUSR |  USR   |  40k |  tamper  |   30     | 1 hour | 120   |
        poolDeployParams[ID].pool = ICLPool(0x21b3D5D4701A8A56EED9b28e4fefc3902Cc6039C);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 200;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = _oneUSDAmount(poolDeployParams[ID].pool.token0(), wstUSR_USD_PRICE_D6);
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_18;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 3; // 1% of position
        _setInitialAndLimitSupply(40000, poolDeployParams[ID], contracts);
        ID++;
    }

    function _modePoolDeployParams(CoreDeployment memory contracts)
        internal
        view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        poolDeployParams = new IVeloDeployFactory.DeployParams[](4);
        /*
            [0]   0x3Adf15f77F2911f84b0FE9DbdfF43ef60D40012c |   6000 | 100 |  weth  |  usdc  | 100k | lazySync | 30 | 1 hour | 60   |
            [2]   0xc2026f3fb6fc51F4EcAE40a88b4509cB6C143ed4 |  19200 | 100 |  weth  |  xvelo |  15k | lazySync | 30 | 1 hour | 192  |
            [3]   0x9c92aA1d12dE024E219884e133B58895C27d6610 |   24   | 100 |  usdc  |  usdt  |  15k | lazySync | 30 | 1 hour | 1    |
            [1]   0x1E41CDE26b30646bb3DBBea48A63708b00470c1c |  25600 | 100 |  weth  |  mode  |  50k | lazySync | 30 | 1 hour | 250  |
        */
        uint256 ID = 0;

        //---------------------------------------------------------------------------------------
        //    [0]   0x3Adf15f77F2911f84b0FE9DbdfF43ef60D40012c | 6000 | 100 |  weth  |  usdc  | 100k | lazySync |   6000   | 1 hour | 60   |
        poolDeployParams[ID].pool = ICLPool(0x3Adf15f77F2911f84b0FE9DbdfF43ef60D40012c);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [2]   0xc2026f3fb6fc51F4EcAE40a88b4509cB6C143ed4 | 19200 | 100 |  weth  |  xvelo |  15k | lazySync |  19200   | 1 hour | 192  |
        poolDeployParams[ID].pool = ICLPool(0xc2026f3fb6fc51F4EcAE40a88b4509cB6C143ed4);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 19200;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_VELO_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 192; // 1% of position
        _setInitialAndLimitSupply(15000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [3]   0x9c92aA1d12dE024E219884e133B58895C27d6610 | 24 | 100 |  usdc  |  usdt  |  15k | lazySync |   24     | 1 hour | 1    |
        poolDeployParams[ID].pool = ICLPool(0x9c92aA1d12dE024E219884e133B58895C27d6610);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 24;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 1; // 1% of position
        _setInitialAndLimitSupply(15000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [1]   0x1E41CDE26b30646bb3DBBea48A63708b00470c1c | 25600 | 100 |  weth  |  mode  | 50k | lazySync |  25600   | 1 hour | 250  |
        poolDeployParams[ID].pool = ICLPool(0x1E41CDE26b30646bb3DBBea48A63708b00470c1c);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 25600;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_MODE_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 256; // 1% of position
        _setInitialAndLimitSupply(50000, poolDeployParams[ID], contracts);
        ID++;
    }

    function _inkPoolDeployParams(CoreDeployment memory contracts)
        internal
        view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        poolDeployParams = new IVeloDeployFactory.DeployParams[](7);
        /*
            [0]   0x317728bcCE5d1C2895b71b01eEBbB6989ae504aE |    12 |   1 |  usdt  |  usdce  | 100k |  tamper  |  60 | 1 hour | 1   |
            [1]   0x67ce303f24b3841698891Cece349072856B80A9C |  8000 | 100 |  weth  |  usdce  | 100k | lazySync |  60 | 1 hour | 80  |
            [2]   0xaC7fC3e9b9d3377a90650fe62B858fF56bD841C9 |  8000 | 100 |  usdt  |  weth   | 100k | lazySync |  60 | 1 hour | 80  |
            [3]   0xc2026f3fb6fc51F4EcAE40a88b4509cB6C143ed4 | 12000 | 200 |  weth  |  xvelo  |  15k | lazySync |  60 | 1 hour | 120 |

            [4]   0xeDaFd349bDac6bAaefC13d06b3Aa2Db779534656 |  8000 | 100 |  weth  |  kBTC   |  226k | lazySync |  60 | 1 hour | 80 |
            [5]   0xDCF119Db83668e8724474dC05F6507CC7430120f |  8000 | 100 |  USDT0 |  kBTC   |  127k | lazySync |  60 | 1 hour | 80 |
            [6]   0x31826a86cD62c6FA12A0a8441eC4C8BCfeE8A453 |    12 |   1 |  USDT0 |  USDG   |  100k |  tamper  |  60 | 1 hour | 1  |
        */
        uint256 ID = 0;

        //---------------------------------------------------------------------------------------
        //    [1]   0x67ce303f24b3841698891Cece349072856B80A9C |  8000 | 100 |  weth  |  usdce  | 100k | lazySync |  60 | 1 hour | 80  |
        poolDeployParams[ID].pool = ICLPool(0x67ce303f24b3841698891Cece349072856B80A9C);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 8000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 80; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [2]   0xaC7fC3e9b9d3377a90650fe62B858fF56bD841C9 |  8000 | 100 |  usdt  |  weth   | 100k | lazySync |  60 | 1 hour | 80  |
        poolDeployParams[ID].pool = ICLPool(0xaC7fC3e9b9d3377a90650fe62B858fF56bD841C9);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 8000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 80; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [0]   0x317728bcCE5d1C2895b71b01eEBbB6989ae504aE |    12 |   1 |  usdt  |  usdce  | 100k |  tamper  |  60 | 1 hour | 1   |
        poolDeployParams[ID].pool = ICLPool(0x317728bcCE5d1C2895b71b01eEBbB6989ae504aE);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 1;
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [3]   0xc2026f3fb6fc51F4EcAE40a88b4509cB6C143ed4 | 12000 | 200 |  weth  |  xvelo  |  15k | lazySync |  60 | 1 hour | 120 |
        poolDeployParams[ID].pool = ICLPool(0xc2026f3fb6fc51F4EcAE40a88b4509cB6C143ed4);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_VELO_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 120; // 1% of position
        _setInitialAndLimitSupply(15000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [4]   0xeDaFd349bDac6bAaefC13d06b3Aa2Db779534656 |  8000 | 100 |  weth  |  kBTC   |  226k | lazySync |  60 | 1 hour | 80 |
        poolDeployParams[ID].pool = ICLPool(0xeDaFd349bDac6bAaefC13d06b3Aa2Db779534656);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 8000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 80; // 1% of position
        _setInitialAndLimitSupply(226000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [5]   0xDCF119Db83668e8724474dC05F6507CC7430120f |  8000 | 100 |  USDT0 |  kBTC   |  127k | lazySync |  60 | 1 hour |  80 |
        poolDeployParams[ID].pool = ICLPool(0xDCF119Db83668e8724474dC05F6507CC7430120f);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 8000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 80; // 1% of position
        _setInitialAndLimitSupply(127000, poolDeployParams[ID], contracts);
        ID++;
        //    [6]   0x31826a86cD62c6FA12A0a8441eC4C8BCfeE8A453 |    12 |   1 |  USDT0 |  USDG   |  100k |  tamper  |  60 | 1 hour | 1  |
        poolDeployParams[ID].pool = ICLPool(0x31826a86cD62c6FA12A0a8441eC4C8BCfeE8A453);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 1;
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
    }

    function _swellPoolDeployParams(CoreDeployment memory contracts)
        internal
        view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        poolDeployParams = new IVeloDeployFactory.DeployParams[](3);
        /*
            ----------------------------------------------------------------------------------------------------------------------------_--|
                                                     address |  width|  TS |   t0   |    t1  |limit | strategy | lookback | maxAge | delta |
            [0]   0xf495610d64FA6a32C5F968c947028f9C7Cacfb19 |    12 |   1 | rswETH |  weth  | 500k |  tamper  |       30 | 1 hour |   1   |
            [1]   0x818eC3274C43A45Ca588b485794644438a3F4653 |    12 |   1 |   weth | weweth | 500k |  tamper  |       30 | 1 hour |   1   |
            [2]   0xeb5A50af8ab6Bd56C71E1376a1455ad2B6E130Be |    12 |   1 | oUSDT  | USDe   |  30k |  tamper  |       30 | 1 hour |   1   |

        */
        uint256 ID = 0;

        //---------------------------------------------------------------------------------------
        //    [0]   0xf495610d64FA6a32C5F968c947028f9C7Cacfb19 |    12 |   1 | rswETH |  weth  | 500k |  tamper  |       30 | 1 hour |   1   |
        poolDeployParams[ID].pool = ICLPool(0xf495610d64FA6a32C5F968c947028f9C7Cacfb19);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 80; // 1% of position
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
        //---------------------------------------------------------------------------------------
        //    [1]   0x818eC3274C43A45Ca588b485794644438a3F4653 |    12 |   1 |   weth | weweth | 500k |  tamper  |       30 | 1 hour |   1   |
        poolDeployParams[ID].pool = ICLPool(0x818eC3274C43A45Ca588b485794644438a3F4653);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_WEETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(500000, poolDeployParams[ID], contracts);
        ID++;
        //    [2]   0xeb5A50af8ab6Bd56C71E1376a1455ad2B6E130Be |    12 |   1 | oUSDT  | USDe   |  30k |  tamper  |       30 | 1 hour |   1   |
        poolDeployParams[ID].pool = ICLPool(0xeb5A50af8ab6Bd56C71E1376a1455ad2B6E130Be);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_18;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(30000, poolDeployParams[ID], contracts);
        ID++;
    }

    function _uniPoolDeployParams(CoreDeployment memory contracts)
        internal
        view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        poolDeployParams = new IVeloDeployFactory.DeployParams[](6);
        /*
            -------------------------------------------------------------------------------------------------------------------------------|
                                                     address |  width|  TS |   t0   |    t1  |limit | strategy | lookback | maxAge | delta |
            [0]   0x5438e884c621d5db08fA605B53ca04c5B33a623A |  6000 | 100 |  usdc  |  weth  | 150k | lazySync |       60 | 1 hour |   60  |
            [1]   0x31bAfd5D04580F71a808ae646BB787d38e9362f9 |    12 |   1 |  usdc  | USDT0  | 200k |  tamper  |       12 | 1 hour |   1   |
            [2]   0x5c7E1F0dCFA6D4F300C55BaB41f27289c88A202A |    12 |   1 |  USDC  | oUSDT  |  30k |  tamper  |       12 | 1 hour |   1   |

            [3]   0x95A0deC1E4fE633AEA5AD725375071a3a9F24501 |  6000 | 100 |  WETH  | USDT0  | 100k | lazySync |       12 | 1 hour |   1   |
            [4]   0x4DD903018D8e474c38c2daafdb6BDf0F62A40E75 |  6000 | 100 |  WBTC  | USDT0  |  50k | lazySync |       12 | 1 hour |   1   |
            [5]   0xC6b8E3559feb231d7769c12872FFBE95c3E20Ff7 |  4000 |  50 |  WBTC  |  WETH  |  50k | lazySync |       12 | 1 hour |   1   |
        */
        uint256 ID = 0;

        //---------------------------------------------------------------------------------------
        //    [0]   0x5438e884c621d5db08fA605B53ca04c5B33a623A |  6000 | 100 |  usdc  |  weth  | 150k |  lazySync|       60 | 1 hour |   60  |
        poolDeployParams[ID].pool = ICLPool(0x5438e884c621d5db08fA605B53ca04c5B33a623A);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(150000, poolDeployParams[ID], contracts);
        ID++;
        //    [1]   0x31bAfd5D04580F71a808ae646BB787d38e9362f9 |  12 |   1 |  usdc  | USDT0  | 200k |  tamper  |       12 | 1 hour |   1  |
        poolDeployParams[ID].pool = ICLPool(0x31bAfd5D04580F71a808ae646BB787d38e9362f9);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(200000, poolDeployParams[ID], contracts);
        ID++;
        //    [2]   0x5c7E1F0dCFA6D4F300C55BaB41f27289c88A202A |    12 |   1 |  USDC  | oUSDT  |  30k |  tamper  |       12 | 1 hour |   1   |
        poolDeployParams[ID].pool = ICLPool(0x5c7E1F0dCFA6D4F300C55BaB41f27289c88A202A);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(30000, poolDeployParams[ID], contracts);
        ID++;

        //    [3]   0x95A0deC1E4fE633AEA5AD725375071a3a9F24501 |  6000 | 100 |  WETH  | USDT0  | 100k | lazySync |       12 | 1 hour |   1   |
        poolDeployParams[ID].pool = ICLPool(0x95A0deC1E4fE633AEA5AD725375071a3a9F24501);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 =
            _oneUSDAmount(poolDeployParams[ID].pool.token0(), ETH_USD_PRICE_D6);
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //    [4]   0x4DD903018D8e474c38c2daafdb6BDf0F62A40E75 |  6000 | 100 |  WBTC  | USDT0  |  50k | lazySync |       12 | 1 hour |   1   |
        poolDeployParams[ID].pool = ICLPool(0x4DD903018D8e474c38c2daafdb6BDf0F62A40E75);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 =
            _oneUSDAmount(poolDeployParams[ID].pool.token0(), BTC_USD_PRICE_D6);
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(50000, poolDeployParams[ID], contracts);
        ID++;
        //    [5]   0xC6b8E3559feb231d7769c12872FFBE95c3E20Ff7 |  4000 |  50 |  WBTC  |  WETH  |  50k | lazySync |       12 | 1 hour |   1   |
        poolDeployParams[ID].pool = ICLPool(0xC6b8E3559feb231d7769c12872FFBE95c3E20Ff7);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 4000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 =
            _oneUSDAmount(poolDeployParams[ID].pool.token0(), BTC_USD_PRICE_D6);
        poolDeployParams[ID].maxAmount1 =
            _oneUSDAmount(poolDeployParams[ID].pool.token1(), ETH_USD_PRICE_D6);
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(50000, poolDeployParams[ID], contracts);
        ID++;
    }

    function _superPoolDeployParams(CoreDeployment memory contracts)
        internal
        view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        poolDeployParams = new IVeloDeployFactory.DeployParams[](3);
        /*
            -------------------------------------------------------------------------------------------------------------------------------|
                                                     address |  width|  TS |   t0   |    t1  |limit | strategy | lookback | maxAge | delta |
            [0]   0x9e374285AcC74D3963f619760E46AB1AF41672ee |  6000 | 100 |  weth  |  usdc  | 15k  |  lazySync|       60 | 1 hour |   60  |
            [1]   0x269f196191bd454bD6A4802b194091cA22e5f449 |  6000 | 200 |  supr  |  usdc  | 70k  |  tamper  |       60 | 1 hour |   60  |

            [2]   0x42b0012CDB35cC40710fe91658b8039B3280f15d |   12  |   1 |  oUSDT |  usdc  |  80k |  tamper  |       60 | 1 hour |   60  |

        */
        uint256 ID = 0;

        //---------------------------------------------------------------------------------------
        //    [0]   0x9e374285AcC74D3963f619760E46AB1AF41672ee |  6000 | 100 |  weth  |  usdc  | 15k  |  lazySync|       60 | 1 hour |   60  |
        poolDeployParams[ID].pool = ICLPool(0x9e374285AcC74D3963f619760E46AB1AF41672ee);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(15000, poolDeployParams[ID], contracts);
        ID++;
        //    [1]   0x269f196191bd454bD6A4802b194091cA22e5f449 |  6000 | 200 |  supr  |  usdc  | 100k  |  tamper  |       60 | 1 hour |   30  |
        poolDeployParams[ID].pool = ICLPool(0x269f196191bd454bD6A4802b194091cA22e5f449);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000; // [    [3000]    ]
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 15; // 3000/15 = 200 tick = 2.0%, 1% swap
        poolDeployParams[ID].maxAmount0 = ONE_USD_SUPR_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = 60 * 1e5; // 5 * 1e-3 = 0.6%; fee pool is 0.3%, so price impact < 0.3%
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 30; // 0.3% in price
        _setInitialAndLimitSupply(70000, poolDeployParams[ID], contracts);
        ID++;
        //    [2]   0x42b0012CDB35cC40710fe91658b8039B3280f15d |   12  |   1 |  oUSDT |  usdc  |  80k |  tamper  |       60 | 1 hour |   60  |
        poolDeployParams[ID].pool = ICLPool(0x42b0012CDB35cC40710fe91658b8039B3280f15d);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(80000, poolDeployParams[ID], contracts);
        ID++;
    }

    function _celoPoolDeployParams(CoreDeployment memory contracts)
        internal
        view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        poolDeployParams = new IVeloDeployFactory.DeployParams[](5);
        /*
            -------------------------------------------------------------------------------------------------------------------------------|
                                                     address |  width|  TS |   t0   |    t1  |limit | strategy | lookback | maxAge | delta |
            [0]   0xA6A14E6767C07Ffba3786Ac0054A8647Cfdca58D |  6000 | 100 |  usdt  |  weth  | 200k |  lazySync|       60 | 1 hour |   60  |

            [1]   0xe8f84C5DaCC3c308747b953aB84FA47b4859263C |  6000 | 100 |  celo  |  usdt  | 100k |  lazySync|       60 | 1 hour |   60  |
            [2]   0xE16b284Ef941dBfC67f425857c51BB673d9D8A57 |    12 |   1 |  USDT  |  cUSD  |  10k |  tamper  |       60 | 1 hour |   60  |

            [3]   0xe8f84C5DaCC3c308747b953aB84FA47b4859263C |  6000 | 100 |  CELO  |  USDT  |  60k | lazySync |       60 | 1 hour |   60  |
            [4]   0x953f87a2C26344d4A667a640758A1Fa038eEA80E |    12 |   1 |  USDT  |  USDC  |  30k |  tamper  |       60 | 1 hour |   60  |

        */
        uint256 ID = 0;

        //---------------------------------------------------------------------------------------
        //    [0]   0xA6A14E6767C07Ffba3786Ac0054A8647Cfdca58D |  6000 | 100 |  usdt  |  weth  | 200k |  lazySync|       60 | 1 hour |   60  |
        poolDeployParams[ID].pool = ICLPool(0xA6A14E6767C07Ffba3786Ac0054A8647Cfdca58D);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(200000, poolDeployParams[ID], contracts);
        ID++;
        //    [1]   0xe8f84C5DaCC3c308747b953aB84FA47b4859263C |  6000 | 100 |  celo  |  USDT  | 100k |  lazySync|       60 | 1 hour |   60  |
        poolDeployParams[ID].pool = ICLPool(0xe8f84C5DaCC3c308747b953aB84FA47b4859263C);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_CELO_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //    [2]   0xE16b284Ef941dBfC67f425857c51BB673d9D8A57 |    12 |   1 |  USDT  |  cUSD  |  10k |  tamper  |       60 | 1 hour |   60  |
        poolDeployParams[ID].pool = ICLPool(0xE16b284Ef941dBfC67f425857c51BB673d9D8A57);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_18;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(10000, poolDeployParams[ID], contracts);
        ID++;
        //    [3]   0xe8f84C5DaCC3c308747b953aB84FA47b4859263C |  6000 | 100 |  CELO  |  USDT  |  60k | lazySync |       60 | 1 hour |   60  |
        poolDeployParams[ID].pool = ICLPool(0xe8f84C5DaCC3c308747b953aB84FA47b4859263C);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 =
            _oneUSDAmount(poolDeployParams[ID].pool.token0(), CELO_USD_PRICE_D6);
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(60000, poolDeployParams[ID], contracts);
        ID++;
        //    [4]   0x953f87a2C26344d4A667a640758A1Fa038eEA80E |    12 |   1 |  USDT  |  USDC  |  30k |  tamper  |       60 | 1 hour |   60  |
        poolDeployParams[ID].pool = ICLPool(0x953f87a2C26344d4A667a640758A1Fa038eEA80E);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 60; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(30000, poolDeployParams[ID], contracts);
        ID++;
    }

    function _liskPoolDeployParams(CoreDeployment memory contracts)
        internal
        view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        poolDeployParams = new IVeloDeployFactory.DeployParams[](9);
        /*
                -----------------------------------------------------------------------------------------------------------------------------------|
                                                         address |  width |  TS  |   t0   |    t1  |  limit | strategy | lookback | maxAge | delta |
                [0]   0xC859c755E8C0568fD86F7860Bcf9A59D6F57BEB5 |   12   |   1  | USDT0  | USDC.e |  300k  |  tamper  |    30    |   1h   |   2   |
                [1]   0x9C69E0B64A63aA7daA0B5dc61Df3Cc77ea05BcB3 |   48   |   1  | WETH   | wstETH |  200k  | lazyDesc |    30    |   1h   |   2   |
                [2]   0xDC1479FD1Db51cA0079ceCfaA879232e168c8246 |  4000  | 100  | WBTC   | WETH   |  200k  | lazySync |    30    |   1h   |  40   |
                [3]   0xEa1BB3Bd0590ce0B04f701F7C3f2911440d56c70 |   900  |  50  | USDT0  | EURC.e |  100k  |  tamper  |    30    |   1h   |   9   |
                [4]   0x915e897DafFBf232991a9ac1a35240318bF7e65D |  6000  | 100  | WETH   | USDT0  |  300k  | lazySync |    30    |   1h   |  60   |

                [5]   0x18Eb25a15eC48Db3C42A0F41EC0a716Ba6b54514 |    12  |   1  | USDT   | USDC.e |   30k  |  tamper  |    30    |   1h   |  60   |
                [6]   0x5d8D16F7de8637499A730D09A363E2EADaF01Dce |    12  |   1  | oUSDT  | USDT0  |   40k  |  tamper  |    30    |   1h   |  60   |
                [7]   0x0c1a84a52628bF0542e3528f35BdcAAFE22a8b9A |    12  |   1  | USDT   | USDT0  |   10k  |  tamper  |    30    |   1h   |  60   |
                [8]   0xa913882766Af5fFD34E72Bdd646e8E8957Fe1842 |  6000  | 200  | WETH   | LSK    |   60k  | lazySync |    30    |   1h   |  60   |
        */
        uint256 ID = 0;
        //    [0]   0xC859c755E8C0568fD86F7860Bcf9A59D6F57BEB5 |   12   |   1  | USDT0  | USDC.e |  300k  |  tamper  |    30    |   1h   |   2   |
        poolDeployParams[ID].pool = ICLPool(0xC859c755E8C0568fD86F7860Bcf9A59D6F57BEB5);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(300000, poolDeployParams[ID], contracts);
        ID++;
        //    [1]   0x9C69E0B64A63aA7daA0B5dc61Df3Cc77ea05BcB3 |   48   |   1  | WETH   | wstETH |  200k  | lazyDesc |    30    |   1h   |   2   |
        poolDeployParams[ID].pool = ICLPool(0x9C69E0B64A63aA7daA0B5dc61Df3Cc77ea05BcB3);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazyDescending;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 48;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_WSTETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 2; // 1% of position
        _setInitialAndLimitSupply(200000, poolDeployParams[ID], contracts);
        ID++;
        //    [2]   0xDC1479FD1Db51cA0079ceCfaA879232e168c8246 |  4000  | 100  | WBTC   | WETH   |  200k  | lazySync |    30    |   1h   |  40   |
        poolDeployParams[ID].pool = ICLPool(0xDC1479FD1Db51cA0079ceCfaA879232e168c8246);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 4000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_BTC_AMOUNT_8;
        poolDeployParams[ID].maxAmount1 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 40; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(200000, poolDeployParams[ID], contracts);
        ID++;
        //    [3]   0xEa1BB3Bd0590ce0B04f701F7C3f2911440d56c70 |   900  |  50  | USDT0  | EURC.e |  100k  |  tamper  |    30    |   1h   |   9   |
        poolDeployParams[ID].pool = ICLPool(0xEa1BB3Bd0590ce0B04f701F7C3f2911440d56c70);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 900;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_EUR_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 10; // 1% of position
        _setInitialAndLimitSupply(100000, poolDeployParams[ID], contracts);
        ID++;
        //    [4]   0x915e897DafFBf232991a9ac1a35240318bF7e65D |  6000  | 100  | WETH   | USDT0  |  300k  | lazySync |    30    |   1h   |  60   |
        poolDeployParams[ID].pool = ICLPool(0x915e897DafFBf232991a9ac1a35240318bF7e65D);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = ONE_USD_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(300000, poolDeployParams[ID], contracts);
        ID++;

        //        [5]   0x18Eb25a15eC48Db3C42A0F41EC0a716Ba6b54514 |    12  |   1  | USDT   | USDC.e |   30k  |  tamper  |    30    |   1h   |  60   |
        poolDeployParams[ID].pool = ICLPool(0x18Eb25a15eC48Db3C42A0F41EC0a716Ba6b54514);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 10; // 1% of position
        _setInitialAndLimitSupply(30000, poolDeployParams[ID], contracts);
        ID++;
        //        [6]   0x5d8D16F7de8637499A730D09A363E2EADaF01Dce |    12  |   1  | oUSDT  | USDT0  |   40k  |  tamper  |    30    |   1h   |  60   |
        poolDeployParams[ID].pool = ICLPool(0x5d8D16F7de8637499A730D09A363E2EADaF01Dce);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 10; // 1% of position
        _setInitialAndLimitSupply(40000, poolDeployParams[ID], contracts);
        ID++;
        //        [7]   0x0c1a84a52628bF0542e3528f35BdcAAFE22a8b9A |    12  |   1  | USDT   | USDT0  |   10k  |  tamper  |    30    |   1h   |  60   |
        poolDeployParams[ID].pool = ICLPool(0x0c1a84a52628bF0542e3528f35BdcAAFE22a8b9A);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 12;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96 / 20;
        poolDeployParams[ID].maxAmount0 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].maxAmount1 = ONE_USD_AMOUNT_6;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 10; // 1% of position
        _setInitialAndLimitSupply(10000, poolDeployParams[ID], contracts);
        ID++;
        //        [8]   0xa913882766Af5fFD34E72Bdd646e8E8957Fe1842 |  6000  | 200  | WETH   | LSK    |   60k  | lazySync |    30    |   1h   |  60   |
        poolDeployParams[ID].pool = ICLPool(0xa913882766Af5fFD34E72Bdd646e8E8957Fe1842);
        poolDeployParams[ID].strategyParams.strategyType =
            IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickSpacing = poolDeployParams[ID].pool.tickSpacing();
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 =
            MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = _oneUSDAmount(poolDeployParams[ID].pool.token0(), ETH_USD_PRICE_D6);
        poolDeployParams[ID].maxAmount1 = _oneUSDAmount(poolDeployParams[ID].pool.token1(), LSK_USD_PRICE_D6);
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].securityParams.lookback = 30; // ~1min
        poolDeployParams[ID].securityParams.maxAge = 1 hours;
        poolDeployParams[ID].securityParams.maxAllowedDelta = 60; // 1% of position
        _setInitialAndLimitSupply(60000, poolDeployParams[ID], contracts);
        ID++;
    }
}
