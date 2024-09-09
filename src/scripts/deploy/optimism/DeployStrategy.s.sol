// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import "src/Core.sol";
import "src/bots/PulseVeloBot.sol";
import "src/utils/VeloDeployFactory.sol";
import "src/helpers/CreateStrategyHelper.sol";

/// @dev =================== STAGE TWO =====================
/// @dev script should be used for deployment specific strategies
/// @dev it may be called many times for differrent pool
/// @param DEPLOY_FACTORY_ADDRESS - address of deployed SC at the first STAGE
/// @param CREATE_STRATEGY_HELPER_ADDRESS - address of deployed SC at the first STAGE
/// @param WIDTH - width position in ticks
/// @dev all logged address should be saved for the next

/*
  Deployer 0xBe440AeE8c8D54aC7bb7D93506460492Df5812ea
  Core/deloy factory/wrapper admin and farm owner 0x893df22649247AD4e57E4926731F9Cf0dA344829
  Protocol treasuty 0xf0E36e9186Dbe927505d2588a6E6D56083Dd4a56
  Core operator 0x0A16Bc694EeA56cbFc808a271178556d3f8c23aD
  Deploy factory operator 0xBe440AeE8c8D54aC7bb7D93506460492Df5812ea
  VeloOracle 0x89bf652e92C073Ac49F33F6bB7B662b446b94681
  PulseStrategyModule 0xb3eBe27274304446E089f7c678e4ED68Ee387Fe2
  VeloDeployFactoryHelper 0x96e7ca11cd96b705ce8fEbccAdb466FD1245Cfea
  VeloAmmModule 0x734effcB7981B00046A9fcb00D6aBd477bbF9684
  VeloDepositWithdrawModule 0x6b0E1a42030cB62C505C60e808Ab945B1396F8e4
  Core 0x71D022eBA6F2607Ab8EC32Cb894075D94e10CEb8
  PulseVeloBotLazy 0x4B7C2Cd551052E2d4516987936D738339dbEFfef
  Compounder 0xb54AaCb3b203499543c6EC2B13acfaD74BBa8bE9
  VeloDeployFactory 0xeD8b81E3fF6c54951621715F5992CA52007D88bA
  CreateStrategyHelper 0x5B1b1aaC71bDca9Ed1dCb2AA357f678584db4029
  VeloSugarHelper 0xa0116415f30d9F783D4E8F1f3FcE5dBB9dD59fD7
*/

/// @dev deployed addresses
address constant DEPLOY_FACTORY_ADDRESS = 0xeD8b81E3fF6c54951621715F5992CA52007D88bA;
address constant CREATE_STRATEGY_HELPER_ADDRESS = 0x5B1b1aaC71bDca9Ed1dCb2AA357f678584db4029;

/// @dev immutable addresses at the deployment
address constant VELO_FACTORY_ADDRESS = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F;

contract DeployStrategy is Script, Test {
    uint256 immutable operatorPrivateKey = vm.envUint("OPERATOR_PRIVATE_KEY");

    /// @dev number from below list of pool to deploy strategy
    uint256 immutable POOL_ID = 0;

    function run() public virtual {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        deployAllStrategies();
        
        vm.stopBroadcast();
    }

    function setPoolParameters()
        internal
        pure
        returns (CreateStrategyHelper.PoolParameter[] memory parameters)
    {
        uint256 MAX_USD_AMOUNT = 10 ** 6; // 1 USD
        uint256 MAX_SUSD_AMOUNT = 10 ** 18; // 1 USD
        uint256 MAX_LUSD_AMOUNT = 10 ** 18; // 1 USD
        uint256 MAX_OP_AMOUNT = uint256(10 ** 18); // 1 OP ~ 1.3 USD
        uint256 MAX_ETH_AMOUNT = uint256(10 ** 18) / 2500; // 1 ETH/2500 ~ 1 USD
        uint256 MAX_BTC_AMOUNT = uint256(10 ** 8) / 50000; // 1 BTC/50000 ~ 1 USD

        parameters = new CreateStrategyHelper.PoolParameter[](11);
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

    function deployCreateStrategyHelper(
        address veloDeployFactoryAddress
    ) internal {
        VeloDeployFactory veloDeployFactory = VeloDeployFactory(
            veloDeployFactoryAddress
        );

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        CreateStrategyHelper createStrategyHelper = new CreateStrategyHelper(
            address(veloDeployFactory),
            vm.addr(deployerPrivateKey)
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

    function deployAllStrategies() internal {
        CreateStrategyHelper.PoolParameter[] memory parameters = setPoolParameters();

        for (uint i = 0; i < parameters.length; i++) {
            if (i == 0) continue;
            deployStrategy(DEPLOY_FACTORY_ADDRESS, CREATE_STRATEGY_HELPER_ADDRESS, i);
        }
    }

    function deployStrategy(
        address veloDeployFactoryAddress,
        address createStrategyHelperAddress,
        uint256 poolId
    ) internal {
        IVeloDeployFactory veloDeployFactory = IVeloDeployFactory(
            veloDeployFactoryAddress
        );
        CreateStrategyHelper createStrategyHelper = CreateStrategyHelper(
            createStrategyHelperAddress
        );

        address operatorAddress = vm.addr(operatorPrivateKey);
        CreateStrategyHelper.PoolParameter[]
            memory parameters = setPoolParameters();

        address lpWrapper = veloDeployFactory
            .poolToAddresses(address(parameters[poolId].pool))
            .lpWrapper;
        address synthetixFarm = veloDeployFactory
            .poolToAddresses(address(parameters[poolId].pool))
            .synthetixFarm;
        if (lpWrapper != address(0)) {
            withdraw(lpWrapper, operatorAddress);
        }

        if (lpWrapper != address(0) || synthetixFarm != address(0)) {
            veloDeployFactory.removeAddressesForPool(
                address(parameters[poolId].pool)
            );
        }

        require(
            parameters[poolId].width % parameters[poolId].pool.tickSpacing() ==
                0,
            "POOL_POSITION_WIDTH is not valid"
        );

        IERC20(parameters[poolId].pool.token0()).approve(
            address(createStrategyHelper),
            type(uint256).max
        );
        IERC20(parameters[poolId].pool.token1()).approve(
            address(createStrategyHelper),
            type(uint256).max
        );

        (
            IVeloDeployFactory.PoolAddresses memory poolAddresses,
            uint256 tokenId
        ) = createStrategyHelper.createStrategy(parameters[poolId]);

        console2.log(
            " =======     POOL ",
            address(parameters[poolId].pool),
            "    ========"
        );
        console2.log("          tokenId:", tokenId);
        console2.log("        lpWrapper:", poolAddresses.lpWrapper);
        console2.log("    synthetixFarm:", poolAddresses.synthetixFarm);
    }
}
