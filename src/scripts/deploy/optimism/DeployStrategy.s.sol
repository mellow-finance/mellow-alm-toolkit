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
/// @param WIDTH - width position in ticks
/// @dev all logged address should be saved for the next

/// @dev pool address and position width to add
uint32 constant MAX_AGE = 1 hours;

/*
  Deployer address: 0xeccba048Fd1fcD5c26f3aAfb7aBf3737e163d0FD
  oracleAddress 0x82004063fdf73A63Fd66a757c9243a98978eCF0a
  strategyModuleAddress 0xacf34411cCEA6Fb196c5E8C79B6349f8C3CD1Ae4
  velotrDeployFactoryHelperAddress 0xd5f83f2f9ef5a49c439b37ad68a95f80780da2f8
  ammModuleAddress 0x326cA8bCf117bDc00ad641D237a35365DEFDE308
  veloDepositWithdrawModuleAddress 0xEdfd0dd4Ada2B6CddfF2BC0f03D8adc93b658271
  coreAddress 0x8CBA3833ad114b4021734357D9383F4DBD69638F
  pulseVeloBotAddress 0xB3dDa916420774efaD6C5cf1a7b55CDCdC245f04
  deployFactoryAddress 0xfAd92599d48D281b3A63F10454F029d77751c643
  createStrategyHelperAddress 0x0C22fFf57828b1860806FFF0dA964ecd0fD4eaDB
*/

/// @dev deployed addresses
address constant DEPLOY_FACTORY_ADDRESS = 0xfAd92599d48D281b3A63F10454F029d77751c643;
address constant CREATE_STRATEGY_HELPER_ADDRESS = 0x0C22fFf57828b1860806FFF0dA964ecd0fD4eaDB;

/// @dev immutable addresses at the deployment
address constant VELO_FACTORY_ADDRESS = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F;

contract Deploy is Script, Test {
    uint256 immutable operatorPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    VeloDeployFactory immutable veloDeployFactory =
        VeloDeployFactory(DEPLOY_FACTORY_ADDRESS);

    /// @dev number from below list of pool to deploy strategy
    uint256 immutable POOL_NUMBER = 2;

    function setPoolParameters()
        internal
        pure
        returns (CreateStrategyHelper.PoolParameter[] memory parameters)
    {
        parameters = new CreateStrategyHelper.PoolParameter[](11);
        /*
            --------------------------------------------------------------------------------------------------|
                               VELO_FACTORY = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F
            --------------------------------------------------------------------------------------------------|
                                              address | width|  TS |         t0   |     t1 | status|  ID | DW |
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
        parameters[0].minAmount = 1000000;
        parameters[1].pool = ICLPool(
            0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60
        );
        parameters[1].width = 6000;
        parameters[1].minAmount = uint256(10 ** 18) / 3000;
        parameters[2].pool = ICLPool(
            0x478946BcD4a5a22b316470F5486fAfb928C0bA25
        );
        parameters[2].width = 4000;
        parameters[2].minAmount = 1000000;
        parameters[3].pool = ICLPool(
            0x319C0DD36284ac24A6b2beE73929f699b9f48c38
        );
        parameters[3].width = 4000;
        parameters[3].minAmount = uint256(10 ** 18) / 50000;
        parameters[4].pool = ICLPool(
            0xEE1baC98527a9fDd57fcCf967817215B083cE1F0
        );
        parameters[4].width = 4000;
        parameters[4].minAmount = 1000000;
        parameters[5].pool = ICLPool(
            0xb71Ac980569540cE38195b38369204ff555C80BE
        );
        parameters[5].width = 10;
        parameters[5].minAmount = uint256(10 ** 18) / 3000;
        parameters[6].pool = ICLPool(
            0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4
        );
        parameters[6].width = 10;
        parameters[6].minAmount = uint256(10 ** 18) / 3000;
        parameters[7].pool = ICLPool(
            0x84Ce89B4f6F67E523A81A82f9f2F14D84B726F6B
        );
        parameters[7].width = 1;
        parameters[7].minAmount = 1000000;
        parameters[8].pool = ICLPool(
            0x2FA71491F8070FA644d97b4782dB5734854c0f6F
        );
        parameters[8].width = 1;
        parameters[8].minAmount = 1000000;
        parameters[9].pool = ICLPool(
            0x3C01ec09D15D5450FC702DC4353b17Cd2978d8a5
        );
        parameters[9].width = 1;
        parameters[9].minAmount = 1000000;
        parameters[10].pool = ICLPool(
            0x8Ac2f9daC7a2852D44F3C09634444d533E4C078e
        );
        parameters[10].width = 1;
        parameters[10].minAmount = 1000000;
    }

    function deployCreateStrategyHelper() internal {
        vm.startBroadcast(operatorPrivateKey);
        CreateStrategyHelper createStrategyHelper = new CreateStrategyHelper(
            INonfungiblePositionManager(
                0x416b433906b1B72FA758e166e239c43d68dC6F29
            ),
            veloDeployFactory
        );
        veloDeployFactory.grantRole(
            veloDeployFactory.ADMIN_DELEGATE_ROLE(),
            address(createStrategyHelper)
        );
        console2.log("createStrategyHelper", address(createStrategyHelper));
    }

    function withdraw(address lpWrapper, address to) private {
        /// @dev withdraw whole assets
        (uint256 amount0, uint256 amount1, uint256 actualLpAmount) = ILpWrapper(
            lpWrapper
        ).withdraw(
                type(uint256).max, // it will be truncated to the actual owned lpTokens
                0,
                0,
                to,
                type(uint256).max
            );

        console2.log(" ================== withdraw info ==================== ");
        console2.log("withdrawer: ", to);
        console2.log("   amount0: ", amount0);
        console2.log("   amount1: ", amount1);
        console2.log("  lpAmount: ", actualLpAmount);
    }

    function run() public {
        CreateStrategyHelper createStrategyHelper = CreateStrategyHelper(
            CREATE_STRATEGY_HELPER_ADDRESS
        );
        vm.startBroadcast(operatorPrivateKey);
        address operatoAddress = vm.addr(operatorPrivateKey);
        CreateStrategyHelper.PoolParameter[]
            memory parameters = setPoolParameters();

        address lpWrapper = veloDeployFactory
            .poolToAddresses(address(parameters[POOL_NUMBER].pool))
            .lpWrapper;
        if (lpWrapper != address(0)) {
            withdraw(lpWrapper, operatoAddress);
        }

        veloDeployFactory.removeAddressesForPool(
            address(parameters[POOL_NUMBER].pool)
        );
        require(
            parameters[POOL_NUMBER].width %
                parameters[POOL_NUMBER].pool.tickSpacing() ==
                0,
            "POOL_POSITION_WIDTH is not valid"
        );
        parameters[POOL_NUMBER].factory = ICLFactory(VELO_FACTORY_ADDRESS);
        parameters[POOL_NUMBER].tickSpacing = parameters[POOL_NUMBER]
            .pool
            .tickSpacing();
        parameters[POOL_NUMBER].token0 = parameters[POOL_NUMBER].pool.token0();
        parameters[POOL_NUMBER].token1 = parameters[POOL_NUMBER].pool.token1();

        int24 maxAllowedDelta = parameters[POOL_NUMBER].tickSpacing / 10; // 10% of tickSpacing
        console2.log("  maxAllowedDelta:", maxAllowedDelta);
        parameters[POOL_NUMBER].securityParams = IVeloOracle.SecurityParams({
            lookback: 10,
            maxAllowedDelta: maxAllowedDelta < int24(1)
                ? int24(1)
                : maxAllowedDelta,
            maxAge: MAX_AGE
        });

        IERC20(parameters[POOL_NUMBER].token0).approve(
            address(createStrategyHelper),
            type(uint256).max
        );
        IERC20(parameters[POOL_NUMBER].token1).approve(
            address(createStrategyHelper),
            type(uint256).max
        );

        (
            VeloDeployFactory.PoolAddresses memory poolAddresses,
            uint256 tokenId
        ) = createStrategyHelper.createStrategy(
                parameters[POOL_NUMBER],
                parameters[POOL_NUMBER].minAmount
            );

        console2.log(
            " =======     POOL ",
            address(parameters[POOL_NUMBER].pool),
            "    ========"
        );
        console2.log("          tokenId:", tokenId);
        console2.log("        lpWrapper:", poolAddresses.lpWrapper);
        console2.log("    synthetixFarm:", poolAddresses.synthetixFarm);
    }
}
