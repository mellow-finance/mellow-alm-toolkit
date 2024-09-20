// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import "src/helpers/CreateStrategyHelper.sol";
import "src/Core.sol";
import "src/bots/PulseVeloBotLazy.sol";
import "src/modules/velo/VeloAmmModule.sol";
import "src/modules/velo/VeloDepositWithdrawModule.sol";
import "src/modules/strategies/PulseStrategyModule.sol";
import "src/oracles/VeloOracle.sol";
import "src/utils/VeloDeployFactoryHelper.sol";
import "src/utils/VeloDeployFactory.sol";
import "src/utils/VeloSugarHelper.sol";
import "src/utils/Compounder.sol";

uint128 constant MIN_INITIAL_LIQUDITY = 1000;
uint32 constant PROTOCOL_FEE_D9 = 1e8; // 10%

INonfungiblePositionManager constant NONFUNGIBLE_POSITION_MANAGER = INonfungiblePositionManager(
    0x827922686190790b37229fd06084350E74485b72
);

address constant VELO_FACTORY = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;
address constant WETH = 0x4200000000000000000000000000000000000006;

contract DeployVeloLazy is Script, Test {
    uint256 STAGE_DEPLOY = 1;

    uint256 immutable deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address immutable DEPLOYER = vm.addr(deployerPrivateKey);
    address immutable CORE_ADMIN = 0x893df22649247AD4e57E4926731F9Cf0dA344829; // protocol msig
    address immutable PROTOCOL_TREASURY =
        0xf0E36e9186Dbe927505d2588a6E6D56083Dd4a56; // treasury msig
    address immutable CORE_OPERATOR =
        0x0A16Bc694EeA56cbFc808a271178556d3f8c23aD; // bot eoa

    address immutable VELO_DEPLOY_FACTORY_ADMIN = CORE_ADMIN;
    address immutable WRAPPER_ADMIN = CORE_ADMIN;
    address immutable FARM_OWNER = CORE_ADMIN;
    address immutable VELO_DEPLOY_FACTORY_OPERATOR = DEPLOYER;

    CreateStrategyHelper createStrategyHelper;
    VeloDeployFactory deployFactory;
    Compounder compounder;
    Core core;

    function run() public virtual {
        deployCore();
    }

    function deployCore()
        internal
        returns (
            address veloDeployFactoryAddress,
            address createStrategyHelperAddress
        )
    {
        console.log("Deployer", DEPLOYER);
        console.log(
            "Core/deloy factory/wrapper admin and farm owner",
            CORE_ADMIN
        );
        console.log("Protocol treasuty", PROTOCOL_TREASURY);
        console.log("Core operator", CORE_OPERATOR);
        console.log("Deploy factory operator", DEPLOYER);

        vm.startBroadcast(deployerPrivateKey);

        if (STAGE_DEPLOY == 1) {
            //-------------------------------------------------------------------------------
            VeloOracle oracle = new VeloOracle();
            console2.log("VeloOracle", address(oracle));

            //-------------------------------------------------------------------------------
            PulseStrategyModule strategyModule = new PulseStrategyModule();
            console2.log("PulseStrategyModule", address(strategyModule));

            //-------------------------------------------------------------------------------
            VeloDeployFactoryHelper velotrDeployFactoryHelper = new VeloDeployFactoryHelper(
                    WETH
                );
            console2.log(
                "VeloDeployFactoryHelper",
                address(velotrDeployFactoryHelper)
            );

            //-------------------------------------------------------------------------------
            VeloAmmModule ammModule = new VeloAmmModule(
                NONFUNGIBLE_POSITION_MANAGER
            );
            console2.log("VeloAmmModule", address(ammModule));

            //-------------------------------------------------------------------------------
            VeloDepositWithdrawModule veloDepositWithdrawModule = new VeloDepositWithdrawModule(
                    NONFUNGIBLE_POSITION_MANAGER
                );
            console2.log(
                "VeloDepositWithdrawModule",
                address(veloDepositWithdrawModule)
            );

            //-------------------------------------------------------------------------------
            core = new Core(ammModule, strategyModule, oracle, DEPLOYER);
            console2.log("Core", address(core));

            core.setProtocolParams(
                abi.encode(
                    IVeloAmmModule.ProtocolParams({
                        feeD9: PROTOCOL_FEE_D9,
                        treasury: PROTOCOL_TREASURY
                    })
                )
            );

            core.setOperatorFlag(true);

            //-------------------------------------------------------------------------------
            compounder = new Compounder(DEPLOYER);
            console2.log("Compounder", address(compounder));

            //-------------------------------------------------------------------------------
            deployFactory = new VeloDeployFactory(
                DEPLOYER,
                core,
                veloDepositWithdrawModule,
                velotrDeployFactoryHelper
            );
            console2.log("VeloDeployFactory", address(deployFactory));
            veloDeployFactoryAddress = address(deployFactory);

            deployFactory.updateMutableParams(
                IVeloDeployFactory.MutableParams({
                    lpWrapperAdmin: WRAPPER_ADMIN,
                    lpWrapperManager: address(0),
                    farmOwner: FARM_OWNER,
                    farmOperator: address(compounder),
                    minInitialLiquidity: MIN_INITIAL_LIQUDITY
                })
            );

            //-------------------------------------------------------------------------------
            PulseVeloBotLazy pulseVeloBot = new PulseVeloBotLazy(
                address(NONFUNGIBLE_POSITION_MANAGER),
                address(core),
                address(deployFactory)
            );
            console2.log("PulseVeloBotLazy", address(pulseVeloBot));

            //-------------------------------------------------------------------------------
            createStrategyHelper = new CreateStrategyHelper(
                address(deployFactory),
                VELO_DEPLOY_FACTORY_OPERATOR
            );
            console2.log("CreateStrategyHelper", address(createStrategyHelper));
            createStrategyHelperAddress = address(createStrategyHelper);

            //-------------------------------------------------------------------------------
            VeloSugarHelper veloSugarHelper = new VeloSugarHelper(
                address(deployFactory)
            );

            console2.log("VeloSugarHelper", address(veloSugarHelper));

            _setRoles();
        }

        vm.stopBroadcast();
    }

    function _setRoles() private {
        compounder.grantRole(compounder.ADMIN_DELEGATE_ROLE(), DEPLOYER);
        compounder.grantRole(compounder.OPERATOR(), CORE_OPERATOR);
        compounder.grantRole(compounder.ADMIN_ROLE(), CORE_ADMIN);
        compounder.renounceRole(compounder.OPERATOR(), DEPLOYER);
        compounder.renounceRole(compounder.ADMIN_DELEGATE_ROLE(), DEPLOYER);
        compounder.renounceRole(compounder.ADMIN_ROLE(), DEPLOYER);

        core.grantRole(core.ADMIN_DELEGATE_ROLE(), DEPLOYER);
        core.grantRole(core.OPERATOR(), CORE_OPERATOR);
        core.grantRole(core.ADMIN_ROLE(), CORE_ADMIN);

        deployFactory.grantRole(deployFactory.ADMIN_DELEGATE_ROLE(), DEPLOYER);

        deployFactory.grantRole(
            deployFactory.OPERATOR(),
            VELO_DEPLOY_FACTORY_OPERATOR
        );

        deployFactory.grantRole(
            deployFactory.ADMIN_ROLE(),
            VELO_DEPLOY_FACTORY_ADMIN
        );

        // grant rights to deploy strategies for new pools
        deployFactory.grantRole(
            deployFactory.OPERATOR(),
            address(createStrategyHelper)
        );

        deployFactory.revokeRole(deployFactory.ADMIN_DELEGATE_ROLE(), DEPLOYER);

        core.revokeRole(core.ADMIN_DELEGATE_ROLE(), DEPLOYER);
        core.revokeRole(core.ADMIN_ROLE(), DEPLOYER);

        deployFactory.revokeRole(deployFactory.ADMIN_ROLE(), DEPLOYER);

        require(!core.isAdmin(DEPLOYER));
        require(core.isAdmin(CORE_ADMIN));
        require(core.isOperator(CORE_OPERATOR));

        require(!deployFactory.isAdmin(DEPLOYER));
        require(!deployFactory.isAdmin(address(createStrategyHelper)));
        require(deployFactory.isOperator(address(createStrategyHelper)));

        require(deployFactory.isAdmin(CORE_ADMIN));
        require(deployFactory.isOperator(VELO_DEPLOY_FACTORY_OPERATOR));
    }
}
