// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.25;

import "../../src.sol";

contract PoolParameters {
    uint256 MAX_USD_AMOUNT = 10 ** 6; // 1 USD
    uint256 MAX_SUSD_AMOUNT = 10 ** 18; // 1 USD
    uint256 MAX_LUSD_AMOUNT = 10 ** 18; // 1 USD
    uint256 MAX_OP_AMOUNT = uint256(10 ** 18); // 1 OP ~ 1.3 USD
    uint256 MAX_ETH_AMOUNT = uint256(10 ** 18) / 2500; // 1 ETH/2500 ~ 1 USD
    uint256 MAX_BTC_AMOUNT = uint256(10 ** 8) / 50000; // 1 BTC/50000 ~ 1 USD

    CreateStrategyHelper.PoolParameter[11] parameters;

    constructor() {
        /*
            --------------------------------------------------------------------------------------------------|
                               VELO_FACTORY = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F
            --------------------------------------------------------------------------------------------------|
                                                    address | width|  TS |   t0   |     t1 | status|  ID | DW |
            -------------------------------------------------------------------------------|-------|-----|----|
            [0]  0xeBD5311beA1948e1441333976EadCFE5fBda777C | 6000 | 200 | usdc   |     op |       |     |    |
            [1]  0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60 | 6000 | 200 | weth   |     op |       |     |    |
            [2]  0x478946BcD4a5a22b316470F5486fAfb928C0bA25 | 4000 | 100 | usdc   |   weth |       |     |    |
            [3]  0x319C0DD36284ac24A6b2beE73929f699b9f48c38 | 4000 | 100 | weth   |   wbtc |       |     |    |
            [4]  0xEE1baC98527a9fDd57fcCf967817215B083cE1F0 | 4000 | 100 | usdc   | wsteth |       |     |    |
            [5]  0xb71Ac980569540cE38195b38369204ff555C80BE |   10 |   1 | wsteth |  ezETH |       |     |    |
            [6]  0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4 |   10 |   1 | wsteth |   weth |       |     |    |
            [7]  0x84Ce89B4f6F67E523A81A82f9f2F14D84B726F6B |    1 |   1 | usdc   |   usdt |       |     |    |
            [8]  0x2FA71491F8070FA644d97b4782dB5734854c0f6F |    1 |   1 | usdc   | usdc.e |       |     |    |
            [9]  0x3C01ec09D15D5450FC702DC4353b17Cd2978d8a5 |    1 |   1 | usdc   |   susd |       |     |    |
            [10] 0x8Ac2f9daC7a2852D44F3C09634444d533E4C078e |    1 |   1 | usdc   |   lusd |       |     |    |
            --------------------------------------------------------------------------------------------------|
        */

        parameters[0].pool = ICLPool(
            0xeBD5311beA1948e1441333976EadCFE5fBda777C
        );
        parameters[0].width = 6000;
        parameters[0].maxAmount0 = MAX_USD_AMOUNT;
        parameters[0].maxAmount1 = MAX_OP_AMOUNT;

        parameters[1].pool = ICLPool(
            0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60
        );
        parameters[1].width = 6000;
        parameters[1].maxAmount0 = MAX_ETH_AMOUNT;
        parameters[1].maxAmount1 = MAX_OP_AMOUNT;

        parameters[2].pool = ICLPool(
            0x478946BcD4a5a22b316470F5486fAfb928C0bA25
        );
        parameters[2].width = 4000;
        parameters[2].maxAmount0 = MAX_USD_AMOUNT;
        parameters[2].maxAmount1 = MAX_ETH_AMOUNT;

        parameters[3].pool = ICLPool(
            0x319C0DD36284ac24A6b2beE73929f699b9f48c38
        );
        parameters[3].width = 4000;
        parameters[3].maxAmount0 = MAX_ETH_AMOUNT;
        parameters[3].maxAmount1 = MAX_BTC_AMOUNT;

        parameters[4].pool = ICLPool(
            0xEE1baC98527a9fDd57fcCf967817215B083cE1F0
        );
        parameters[4].width = 4000;
        parameters[4].maxAmount0 = MAX_USD_AMOUNT;
        parameters[4].maxAmount1 = MAX_ETH_AMOUNT;

        parameters[5].pool = ICLPool(
            0xb71Ac980569540cE38195b38369204ff555C80BE
        );
        parameters[5].width = 10;
        parameters[5].maxAmount0 = MAX_ETH_AMOUNT;
        parameters[5].maxAmount1 = MAX_ETH_AMOUNT;

        parameters[6].pool = ICLPool(
            0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4
        );
        parameters[6].width = 10;
        parameters[6].maxAmount0 = MAX_ETH_AMOUNT;
        parameters[6].maxAmount1 = MAX_ETH_AMOUNT;

        parameters[7].pool = ICLPool(
            0x84Ce89B4f6F67E523A81A82f9f2F14D84B726F6B
        );
        parameters[7].width = 1;
        parameters[7].maxAmount0 = MAX_USD_AMOUNT;
        parameters[7].maxAmount1 = MAX_USD_AMOUNT;

        parameters[8].pool = ICLPool(
            0x2FA71491F8070FA644d97b4782dB5734854c0f6F
        );
        parameters[8].width = 1;
        parameters[8].maxAmount0 = MAX_USD_AMOUNT;
        parameters[8].maxAmount1 = MAX_USD_AMOUNT;

        parameters[9].pool = ICLPool(
            0x3C01ec09D15D5450FC702DC4353b17Cd2978d8a5
        );
        parameters[9].width = 1;
        parameters[9].maxAmount0 = MAX_USD_AMOUNT;
        parameters[9].maxAmount1 = MAX_SUSD_AMOUNT;

        parameters[10].pool = ICLPool(
            0x8Ac2f9daC7a2852D44F3C09634444d533E4C078e
        );
        parameters[10].width = 1;
        parameters[10].maxAmount0 = MAX_USD_AMOUNT;
        parameters[10].maxAmount1 = MAX_LUSD_AMOUNT;
    }
}
