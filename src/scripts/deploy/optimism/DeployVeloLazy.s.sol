// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import "src/helpers/CreateStrategyHelper.sol";
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

        VeloOracle oracle = new VeloOracle();
        oracleAddress = address(oracle);
        console2.log("oracleAddress", oracleAddress);

        PulseStrategyModule strategyModule = new PulseStrategyModule();
        strategyModuleAddress = address(strategyModule);
        console2.log("strategyModuleAddress", strategyModuleAddress);

        VeloDeployFactoryHelper velotrDeployFactoryHelper = new VeloDeployFactoryHelper();
        velotrDeployFactoryHelperAddress = address(velotrDeployFactoryHelper);
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
        veloDepositWithdrawModuleAddress = address(veloDepositWithdrawModule);
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

        _migrateRoles();

        vm.stopBroadcast();
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
