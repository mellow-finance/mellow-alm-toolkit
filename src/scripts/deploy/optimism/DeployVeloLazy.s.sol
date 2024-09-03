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
    0x416b433906b1B72FA758e166e239c43d68dC6F29
);

address constant VELO_FACTORY = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F;
address constant WETH = 0x4200000000000000000000000000000000000006;

contract DeployVeloLazy is Script, Test {
    uint256 STAGE_DEPLOY = 1;

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
    address immutable VELO_DEPLOY_FACTORY_OPERATOR = deployerAddress;

    CreateStrategyHelper createStrategyHelper;
    VeloDeployFactory deployFactory;
    Core core;

    function run() virtual public {
        deployCore();
    }

    function deployCore() internal returns (address veloDeployFactoryAddress, address createStrategyHelperAddress) {
        console.log("Deployer", deployerAddress);

        //vm.startBroadcast(deployerPrivateKey);

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
            core = new Core(ammModule, strategyModule, oracle, deployerAddress);
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
            PulseVeloBotLazy pulseVeloBot = new PulseVeloBotLazy(
                address(NONFUNGIBLE_POSITION_MANAGER),
                address(core)
            );
            console2.log("PulseVeloBotLazy", address(pulseVeloBot));

            //-------------------------------------------------------------------------------
            Compounder compounder = new Compounder(deployerAddress);
            console2.log("Compounder", address(compounder));

            //-------------------------------------------------------------------------------
            deployFactory = new VeloDeployFactory(
                deployerAddress,
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
            createStrategyHelper = new CreateStrategyHelper(
                NONFUNGIBLE_POSITION_MANAGER,
                deployFactory
            );
            console2.log("CreateStrategyHelper", address(createStrategyHelper));
            createStrategyHelperAddress = address(createStrategyHelper);
            deployFactory.grantRole(
                deployFactory.ADMIN_DELEGATE_ROLE(),
                address(createStrategyHelper)
            );

            //-------------------------------------------------------------------------------
            VeloSugarHelper veloSugarHelper = new VeloSugarHelper(
                address(deployFactory)
            );

            console2.log("VeloSugarHelper", address(veloSugarHelper));

        } else {
            _migrateRoles();
        }

        // vm.stopBroadcast();
    }

    function _migrateRoles() private {
        // use addresses form deployment STAGE_DEPLOY == 1
        address coreAddress = address(0);
        address deployFactoryAddress = address(0);
        address createStrategyHelperAddress = address(0);

        core = Core(coreAddress);
        deployFactory = VeloDeployFactory(deployFactoryAddress);

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

        // left rights to deploy new strategies for pools
        //deployFactory.revokeRole(
        //    deployFactory.ADMIN_DELEGATE_ROLE(),
        //    address(createStrategyHelper)
        //);

        deployFactory.revokeRole(deployFactory.ADMIN_ROLE(), deployerAddress);
        require(!deployFactory.isAdmin(deployerAddress));
        //require(!deployFactory.isAdmin(address(createStrategyHelper)));
        require(deployFactory.isAdmin(CORE_ADMIN));

        core.revokeRole(core.ADMIN_DELEGATE_ROLE(), deployerAddress);
        core.revokeRole(core.ADMIN_ROLE(), deployerAddress);
        require(!core.isAdmin(deployerAddress));
        require(core.isAdmin(CORE_ADMIN));
    }
}
