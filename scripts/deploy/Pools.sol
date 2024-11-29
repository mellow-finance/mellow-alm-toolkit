// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "src/interfaces/utils/IVeloDeployFactory.sol";

library PoolParameters {
    uint256 constant Q96 = 2 ** 96;
    uint256 constant MAX_USD_AMOUNT = 10 ** 6; // 1 USD
    uint256 constant MAX_SUSD_AMOUNT = 10 ** 18; // 1 USD
    uint256 constant MAX_LUSD_AMOUNT = 10 ** 18; // 1 USD
    uint256 constant MAX_OP_AMOUNT = uint256(10 ** 18); // 1 OP ~ 1.3 USD
    uint256 constant MAX_ETH_AMOUNT = uint256(10 ** 18) / 2500; // 1 ETH/2500 ~ 1 USD
    uint256 constant MAX_BTC_AMOUNT = uint256(10 ** 8) / 50000; // 1 BTC/50000 ~ 1 USD
    uint256 constant TICK_NEIGHBORHOOD_DEFAULT = 0;
    uint256 constant MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT = 0;
    uint32 constant SLIPPAGE_D9_DEFAULT = 5 * 1e5; // 5 * 1e-4 = 0.05%

    function getPoolDeployParams() external view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        if (block.chainid == 10) {
            poolDeployParams = _optimismPoolDeployParams();
        }
        else if (block.chainid == 8453) {
            poolDeployParams = _basePoolDeployParams();
        } else {
            revert("Unsupported chain");
        }

        for (uint256 i = 0; i < poolDeployParams.length; i++) {
            poolDeployParams[i].strategyParams.tickSpacing = poolDeployParams[i].pool.tickSpacing();
        }
    }

    function _optimismPoolDeployParams() internal view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        poolDeployParams = new IVeloDeployFactory.DeployParams[](3);

        IVeloOracle.SecurityParams memory SECURITY_PARAMS_DEFAULT = IVeloOracle.SecurityParams({
            lookback: 1, // Maximum number of historical data points to consider for analysis
            maxAge: 1 hours, // Maximum age of observations to be used in the analysis
            maxAllowedDelta: 10 // Maximum allowed change between data points to be considered valid
        });

        /*
            --------------------------------------------------------------------------------------------------|
                               VELO_FACTORY = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F
            --------------------------------------------------------------------------------------------------|
                                                    address | width|  TS |   t0   |     t1 | status| strategy |
            -------------------------------------------------------------------------------|-------|----------|
            [0]  0xeBD5311beA1948e1441333976EadCFE5fBda777C | 6000 | 200 | usdc   |     op |       |   lazy   |
            [1]  0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60 | 6000 | 200 | weth   |     op |       |   lazy   |
            [2]  0x478946BcD4a5a22b316470F5486fAfb928C0bA25 | 4000 | 100 | usdc   |   weth |   -   |   lazy   |
            [3]  0x319C0DD36284ac24A6b2beE73929f699b9f48c38 | 4000 | 100 | weth   |   wbtc |       |   lazy   |
            [4]  0xEE1baC98527a9fDd57fcCf967817215B083cE1F0 | 4000 | 100 | usdc   | wsteth |       |  tamper  |
            [5]  0xb71Ac980569540cE38195b38369204ff555C80BE |  160 |   1 | wsteth |  ezETH |       |  tamper  |
            [6]  0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4 |  160 |   1 | wsteth |   weth |   -   |  tamper  |
            [7]  0x84Ce89B4f6F67E523A81A82f9f2F14D84B726F6B |    2 |   1 | usdc   |   usdt |   -   |  tamper  |
            [8]  0x2FA71491F8070FA644d97b4782dB5734854c0f6F |    2 |   1 | usdc   | usdc.e |       |  tamper  |
            [9]  0x3C01ec09D15D5450FC702DC4353b17Cd2978d8a5 |    2 |   1 | usdc   |   susd |       |  tamper  |
            [10] 0x8Ac2f9daC7a2852D44F3C09634444d533E4C078e |    2 |   1 | usdc   |   lusd |       |  tamper  |
            --------------------------------------------------------------------------------------------------|
        */

        uint256 ID = 0;
        IVeloOracle.SecurityParams memory securityParams = SECURITY_PARAMS_DEFAULT;
        //---------------------------------------------------------------------------------------
       /*  poolDeployParams[ID].pool = ICLPool(0xeBD5311beA1948e1441333976EadCFE5fBda777C);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = MAX_USD_AMOUNT;
        poolDeployParams[ID].maxAmount1 = MAX_OP_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].totalSupplyLimit = 1000 ether;
        poolDeployParams[ID].initialTotalSupply = 10 ** 12;
        securityParams = SECURITY_PARAMS_DEFAULT;
        securityParams.maxAllowedDelta = poolDeployParams[ID].pool.tickSpacing() / 10;
        poolDeployParams[ID].securityParams = securityParams;
        ID++;
        //---------------------------------------------------------------------------------------
        poolDeployParams[ID].pool = ICLPool(0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 6000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = MAX_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = MAX_OP_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].totalSupplyLimit = 1000 ether;
        poolDeployParams[ID].initialTotalSupply = 10 ** 18;
        securityParams = SECURITY_PARAMS_DEFAULT;
        securityParams.maxAllowedDelta = poolDeployParams[ID].pool.tickSpacing() / 10;
        poolDeployParams[ID].securityParams = securityParams;
        ID++; */
        //---------------------------------------------------------------------------------------
        poolDeployParams[ID].pool = ICLPool(0x478946BcD4a5a22b316470F5486fAfb928C0bA25); //[2]  0x478946BcD4a5a22b316470F5486fAfb928C0bA25 | 4000 | 100 | usdc   |   weth 
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 4000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = MAX_USD_AMOUNT;
        poolDeployParams[ID].maxAmount1 = MAX_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].totalSupplyLimit = 1000 ether;
        poolDeployParams[ID].initialTotalSupply = 10 ** 18;
        securityParams = SECURITY_PARAMS_DEFAULT;
        securityParams.maxAllowedDelta = poolDeployParams[ID].pool.tickSpacing() / 10;
        poolDeployParams[ID].securityParams = securityParams;
        ID++;
        //---------------------------------------------------------------------------------------
       /* poolDeployParams[ID].pool = ICLPool(0x319C0DD36284ac24A6b2beE73929f699b9f48c38);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 4000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = MAX_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = MAX_BTC_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].totalSupplyLimit = 1000 ether;
        poolDeployParams[ID].initialTotalSupply = 10 ** 12;
        securityParams = SECURITY_PARAMS_DEFAULT;
        securityParams.maxAllowedDelta = poolDeployParams[ID].pool.tickSpacing() / 10;
        poolDeployParams[ID].securityParams = securityParams;
        ID++; */
        //---------------------------------------------------------------------------------------
 /*       poolDeployParams[ID].pool = ICLPool(0xEE1baC98527a9fDd57fcCf967817215B083cE1F0);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.LazySyncing;
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 4000;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = MAX_LIQUIDITY_RATIO_DEVIATION_X96_DEFAULT;
        poolDeployParams[ID].maxAmount0 = MAX_USD_AMOUNT;
        poolDeployParams[ID].maxAmount1 = MAX_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].totalSupplyLimit = 1000 ether;
        poolDeployParams[ID].initialTotalSupply = 10 ** 12;
        securityParams = SECURITY_PARAMS_DEFAULT;
        securityParams.maxAllowedDelta = poolDeployParams[ID].pool.tickSpacing() / 10;
        poolDeployParams[ID].securityParams = securityParams;
        ID++;
        //---------------------------------------------------------------------------------------
         poolDeployParams[ID].pool = ICLPool(0xb71Ac980569540cE38195b38369204ff555C80BE);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 160;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96/20;
        poolDeployParams[ID].maxAmount0 = MAX_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = MAX_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].totalSupplyLimit = 1000 ether;
        poolDeployParams[ID].initialTotalSupply = 10 ** 18;
        securityParams = SECURITY_PARAMS_DEFAULT;
        securityParams.maxAllowedDelta = 1;
        poolDeployParams[ID].securityParams = securityParams;
        ID++; */
        //---------------------------------------------------------------------------------------
        poolDeployParams[ID].pool = ICLPool(0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4); // [6]  0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4 |   10 |   1 | wsteth |   weth
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 160;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96/20;
        poolDeployParams[ID].maxAmount0 = MAX_ETH_AMOUNT;
        poolDeployParams[ID].maxAmount1 = MAX_ETH_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].totalSupplyLimit = 1000 ether;
        poolDeployParams[ID].initialTotalSupply = 10 ** 18;
        securityParams = SECURITY_PARAMS_DEFAULT;
        securityParams.maxAllowedDelta = 1;
        poolDeployParams[ID].securityParams = securityParams;
        ID++;
        //---------------------------------------------------------------------------------------
        poolDeployParams[ID].pool = ICLPool(0x84Ce89B4f6F67E523A81A82f9f2F14D84B726F6B); // [7]  0x84Ce89B4f6F67E523A81A82f9f2F14D84B726F6B |    1 |   1 | usdc   |   usdt
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 2;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96/20;
        poolDeployParams[ID].maxAmount0 = MAX_USD_AMOUNT;
        poolDeployParams[ID].maxAmount1 = MAX_USD_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].totalSupplyLimit = 1000 ether;
        poolDeployParams[ID].initialTotalSupply = 10 ** 6;
        securityParams = SECURITY_PARAMS_DEFAULT;
        securityParams.maxAllowedDelta = 1;
        poolDeployParams[ID].securityParams = securityParams;
        ID++;
        //---------------------------------------------------------------------------------------
        /* poolDeployParams[ID].pool = ICLPool(0x2FA71491F8070FA644d97b4782dB5734854c0f6F);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 2;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96/20;
        poolDeployParams[ID].maxAmount0 = MAX_USD_AMOUNT;
        poolDeployParams[ID].maxAmount1 = MAX_USD_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].totalSupplyLimit = 1000 ether;
        poolDeployParams[ID].initialTotalSupply = 10 ** 6;
        securityParams = SECURITY_PARAMS_DEFAULT;
        securityParams.maxAllowedDelta = 1;
        poolDeployParams[ID].securityParams = securityParams;
        ID++;
        //---------------------------------------------------------------------------------------
        poolDeployParams[ID].pool = ICLPool(0x3C01ec09D15D5450FC702DC4353b17Cd2978d8a5);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 2;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96/20;
        poolDeployParams[ID].maxAmount0 = MAX_USD_AMOUNT;
        poolDeployParams[ID].maxAmount1 = MAX_SUSD_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].totalSupplyLimit = 1000 ether;
        poolDeployParams[ID].initialTotalSupply = 10 ** 12;
        securityParams = SECURITY_PARAMS_DEFAULT;
        securityParams.maxAllowedDelta = 1;
        poolDeployParams[ID].securityParams = securityParams;
        ID++;
        //---------------------------------------------------------------------------------------
        poolDeployParams[ID].pool = ICLPool(0x8Ac2f9daC7a2852D44F3C09634444d533E4C078e);
        poolDeployParams[ID].strategyParams.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        poolDeployParams[ID].strategyParams.tickNeighborhood = 0;
        poolDeployParams[ID].strategyParams.width = 2;
        poolDeployParams[ID].strategyParams.maxLiquidityRatioDeviationX96 = Q96/20;
        poolDeployParams[ID].maxAmount0 = MAX_USD_AMOUNT;
        poolDeployParams[ID].maxAmount1 = MAX_LUSD_AMOUNT;
        poolDeployParams[ID].slippageD9 = SLIPPAGE_D9_DEFAULT;
        poolDeployParams[ID].totalSupplyLimit = 1000 ether;
        poolDeployParams[ID].initialTotalSupply = 10 ** 12;
        securityParams = SECURITY_PARAMS_DEFAULT;
        securityParams.maxAllowedDelta = 1;
        poolDeployParams[ID].securityParams = securityParams; */
    }

    function _basePoolDeployParams() internal view
        returns (IVeloDeployFactory.DeployParams[] memory poolDeployParams)
    {
        poolDeployParams = new IVeloDeployFactory.DeployParams[](15);

        IVeloOracle.SecurityParams memory SECURITY_PARAMS_DEFAULT = IVeloOracle.SecurityParams({
            lookback: 2, // Maximum number of historical data points to consider for analysis
            maxAge: 1 hours, // Maximum age of observations to be used in the analysis
            maxAllowedDelta: 1 // Maximum allowed change between data points to be considered valid
        });

        /*
            |----------------------------------------------------------------------------------------------|
            |                      AERO_FACTORY = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A               |
            |----------------------------------------------------------------------------------------------|
            |                                    address | width|  TS |   t0   |     t1 | status|  ID | DW |
            |---------------------------------------------------------------------------|-------|-----|----|
            | 0x4e829F8A5213c42535AB84AA40BD4aDCCE9cBa02 | 6000 | 200 |  weth  |  brett |   -   |     |    |
            | 0xaFB62448929664Bfccb0aAe22f232520e765bA88 | 6000 | 200 |  weth  |  degen |   -   |     |    |
            | 0x82321f3BEB69f503380D6B233857d5C43562e2D0 | 6000 | 200 |  weth  |  aero  |   -   |     |    |
            | 0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59 | 4000 | 100 |  weth  |  usdc  |   -   |     |    |
            | 0x4D69971CCd4A636c403a3C1B00c85e99bB9B5606 | 4000 | 100 |  weth  |  usd+  |   -   |     |    |
            | 0x9785eF59E2b499fB741674ecf6fAF912Df7b3C1b | 4000 | 100 |  weth  |  usdt  |   -   |     |    |
            | 0xE846373C1a92B167b4E9cd5d8E4d6B1Db9E90EC7 | 1000 |  50 |  eurc  |  usdc  |   -   |     |    |
            | 0x861A2922bE165a5Bd41b1E482B49216b465e1B5F |    1 |   1 |  weth  |  wsteth|   -   |     |    |
            | 0x2ae9DF02539887d4EbcE0230168a302d34784c82 |    1 |   1 |  weth  |  bsdeth|   -   |     |    |
            | 0xdE5Ff829fEF54d1BdEc957D9538A306f0EAD1368 |    1 |   1 |  usdz  |  usdc  |   -   |     |    |
            | 0x988702fe529a3461ec7Fd09Eea3f962856709FD9 |    1 |   1 |  usdc  |  eusd  |   -   |     |    |
            | 0x47cA96Ea59C13F72745928887f84C9F52C3D7348 |    1 |   1 |  cbeth |  weth  |   -   |     |    |
            | 0xDC7EAd706795eDa3FEDa08Ad519d9452BAdF2C0d |    1 |   1 |  ezeth |  weth  |   -   |     |    |
            | 0x70aCDF2Ad0bf2402C957154f944c19Ef4e1cbAE1 | 4000 | 100 |  weth  | cbbtc  |   -   |     |    |
            | 0x4e962BB3889Bf030368F56810A9c96B83CB3E778 | 4000 | 100 |  usdc  | cbbtc  |   -   |     |    |
            |----------------------------------------------------------------------------------------------|
        */
        /* 
        poolDeployParams[0].pool = ICLPool(
            0x4e829F8A5213c42535AB84AA40BD4aDCCE9cBa02
        );
        poolDeployParams[0].width = 6000;
        poolDeployParams[0].maxAmount0 = MAX_ETH_AMOUNT;
        poolDeployParams[0].maxAmount1 = MAX_BRETT_AMOUNT;
        poolDeployParams[1].pool = ICLPool(
            0xaFB62448929664Bfccb0aAe22f232520e765bA88
        );
        poolDeployParams[1].width = 6000;
        poolDeployParams[1].maxAmount0 = MAX_ETH_AMOUNT;
        poolDeployParams[1].maxAmount1 = MAX_DEGEN_AMOUNT;
        poolDeployParams[2].pool = ICLPool(
            0x82321f3BEB69f503380D6B233857d5C43562e2D0
        );
        poolDeployParams[2].width = 6000;
        poolDeployParams[2].maxAmount0 = MAX_ETH_AMOUNT;
        poolDeployParams[2].maxAmount1 = MAX_AERO_AMOUNT;
        poolDeployParams[3].pool = ICLPool(
            0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59
        );
        poolDeployParams[3].width = 4000;
        poolDeployParams[3].maxAmount0 = MAX_ETH_AMOUNT;
        poolDeployParams[3].maxAmount1 = MAX_USD6_AMOUNT;
        poolDeployParams[4].pool = ICLPool(
            0x4D69971CCd4A636c403a3C1B00c85e99bB9B5606
        );
        poolDeployParams[4].width = 4000;
        poolDeployParams[4].maxAmount0 = MAX_ETH_AMOUNT;
        poolDeployParams[4].maxAmount1 = MAX_USD6_AMOUNT;
        poolDeployParams[5].pool = ICLPool(
            0x9785eF59E2b499fB741674ecf6fAF912Df7b3C1b
        );
        poolDeployParams[5].width = 4000;
        poolDeployParams[5].maxAmount0 = MAX_ETH_AMOUNT;
        poolDeployParams[5].maxAmount1 = MAX_USD6_AMOUNT;
        poolDeployParams[6].pool = ICLPool(
            0xE846373C1a92B167b4E9cd5d8E4d6B1Db9E90EC7
        );
        poolDeployParams[6].width = 1000;
        poolDeployParams[6].maxAmount0 = MAX_USD6_AMOUNT;
        poolDeployParams[6].maxAmount1 = MAX_USD6_AMOUNT;
        poolDeployParams[7].pool = ICLPool(
            0x861A2922bE165a5Bd41b1E482B49216b465e1B5F
        );
        poolDeployParams[7].width = 1;
        poolDeployParams[7].maxAmount0 = MAX_ETH_AMOUNT;
        poolDeployParams[7].maxAmount1 = MAX_ETH_AMOUNT;
        poolDeployParams[8].pool = ICLPool(
            0x2ae9DF02539887d4EbcE0230168a302d34784c82
        );
        poolDeployParams[8].width = 1;
        poolDeployParams[8].maxAmount0 = MAX_ETH_AMOUNT;
        poolDeployParams[8].maxAmount1 = MAX_ETH_AMOUNT;
        poolDeployParams[9].pool = ICLPool(
            0xdE5Ff829fEF54d1BdEc957D9538A306f0EAD1368
        );
        poolDeployParams[9].width = 1;
        poolDeployParams[9].maxAmount0 = MAX_USD18_AMOUNT;
        poolDeployParams[9].maxAmount1 = MAX_USD6_AMOUNT;
        poolDeployParams[10].pool = ICLPool(
            0x988702fe529a3461ec7Fd09Eea3f962856709FD9
        );
        poolDeployParams[10].width = 1;
        poolDeployParams[10].maxAmount0 = MAX_USD6_AMOUNT;
        poolDeployParams[10].maxAmount1 = MAX_USD18_AMOUNT;
        poolDeployParams[11].pool = ICLPool(
            0x47cA96Ea59C13F72745928887f84C9F52C3D7348
        );
        poolDeployParams[11].width = 1;
        poolDeployParams[11].maxAmount0 = MAX_ETH_AMOUNT;
        poolDeployParams[11].maxAmount1 = MAX_ETH_AMOUNT;
        poolDeployParams[12].pool = ICLPool(
            0xDC7EAd706795eDa3FEDa08Ad519d9452BAdF2C0d
        );
        poolDeployParams[12].width = 1;
        poolDeployParams[12].maxAmount0 = MAX_ETH_AMOUNT;
        poolDeployParams[12].maxAmount1 = MAX_ETH_AMOUNT;
        poolDeployParams[13].pool = ICLPool(
            0x70aCDF2Ad0bf2402C957154f944c19Ef4e1cbAE1
        );
        poolDeployParams[13].width = 4000;
        poolDeployParams[13].maxAmount0 = MAX_ETH_AMOUNT;
        poolDeployParams[13].maxAmount1 = MAX_BTC_AMOUNT;
        poolDeployParams[14].pool = ICLPool(
            0x4e962BB3889Bf030368F56810A9c96B83CB3E778
        );
        poolDeployParams[14].width = 4000;
        poolDeployParams[14].maxAmount0 = MAX_USD6_AMOUNT;
        poolDeployParams[14].maxAmount1 = MAX_BTC_AMOUNT;*/
    }
}
