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
    0x478946BcD4a5a22b316470F5486fAfb928C0bA25 | 4000 | 100 | usdc   |   weth |   +
    0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60 | 6000 | 200 | weth   |     op |   +
    0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4 |    1 |   1 | wsteth |   weth |   +
    0x84Ce89B4f6F67E523A81A82f9f2F14D84B726F6B |    1 |   1 | usdc   |   usdt |   +
    0x3C01ec09D15D5450FC702DC4353b17Cd2978d8a5 |    1 |   1 | usdc   |   susd |   +
    0xEE1baC98527a9fDd57fcCf967817215B083cE1F0 | 4000 | 100 | usdc   | wsteth |   +
    0x2FA71491F8070FA644d97b4782dB5734854c0f6F |    1 |   1 | usdc   | usdc.e |   +
    0x319C0DD36284ac24A6b2beE73929f699b9f48c38 | 4000 | 100 | weth   |   wbtc |   +
    0xeBD5311beA1948e1441333976EadCFE5fBda777C | 6000 | 200 | usdc   |     op |   +
    0xBafB44286c5EcaFb1F26A6649E15C49Fc1c49882 |  100 | 100 | weth   |   lusd | test
    --------------------------------------------------------------------------|
*/
/// @dev pool address and position width to add
address constant POOL_ADDRESS = 0xBafB44286c5EcaFb1F26A6649E15C49Fc1c49882;
int24 constant POOL_POSITION_WIDTH = 100;

/*
  Deployer address: 0xef5DCE7ED67eD50F38D4eed3244BEa62778D8e87
  oracleAddress 0x45cC5B0A18C48Db0d54D7fb2d30E7022c389D51f
  strategyModuleAddress 0x6Aa6215f353F17D97CaD8219B20204e771ec59e9
  velotrDeployFactoryHelperAddress 0x812Cf784f522908bc97c31CeC945684D78e338c9
  ammModuleAddress 0xA1890D3991b00bD5Aa43dedD2CC58aAAF26E88a8
  veloDepositWithdrawModuleAddress 0x37DA9a5859533E32E582A3989CF2da218220A3dC
  pulseVeloBotAddress 0x02c1bD2Ac1d59FE8B81F151303340564cA2f957C
  coreAddress 0xB4AbEf6f42bA5F89Dc060f4372642A1C700b22bC

  deployFactoryAddress 0xf8a5Adf0540353410a4432B6B6Cde42e548d4709
  createStrategyHelper 0x6ac1656218e6e939A77350228C88eCc3afc84e54
*/

/// @dev deployed addresses
address constant DEPLOY_FACTORY_ADDRESS = 0xf8a5Adf0540353410a4432B6B6Cde42e548d4709;
address constant CREATE_STRATEGY_HELPER_ADDRESS = 0x6ac1656218e6e939A77350228C88eCc3afc84e54;

/// @dev immutable addresses at the deployment
address constant VELO_FACTORY_ADDRESS = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F;

contract Deploy is Script, Test {
    uint256 immutable deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address immutable deployerAddress = vm.addr(deployerPrivateKey);

    function run() public {
        CreateStrategyHelper createStrategyHelper = CreateStrategyHelper(
            CREATE_STRATEGY_HELPER_ADDRESS
        );

        vm.startBroadcast(deployerPrivateKey);

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
                token1: pool.token1()
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
        ) = createStrategyHelper.createStrategy(poolParameter);

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
