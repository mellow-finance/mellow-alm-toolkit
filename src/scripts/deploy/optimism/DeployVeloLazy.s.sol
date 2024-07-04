// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import "./CreateStrategyHelper.sol";
import "src/Core.sol";
import "src/bots/PulseVeloBot.sol";
import "src/modules/velo/VeloAmmModule.sol";
import "src/modules/velo/VeloDepositWithdrawModule.sol";
import "src/modules/strategies/PulseStrategyModule.sol";
import "src/oracles/VeloOracle.sol";
import "src/utils/VeloDeployFactoryHelper.sol";
import "src/utils/VeloDeployFactory.sol";
import "src/interfaces/external/velo/external/IWETH9.sol";

uint128 constant MIN_INITIAL_LIQUDITY = 1000;
uint32 constant PROTOCOL_FEE_D9 = 1e8; // 10%

INonfungiblePositionManager constant NONFUNGIBLE_POSITION_MANAGER = INonfungiblePositionManager(
    0x416b433906b1B72FA758e166e239c43d68dC6F29
);

address constant VELO_FACTORY = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F;
IQuoterV2 constant QUOTER_V2 = IQuoterV2(
    0xA2DEcF05c16537C702779083Fe067e308463CE45
);
ISwapRouter constant SWAP_ROUTER = ISwapRouter(
    0x5F9a4bb5d3b0c5e233Ee3cB35701077504a6F0eb
);
address constant USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
address constant WETH = 0x4200000000000000000000000000000000000006;
address constant OP = 0x4200000000000000000000000000000000000042;
address constant WSTETH = 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;
address constant USDT = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;
address constant SUSD = 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9;
address constant USDCe = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
address constant EZETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
address constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

contract Deploy is Script, Test {
    uint256 STAGE_DEPLOY = 2;

    address coreAddress;
    address deployFactoryAddress;
    address oracleAddress;
    address strategyModuleAddress;
    address velotrDeployFactoryHelperAddress;
    address ammModuleAddress;
    address veloDepositWithdrawModuleAddress;
    address pulseVeloBotAddress;

    uint256 nonceDeployer;
    uint256 immutable deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address immutable deployerAddress = vm.addr(deployerPrivateKey);
    address immutable CORE_ADMIN = 0x379Ea012582A33AB78Feb34474Df7aD6Dc39F178; // msig
    address immutable PROTOCOL_TREASURY =
        0x0da6d939Cb0555A0D2eB99E310eBAE68432F31F2; // msig
    address immutable CORE_OPERATOR =
        0x9DFb1fC83EB81F99ACb008c49384c4446F2313Ed; // bot eoa

    address immutable VELO_DEPLOY_FACTORY_ADMIN = CORE_ADMIN;
    address immutable WRAPPER_ADMIN = CORE_ADMIN;
    address immutable FARM_OWNER = CORE_ADMIN;
    address immutable FARM_OPERATOR = CORE_OPERATOR;
    address immutable VELO_DEPLOY_FACTORY_OPERATOR = deployerAddress;

    CreateStrategyHelper createStrategyHelper;
    VeloDeployFactory deployFactory;
    Core core;

    function run() public {
        console.log("Deployer address:", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

        if (STAGE_DEPLOY == 0) {
            VeloOracle oracle = new VeloOracle();
            oracleAddress = address(oracle);
            console2.log("oracleAddress", oracleAddress);

            PulseStrategyModule strategyModule = new PulseStrategyModule();
            strategyModuleAddress = address(strategyModule);
            console2.log("strategyModuleAddress", strategyModuleAddress);

            VeloDeployFactoryHelper velotrDeployFactoryHelper = new VeloDeployFactoryHelper();
            velotrDeployFactoryHelperAddress = address(
                velotrDeployFactoryHelper
            );
            console2.log(
                "velotrDeployFactoryHelperAddress",
                velotrDeployFactoryHelperAddress
            );

            VeloAmmModule ammModule = new VeloAmmModule(
                NONFUNGIBLE_POSITION_MANAGER
            );
            ammModuleAddress = address(ammModule);
            console2.log("ammModuleAddress", ammModuleAddress);

            VeloDepositWithdrawModule veloDepositWithdrawModule = new VeloDepositWithdrawModule(
                    NONFUNGIBLE_POSITION_MANAGER
                );
            veloDepositWithdrawModuleAddress = address(
                veloDepositWithdrawModule
            );
            console2.log(
                "veloDepositWithdrawModuleAddress",
                veloDepositWithdrawModuleAddress
            );

            PulseVeloBot pulseVeloBot = new PulseVeloBot(
                QUOTER_V2,
                SWAP_ROUTER,
                NONFUNGIBLE_POSITION_MANAGER
            );
            pulseVeloBotAddress = address(pulseVeloBot);
            console2.log("pulseVeloBotAddress", pulseVeloBotAddress);

            core = new Core(ammModule, strategyModule, oracle, deployerAddress);
            coreAddress = address(core);
            console2.log("coreAddress", coreAddress);

            core.setProtocolParams(
                abi.encode(
                    IVeloAmmModule.ProtocolParams({
                        feeD9: PROTOCOL_FEE_D9,
                        treasury: PROTOCOL_TREASURY
                    })
                )
            );

            core.setOperatorFlag(true);

            deployFactory = new VeloDeployFactory(
                deployerAddress,
                core,
                veloDepositWithdrawModule,
                velotrDeployFactoryHelper
            );
            deployFactoryAddress = address(deployFactory);
            console2.log("deployFactoryAddress", deployFactoryAddress);

            deployFactory.updateMutableParams(
                IVeloDeployFactory.MutableParams({
                    lpWrapperAdmin: WRAPPER_ADMIN,
                    lpWrapperManager: address(0),
                    farmOwner: FARM_OWNER,
                    farmOperator: FARM_OPERATOR,
                    minInitialLiquidity: MIN_INITIAL_LIQUDITY
                })
            );
            createStrategyHelper = new CreateStrategyHelper(
                NONFUNGIBLE_POSITION_MANAGER,
                deployFactory,
                deployerAddress
            );
            deployFactory.grantRole(
                deployFactory.ADMIN_DELEGATE_ROLE(),
                address(createStrategyHelper)
            );
        }
        /*
                    VELO_FACTORY = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F

                                               address wdth  TS   t0       t1 maxAllowedDelta 
            0x478946BcD4a5a22b316470F5486fAfb928C0bA25 4000 100 usdc     weth              50 +
            0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60 6000 200 weth       op              50 +
            0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4    1   1 wsteth   weth               1 + 
            0x84Ce89B4f6F67E523A81A82f9f2F14D84B726F6B    1   1 usdc     usdt               1 + 
            0x3C01ec09D15D5450FC702DC4353b17Cd2978d8a5    1   1 usdc     susd               1 + 
            0xEE1baC98527a9fDd57fcCf967817215B083cE1F0 4000 100 usdc   wsteth              50 +
            0x2FA71491F8070FA644d97b4782dB5734854c0f6F    1   1 usdc   usdc.e               1 +
            0xeBD5311beA1948e1441333976EadCFE5fBda777C 6000 200 usdc       op              50 +
            0x1737275d53A5Ca5dAc582a493AA32C85ba2cFaD3    1   1 usdc      dai               1 +
            0xb71Ac980569540cE38195b38369204ff555C80BE    1   1 wsteth  ezeth               1 -
        */
        else if (STAGE_DEPLOY == 1) {
            core = Core(0x21017CeCE935974a269D6b3E41331fB80c373413);
            deployFactory = VeloDeployFactory(
                0xB2E8811465832C1dD67487de149d7317DD84565F
            );
            CreateStrategyHelper.PoolParameter[10] memory poolParameter;
            poolParameter[0] = CreateStrategyHelper.PoolParameter({
                factory: ICLFactory(VELO_FACTORY),
                pool: ICLPool(0x478946BcD4a5a22b316470F5486fAfb928C0bA25),
                width: 40,
                tickSpacing: 100,
                token0: USDC,
                token1: WETH
            });

            poolParameter[1] = CreateStrategyHelper.PoolParameter({
                factory: ICLFactory(VELO_FACTORY),
                pool: ICLPool(0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60),
                width: 30,
                tickSpacing: 200,
                token0: WETH,
                token1: OP
            });

            poolParameter[2] = CreateStrategyHelper.PoolParameter({
                factory: ICLFactory(VELO_FACTORY),
                pool: ICLPool(0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4),
                width: 1,
                tickSpacing: 1,
                token0: WSTETH,
                token1: WETH
            });

            poolParameter[3] = CreateStrategyHelper.PoolParameter({
                factory: ICLFactory(VELO_FACTORY),
                pool: ICLPool(0x84Ce89B4f6F67E523A81A82f9f2F14D84B726F6B),
                width: 1,
                tickSpacing: 1,
                token0: USDC,
                token1: USDT
            });

            poolParameter[4] = CreateStrategyHelper.PoolParameter({
                factory: ICLFactory(VELO_FACTORY),
                pool: ICLPool(0x3C01ec09D15D5450FC702DC4353b17Cd2978d8a5),
                width: 1,
                tickSpacing: 1,
                token0: USDC,
                token1: SUSD
            });

            poolParameter[5] = CreateStrategyHelper.PoolParameter({
                factory: ICLFactory(VELO_FACTORY),
                pool: ICLPool(0xEE1baC98527a9fDd57fcCf967817215B083cE1F0),
                width: 40,
                tickSpacing: 100,
                token0: USDC,
                token1: WSTETH
            });

            poolParameter[6] = CreateStrategyHelper.PoolParameter({
                factory: ICLFactory(VELO_FACTORY),
                pool: ICLPool(0x2FA71491F8070FA644d97b4782dB5734854c0f6F),
                width: 1,
                tickSpacing: 1,
                token0: USDC,
                token1: USDCe
            });

            poolParameter[7] = CreateStrategyHelper.PoolParameter({
                factory: ICLFactory(VELO_FACTORY),
                pool: ICLPool(0xeBD5311beA1948e1441333976EadCFE5fBda777C),
                width: 30,
                tickSpacing: 200,
                token0: USDC,
                token1: OP
            });

            poolParameter[8] = CreateStrategyHelper.PoolParameter({
                factory: ICLFactory(VELO_FACTORY),
                pool: ICLPool(0x1737275d53A5Ca5dAc582a493AA32C85ba2cFaD3),
                width: 1,
                tickSpacing: 1,
                token0: USDC,
                token1: DAI
            });

            poolParameter[9] = CreateStrategyHelper.PoolParameter({
                factory: ICLFactory(VELO_FACTORY),
                pool: ICLPool(0xb71Ac980569540cE38195b38369204ff555C80BE),
                width: 1,
                tickSpacing: 1,
                token0: WSTETH,
                token1: EZETH
            });

            createStrategyHelper = CreateStrategyHelper(
                0x76da00F690F4C02459A7633AC27397AbdbbDc344
            );

            for (uint i = 7; i < poolParameter.length - 1; i++) {
                IERC20(poolParameter[i].token0).approve(
                    address(createStrategyHelper),
                    type(uint256).max
                );
                IERC20(poolParameter[i].token1).approve(
                    address(createStrategyHelper),
                    type(uint256).max
                );
                createStrategyHelper.createStrategy(poolParameter[i]);
            }
        } else if (STAGE_DEPLOY == 2) {
            core = Core(0x21017CeCE935974a269D6b3E41331fB80c373413);
            deployFactory = VeloDeployFactory(
                0xB2E8811465832C1dD67487de149d7317DD84565F
            );
            _migrateRoles();
        }

        vm.stopBroadcast();
    }

    function _init(
        CreateStrategyHelper.PoolParameter memory poolParameter
    ) private {
        IERC20 token0 = IERC20(poolParameter.token0);
        IERC20 token1 = IERC20(poolParameter.token1);
        token0.approve(address(poolParameter.pool), type(uint256).max);
        token0.approve(
            address(NONFUNGIBLE_POSITION_MANAGER),
            type(uint256).max
        );
        token1.approve(address(poolParameter.pool), type(uint256).max);
        token1.approve(
            address(NONFUNGIBLE_POSITION_MANAGER),
            type(uint256).max
        );
    }

    function _migrateRoles() private {
        core.grantRole(core.ADMIN_DELEGATE_ROLE(), deployerAddress);
        core.grantRole(core.OPERATOR(), CORE_OPERATOR);
        core.grantRole(core.ADMIN_ROLE(), CORE_ADMIN);

        deployFactory.grantRole(
            deployFactory.ADMIN_DELEGATE_ROLE(),
            deployerAddress
        );

        deployFactory.grantRole(
            deployFactory.OPERATOR(),
            VELO_DEPLOY_FACTORY_OPERATOR
        );

        deployFactory.grantRole(
            deployFactory.ADMIN_ROLE(),
            VELO_DEPLOY_FACTORY_ADMIN
        );

        deployFactory.revokeRole(
            deployFactory.ADMIN_DELEGATE_ROLE(),
            deployerAddress
        );
        deployFactory.revokeRole(
            deployFactory.ADMIN_DELEGATE_ROLE(),
            address(createStrategyHelper)
        );
        deployFactory.revokeRole(deployFactory.ADMIN_ROLE(), deployerAddress);
        require(!deployFactory.isAdmin(deployerAddress));
        require(!deployFactory.isAdmin(address(createStrategyHelper)));
        require(deployFactory.isAdmin(CORE_ADMIN));

        core.revokeRole(core.ADMIN_DELEGATE_ROLE(), deployerAddress);
        core.revokeRole(core.ADMIN_ROLE(), deployerAddress);
        require(!core.isAdmin(deployerAddress));
        require(core.isAdmin(CORE_ADMIN));
    }
}
