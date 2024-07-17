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
    |----------------------------------------------------------------------------------------------|
    |                      AERO_FACTORY = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A               |
    |----------------------------------------------------------------------------------------------|
    |                                    address | width|  TS |   t0   |     t1 | status|  ID | DW | sec/tx
    |---------------------------------------------------------------------------|-------|-----|----|
    | 0x4e829F8A5213c42535AB84AA40BD4aDCCE9cBa02 | 6000 | 200 |  weth  |  brett |   +   |  0  | ++ | 6 sec
    | 0xaFB62448929664Bfccb0aAe22f232520e765bA88 | 6000 | 200 |  weth  |  degen |   +   |  1  | ++ | 120 sec
    | 0x82321f3BEB69f503380D6B233857d5C43562e2D0 | 6000 | 200 |  weth  |  aero  |   +   |  2  | ++ | 40 sec
    | 0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59 | 4000 | 100 |  weth  |  usdc  |   +   |  3  | ++ | 6 sec
    | 0x4D69971CCd4A636c403a3C1B00c85e99bB9B5606 | 4000 | 100 |  weth  |  usd+  |   +   |  4  | ++ | 3 sec
    | 0x861A2922bE165a5Bd41b1E482B49216b465e1B5F |      |   1 |  weth  |  wsteth|   +   |  5  | ++ | 60 sec
    | 0x2ae9DF02539887d4EbcE0230168a302d34784c82 |      |   1 |  weth  |  bsdeth|   +   |  6  | ++ | 360 sec
    | 0x0c1A09d5D0445047DA3Ab4994262b22404288A3B |      |   1 |  usdc  |  usd+  |   +   |  7  | ++ | 30 sec
    | 0x20086910E220D5f4c9695B784d304A72a0de403B |      |   1 |  usd+  |  usdbc |   +   |  8  | ++ | 60 sec
    | 0xdE5Ff829fEF54d1BdEc957D9538A306f0EAD1368 |      |   1 |  usdz  |  usdc  |revert |     |    | 180 sec
    | 0x988702fe529a3461ec7Fd09Eea3f962856709FD9 |      |   1 |  usdc  |  eusd  |   -   |     |    | 500 sec
    | 0x47cA96Ea59C13F72745928887f84C9F52C3D7348 |      |   1 |  cbeth |  weth  |   -   |     |    | 900 sec
    | 0xDC7EAd706795eDa3FEDa08Ad519d9452BAdF2C0d |      |   1 |  ezeth |  weth  |   -   |     |    | 1000 sec
    |----------------------------------------------------------------------------------------------|
*/

/// @dev pool address and position width to add
address constant POOL_ADDRESS = 0xdE5Ff829fEF54d1BdEc957D9538A306f0EAD1368;
int24 constant POOL_POSITION_WIDTH = 1;
int24 constant MAX_ALLOWED_DELTA = 1;
uint32 constant MAX_AGE = 1 hours;

/*
  Deployer address: 0xeccba048Fd1fcD5c26f3aAfb7aBf3737e163d0FD
  oracleAddress 0x556323eC861e3574F6D59cabd526C78496C8EFB5
  strategyModuleAddress 0xA589489eb8f1C2134b9338dC58992e2c80a01dC3
  velotrDeployFactoryHelperAddress 0x78F8A08aa8AFaC813e700aF94c97a5A988537fc8
  ammModuleAddress 0x65FcB0D51413229772104422E8f7eFE3F59E0d26
  veloDepositWithdrawModuleAddress 0x873a6A2757b927C82456B850Fcb7E7a3Bf8bbbD5
  coreAddress 0x403875f04283cd5403dCA5BF96fbbd071659478E
  pulseVeloBotAddress 0xE23653290b0C5065484B14171c6e11Da238F7321
  deployFactoryAddress 0x3F9E6301E76d83A7c6e19461a08d27f844E316D3
  createStrategyHelperAddress 0xd578cc03Ea813814933675b2dc9c7ab331fB47F9
*/

/// @dev deployed addresses
address constant DEPLOY_FACTORY_ADDRESS = 0x3F9E6301E76d83A7c6e19461a08d27f844E316D3;
address constant CREATE_STRATEGY_HELPER_ADDRESS = 0xd578cc03Ea813814933675b2dc9c7ab331fB47F9;

/// @dev immutable addresses at the deployment
address constant VELO_FACTORY_ADDRESS = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;

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
