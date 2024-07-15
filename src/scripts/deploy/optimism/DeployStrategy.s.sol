// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import "src/Core.sol";
import "src/bots/PulseVeloBot.sol";
import "src/helpers/CreateStrategyHelper.sol";

/// @dev =================== STAGE TWO =====================
/// @dev script should be used for deployment specific strategies
/// @dev it may be called many times for differrent pool
/// @param DEPLOY_FACTORY_ADDRESS - address of deployed SC at the first STAGE
/// @param CREATE_STRATEGY_HELPER_ADDRESS - address of deployed SC at the first STAGE
/// @param POOL_ADDRESS - strategy pool address
/// @param WIDTH - width position in ticks
/// @dev all logged address should be saved for the next

/*
    ----------------------------------------------------------------------------------
            VELO_FACTORY = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F
    ----------------------------------------------------------------------------------
                                       address | width|  TS |   t0   |     t1 | status 
    --------------------------------------------------------------------------|-------
    0xeBD5311beA1948e1441333976EadCFE5fBda777C | 6000 | 200 | usdc   |     op |   + 3
    0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60 | 6000 | 200 | weth   |     op |   + 4
    0x478946BcD4a5a22b316470F5486fAfb928C0bA25 | 4000 | 100 | usdc   |   weth |   + 0
    0x319C0DD36284ac24A6b2beE73929f699b9f48c38 | 4000 | 100 | weth   |   wbtc |   + 1
    0xEE1baC98527a9fDd57fcCf967817215B083cE1F0 | 4000 | 100 | usdc   | wsteth |   + 2
    0xb71Ac980569540cE38195b38369204ff555C80BE |   10 |   1 | wsteth |  ezETH |   + 5
    0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4 |   10 |   1 | wsteth |   weth |   + 6
    0x84Ce89B4f6F67E523A81A82f9f2F14D84B726F6B |    1 |   1 | usdc   |   usdt |   + 7
    0x2FA71491F8070FA644d97b4782dB5734854c0f6F |    1 |   1 | usdc   | usdc.e |   + 8
    0x3C01ec09D15D5450FC702DC4353b17Cd2978d8a5 |    1 |   1 | usdc   |   susd |   + 9
    0x8Ac2f9daC7a2852D44F3C09634444d533E4C078e |    1 |   1 | usdc   |   lusd |   + 10 test 10
    --------------------------------------------------------------------------|
*/

/// @dev pool address and position width to add
address constant POOL_ADDRESS = 0xb71Ac980569540cE38195b38369204ff555C80BE;
int24 constant POOL_POSITION_WIDTH = 10;
int24 constant MAX_ALLOWED_DELTA = 1;
uint32 constant MAX_AGE = 1 hours;

/*
  Deployer address: 0xeccba048Fd1fcD5c26f3aAfb7aBf3737e163d0FD
  oracleAddress 0x82004063fdf73A63Fd66a757c9243a98978eCF0a
  strategyModuleAddress 0xacf34411cCEA6Fb196c5E8C79B6349f8C3CD1Ae4
  velotrDeployFactoryHelperAddress 0x511B4EE54601eF30Dbd3708eeD47aa1497516079
  ammModuleAddress 0x326cA8bCf117bDc00ad641D237a35365DEFDE308
  veloDepositWithdrawModuleAddress 0xEdfd0dd4Ada2B6CddfF2BC0f03D8adc93b658271
  coreAddress 0x8CBA3833ad114b4021734357D9383F4DBD69638F
  pulseVeloBotAddress 0xB3dDa916420774efaD6C5cf1a7b55CDCdC245f04
  deployFactoryAddress 0x2B4005CEA7acfa1285034d4887E761fD1a4c7C7D
  createStrategyHelperAddress 0x0f5A7135EA6ba4dA3A0AD3092E38471A0f82C023
*/

/// @dev deployed addresses
address constant DEPLOY_FACTORY_ADDRESS = 0x2B4005CEA7acfa1285034d4887E761fD1a4c7C7D;
address constant CREATE_STRATEGY_HELPER_ADDRESS = 0x0f5A7135EA6ba4dA3A0AD3092E38471A0f82C023;

/// @dev immutable addresses at the deployment
address constant VELO_FACTORY_ADDRESS = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F;

contract Deploy is Script, Test {
    uint256 immutable operatorPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

    function run() public {
        CreateStrategyHelper createStrategyHelper = CreateStrategyHelper(
            CREATE_STRATEGY_HELPER_ADDRESS
        );

        vm.startBroadcast(operatorPrivateKey);

        ICLPool pool = ICLPool(POOL_ADDRESS);
        require(
            POOL_POSITION_WIDTH % pool.tickSpacing() == 0,
            "POOL_POSITION_WIDTH is not valid"
        );

        CreateStrategyHelper.PoolParameter
            memory poolParameter = CreateStrategyHelper.PoolParameter({
                factory: ICLFactory(VELO_FACTORY_ADDRESS),
                pool: ICLPool(pool),
                width: POOL_POSITION_WIDTH,
                tickSpacing: pool.tickSpacing(),
                token0: pool.token0(),
                token1: pool.token1(),
                securityParams: IVeloOracle.SecurityParams({
                    lookback: 10,
                    maxAllowedDelta: MAX_ALLOWED_DELTA,
                    maxAge: MAX_AGE
                })
            });

        IERC20(poolParameter.token0).approve(
            address(createStrategyHelper),
            type(uint256).max
        );
        IERC20(poolParameter.token1).approve(
            address(createStrategyHelper),
            type(uint256).max
        );
        (
            VeloDeployFactory.PoolAddresses memory poolAddresses,
            uint256 tokenId
        ) = createStrategyHelper.createStrategy(poolParameter, 100000);

        console2.log(
            " =======     POOL ",
            address(poolParameter.pool),
            "    ========"
        );
        console2.log("          tokenId:", tokenId);
        console2.log("        lpWrapper:", poolAddresses.lpWrapper);
        console2.log("    synthetixFarm:", poolAddresses.synthetixFarm);

        vm.stopBroadcast();
    }
}
