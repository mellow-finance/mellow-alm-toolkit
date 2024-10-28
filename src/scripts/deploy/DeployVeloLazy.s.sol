// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "./base/Constants.sol";

contract DeployVeloLazy is Script, Test, PoolParameters, Addresses {
    address immutable VELO_DEPLOY_FACTORY_ADMIN = CORE_ADMIN;
    address immutable WRAPPER_ADMIN = CORE_ADMIN;
    address immutable FARM_OWNER = CORE_ADMIN;
    address immutable VELO_DEPLOY_FACTORY_OPERATOR = DEPLOYER;

    function run() public virtual {
        deployCore();
    }

    function deployCore()
        internal
        returns (address veloDeployFactoryAddress, address createStrategyHelperAddress)
    {
        console.log("Deployer", DEPLOYER);
        console.log("Core/deloy factory/wrapper admin and farm owner", CORE_ADMIN);
        console.log("Protocol treasuty", PROTOCOL_TREASURY);
        console.log("Core operator", CORE_OPERATOR);
        console.log("Deploy factory operator", DEPLOYER);

        // vm.startBroadcast(deployerPrivateKey);

        //-------------------------------------------------------------------------------
        oracle = new VeloOracle();
        console2.log("VeloOracle", address(oracle));

        //-------------------------------------------------------------------------------
        strategyModule = new PulseStrategyModule();
        console2.log("PulseStrategyModule", address(strategyModule));

        //-------------------------------------------------------------------------------
        velotrDeployFactoryHelper = new VeloDeployFactoryHelper(Constants.WETH);
        console2.log("VeloDeployFactoryHelper", address(velotrDeployFactoryHelper));

        //-------------------------------------------------------------------------------
        ammModule = new VeloAmmModule(
            INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER),
            Constants.SELECTOR_IS_POOL
        );
        console2.log("VeloAmmModule", address(ammModule));

        //-------------------------------------------------------------------------------
        veloDepositWithdrawModule = new VeloDepositWithdrawModule(
            INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER)
        );
        console2.log("VeloDepositWithdrawModule", address(veloDepositWithdrawModule));

        //-------------------------------------------------------------------------------
        core = new Core(ammModule, strategyModule, oracle, DEPLOYER);
        console2.log("Core", address(core));

        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    feeD9: Constants.PROTOCOL_FEE_D9,
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
            velotrDeployFactoryHelper,
            IVeloFactoryDeposit(address(0))
        );
        console2.log("VeloDeployFactory", address(deployFactory));
        veloDeployFactoryAddress = address(deployFactory);

        deployFactory.updateMutableParams(
            IVeloDeployFactory.MutableParams({
                lpWrapperAdmin: WRAPPER_ADMIN,
                lpWrapperManager: address(0),
                farmOwner: FARM_OWNER,
                farmOperator: address(compounder),
                minInitialLiquidity: Constants.MIN_INITIAL_LIQUDITY
            })
        );

        //-------------------------------------------------------------------------------
        pulseVeloBot = new PulseVeloBotLazy(
            Constants.NONFUNGIBLE_POSITION_MANAGER, address(core), address(deployFactory)
        );
        console2.log("PulseVeloBotLazy", address(pulseVeloBot));

        //-------------------------------------------------------------------------------
        /* createStrategyHelper = new CreateStrategyHelper(
            address(deployFactory),
            VELO_DEPLOY_FACTORY_OPERATOR
        );
        console2.log("CreateStrategyHelper", address(createStrategyHelper));
        createStrategyHelperAddress = address(createStrategyHelper); */

        //-------------------------------------------------------------------------------
        veloSugarHelper = new VeloSugarHelper(address(deployFactory));

        console2.log("VeloSugarHelper", address(veloSugarHelper));

        _setRoles();

        // vm.stopBroadcast();
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

        deployFactory.grantRole(deployFactory.OPERATOR(), VELO_DEPLOY_FACTORY_OPERATOR);

        deployFactory.grantRole(deployFactory.ADMIN_ROLE(), VELO_DEPLOY_FACTORY_ADMIN);

        // grant rights to deploy strategies for new pools
        /*         deployFactory.grantRole(
            deployFactory.OPERATOR(),
            address(createStrategyHelper)
        );
        */
        deployFactory.revokeRole(deployFactory.ADMIN_DELEGATE_ROLE(), DEPLOYER);

        core.revokeRole(core.ADMIN_DELEGATE_ROLE(), DEPLOYER);
        core.revokeRole(core.ADMIN_ROLE(), DEPLOYER);

        deployFactory.revokeRole(deployFactory.ADMIN_ROLE(), DEPLOYER);

        require(!core.isAdmin(DEPLOYER));
        require(core.isAdmin(CORE_ADMIN));
        require(core.isOperator(CORE_OPERATOR));

        require(!deployFactory.isAdmin(DEPLOYER));
        //    require(!deployFactory.isAdmin(address(createStrategyHelper)));
        //    require(deployFactory.isOperator(address(createStrategyHelper)));

        require(deployFactory.isAdmin(CORE_ADMIN));
        require(deployFactory.isOperator(VELO_DEPLOY_FACTORY_OPERATOR));
    }
}
