// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";
import "./Constants.sol";
import "./Pools.sol";

abstract contract DeployScript {
    struct CoreDeploymentParams {
        address deployer;
        // Constructor params
        address mellowAdmin;
        address positionManager;
        bytes4 isPoolSelector;
        address weth;
        // Mutable params:
        // VeloDeployFactory
        address lpWrapperAdmin;
        address lpWrapperManager;
        uint256 minInitialTotalSupply;
        address factoryOperator;
        // Core
        address coreOperator;
        IVeloAmmModule.ProtocolParams protocolParams;
    }

    struct CoreDeployment {
        Core core;
        IVeloAmmModule ammModule;
        IVeloDepositWithdrawModule depositWithdrawModule;
        IVeloOracle oracle;
        IPulseStrategyModule strategyModule;
        VeloDeployFactory deployFactory;
        ILpWrapper lpWrapperImplementation;
    }

    function deployCore(CoreDeploymentParams memory params)
        internal
        returns (CoreDeployment memory contracts)
    {
        contracts.ammModule = new VeloAmmModule(
            INonfungiblePositionManager(params.positionManager), params.isPoolSelector
        );
        contracts.depositWithdrawModule =
            new VeloDepositWithdrawModule(INonfungiblePositionManager(params.positionManager));
        contracts.oracle = new VeloOracle();
        contracts.strategyModule = new PulseStrategyModule();
        contracts.core = new Core(
            contracts.ammModule,
            contracts.depositWithdrawModule,
            contracts.strategyModule,
            contracts.oracle,
            params.deployer,
            params.weth
        );
        contracts.lpWrapperImplementation = new LpWrapper(address(contracts.core));
        contracts.deployFactory = new VeloDeployFactory(
            params.deployer,
            contracts.core,
            contracts.strategyModule,
            address(contracts.lpWrapperImplementation)
        );

        contracts.core.setProtocolParams(abi.encode(params.protocolParams));

        contracts.deployFactory.setLpWrapperAdmin(params.lpWrapperAdmin);
        contracts.deployFactory.setLpWrapperManager(params.lpWrapperManager);
        contracts.deployFactory.setMinInitialTotalSupply(params.minInitialTotalSupply);

        {
            bytes32 ADMIN_ROLE = contracts.core.ADMIN_ROLE();
            bytes32 ADMIN_DELEGATE_ROLE = contracts.core.ADMIN_DELEGATE_ROLE();
            bytes32 OPERATOR = contracts.core.OPERATOR();

            contracts.core.grantRole(ADMIN_ROLE, params.mellowAdmin);
            if (params.coreOperator != address(0)) {
                contracts.core.grantRole(ADMIN_DELEGATE_ROLE, params.deployer);
                contracts.core.grantRole(OPERATOR, params.coreOperator);
                contracts.core.renounceRole(ADMIN_DELEGATE_ROLE, params.deployer);
            }
            contracts.core.renounceRole(ADMIN_ROLE, params.deployer);
            contracts.core.renounceRole(OPERATOR, params.deployer);
        }
        {
            bytes32 ADMIN_ROLE = contracts.deployFactory.ADMIN_ROLE();
            bytes32 ADMIN_DELEGATE_ROLE = contracts.deployFactory.ADMIN_DELEGATE_ROLE();
            bytes32 OPERATOR = contracts.deployFactory.OPERATOR();

            contracts.deployFactory.grantRole(ADMIN_ROLE, params.mellowAdmin);
            contracts.deployFactory.grantRole(ADMIN_DELEGATE_ROLE, params.deployer);
            contracts.deployFactory.grantRole(OPERATOR, params.factoryOperator);
            contracts.deployFactory.renounceRole(OPERATOR, params.deployer);
            contracts.deployFactory.renounceRole(ADMIN_DELEGATE_ROLE, params.deployer);
            contracts.deployFactory.renounceRole(ADMIN_ROLE, params.deployer);
        }
    }
    
    function deployStrategy(
        CoreDeployment memory contracts,
        IVeloDeployFactory.DeployParams memory params
    ) internal returns (ILpWrapper) {

        try contracts.deployFactory.createStrategy(params) returns (ILpWrapper lpWrapper) {
            return lpWrapper;
        } catch {
            return ILpWrapper(address(0));
        }
    }

    function testDeployScript() internal pure {}
}

contract Deploy is Script, DeployScript {

    uint256 immutable deployerPrivateKey = vm.envUint("TEST_DEPLOYER_PRIVATE_KEY");
    address immutable DEPLOYER = vm.addr(deployerPrivateKey);
    uint256 immutable operatorPrivateKey = vm.envUint("TEST_OPERATOR_PRIVATE_KEY");
    address immutable OPERATOR = vm.addr(operatorPrivateKey);
    
    function run() external {
        CoreDeploymentParams memory coreDeploymentParams = Constants.getDeploymentParams();
        
        vm.startBroadcast(deployerPrivateKey);
        CoreDeployment memory contracts = deployCore(coreDeploymentParams);
        vm.stopBroadcast();
        console2.log("----------- Mellow ALM deployment addresses at chain ID", block.chainid, "-----------");
        console2.log("                     Core: ", address(contracts.core));
        console2.log("        VeloDeployFactory: ", address(contracts.deployFactory));
        console2.log("      PulseStrategyModule: ", address(contracts.strategyModule));
        console2.log("                LpWrapper: ", address(contracts.lpWrapperImplementation));
        console2.log("            VeloAmmModule: ", address(contracts.ammModule));
        console2.log("VeloDepositWithdrawModule: ", address(contracts.depositWithdrawModule));
        console2.log("               VeloOracle: ", address(contracts.oracle));

        require(OPERATOR == coreDeploymentParams.factoryOperator);

        vm.startBroadcast(operatorPrivateKey);
        deployStrategies(contracts);
        vm.stopBroadcast();
        
        //revert("success");
    }

    function deployStrategies(CoreDeployment memory contracts) internal {
        IVeloDeployFactory.DeployParams[] memory params = PoolParameters.getPoolDeployParams();

        for (uint i = 0; i < params.length; i++) {
            IERC20(params[i].pool.token0()).approve(address(contracts.deployFactory), params[i].maxAmount0);
            IERC20(params[i].pool.token1()).approve(address(contracts.deployFactory), params[i].maxAmount1);
            ILpWrapper lpWrapper = deployStrategy(contracts, params[i]);

            //console2.log("     pool", address(params[i].pool));
            console2.log(" Pool/LpWrapper addresses: ", address(params[i].pool), address(lpWrapper));
        }
    }
}