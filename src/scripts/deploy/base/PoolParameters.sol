// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "../../src.sol";

contract PoolParameters {
    uint256 constant MAX_ETH_AMOUNT = uint256(10 ** 18) / 2500; // 1 ETH/2500 ~ 1 USD
    uint256 constant MAX_BTC_AMOUNT = uint256(10 ** 18) / 60000; // 1 BTC/60000 ~ 1 USD
    uint256 constant MAX_BRETT_AMOUNT = uint256(10 ** 18) * 14; // 18 BRETT ~ 1 USD
    uint256 constant MAX_DEGEN_AMOUNT = uint256(10 ** 18) * 300; // 300 DEGEN ~ 1 USD
    uint256 constant MAX_AERO_AMOUNT = uint256(10 ** 18) * 300; // 2 AERO ~ 1.1 USD
    uint256 constant MAX_USD6_AMOUNT = 10 ** 6; // 1 USD
    uint256 constant MAX_USD18_AMOUNT = 10 ** 18; // 1 USD

    //   CreateStrategyHelper.PoolParameter[15] parameters;

    constructor() {
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
        parameters[0].pool = ICLPool(
            0x4e829F8A5213c42535AB84AA40BD4aDCCE9cBa02
        );
        parameters[0].width = 6000;
        parameters[0].maxAmount0 = MAX_ETH_AMOUNT;
        parameters[0].maxAmount1 = MAX_BRETT_AMOUNT;

        parameters[1].pool = ICLPool(
            0xaFB62448929664Bfccb0aAe22f232520e765bA88
        );
        parameters[1].width = 6000;
        parameters[1].maxAmount0 = MAX_ETH_AMOUNT;
        parameters[1].maxAmount1 = MAX_DEGEN_AMOUNT;

        parameters[2].pool = ICLPool(
            0x82321f3BEB69f503380D6B233857d5C43562e2D0
        );
        parameters[2].width = 6000;
        parameters[2].maxAmount0 = MAX_ETH_AMOUNT;
        parameters[2].maxAmount1 = MAX_AERO_AMOUNT;

        parameters[3].pool = ICLPool(
            0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59
        );
        parameters[3].width = 4000;
        parameters[3].maxAmount0 = MAX_ETH_AMOUNT;
        parameters[3].maxAmount1 = MAX_USD6_AMOUNT;

        parameters[4].pool = ICLPool(
            0x4D69971CCd4A636c403a3C1B00c85e99bB9B5606
        );
        parameters[4].width = 4000;
        parameters[4].maxAmount0 = MAX_ETH_AMOUNT;
        parameters[4].maxAmount1 = MAX_USD6_AMOUNT;

        parameters[5].pool = ICLPool(
            0x9785eF59E2b499fB741674ecf6fAF912Df7b3C1b
        );
        parameters[5].width = 4000;
        parameters[5].maxAmount0 = MAX_ETH_AMOUNT;
        parameters[5].maxAmount1 = MAX_USD6_AMOUNT;

        parameters[6].pool = ICLPool(
            0xE846373C1a92B167b4E9cd5d8E4d6B1Db9E90EC7
        );
        parameters[6].width = 1000;
        parameters[6].maxAmount0 = MAX_USD6_AMOUNT;
        parameters[6].maxAmount1 = MAX_USD6_AMOUNT;

        parameters[7].pool = ICLPool(
            0x861A2922bE165a5Bd41b1E482B49216b465e1B5F
        );
        parameters[7].width = 1;
        parameters[7].maxAmount0 = MAX_ETH_AMOUNT;
        parameters[7].maxAmount1 = MAX_ETH_AMOUNT;

        parameters[8].pool = ICLPool(
            0x2ae9DF02539887d4EbcE0230168a302d34784c82
        );
        parameters[8].width = 1;
        parameters[8].maxAmount0 = MAX_ETH_AMOUNT;
        parameters[8].maxAmount1 = MAX_ETH_AMOUNT;

        parameters[9].pool = ICLPool(
            0xdE5Ff829fEF54d1BdEc957D9538A306f0EAD1368
        );
        parameters[9].width = 1;
        parameters[9].maxAmount0 = MAX_USD18_AMOUNT;
        parameters[9].maxAmount1 = MAX_USD6_AMOUNT;

        parameters[10].pool = ICLPool(
            0x988702fe529a3461ec7Fd09Eea3f962856709FD9
        );
        parameters[10].width = 1;
        parameters[10].maxAmount0 = MAX_USD6_AMOUNT;
        parameters[10].maxAmount1 = MAX_USD18_AMOUNT;

        parameters[11].pool = ICLPool(
            0x47cA96Ea59C13F72745928887f84C9F52C3D7348
        );
        parameters[11].width = 1;
        parameters[11].maxAmount0 = MAX_ETH_AMOUNT;
        parameters[11].maxAmount1 = MAX_ETH_AMOUNT;

        parameters[12].pool = ICLPool(
            0xDC7EAd706795eDa3FEDa08Ad519d9452BAdF2C0d
        );
        parameters[12].width = 1;
        parameters[12].maxAmount0 = MAX_ETH_AMOUNT;
        parameters[12].maxAmount1 = MAX_ETH_AMOUNT;

        parameters[13].pool = ICLPool(
            0x70aCDF2Ad0bf2402C957154f944c19Ef4e1cbAE1
        );
        parameters[13].width = 4000;
        parameters[13].maxAmount0 = MAX_ETH_AMOUNT;
        parameters[13].maxAmount1 = MAX_BTC_AMOUNT;

        parameters[14].pool = ICLPool(
            0x4e962BB3889Bf030368F56810A9c96B83CB3E778
        );
        parameters[14].width = 4000;
        parameters[14].maxAmount0 = MAX_USD6_AMOUNT;
        parameters[14].maxAmount1 = MAX_BTC_AMOUNT;*/
    }
}
