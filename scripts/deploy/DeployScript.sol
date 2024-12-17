// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Pools.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

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

        // -----------------------------------------
        
        address create2DeterministicDeployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        bytes32 salt;
        bytes memory bytecode = abi.encodePacked(
                type(Core).creationCode,
                abi.encode(
                    contracts.ammModule,
                    contracts.depositWithdrawModule,
                    contracts.strategyModule,
                    contracts.oracle,
                    params.deployer,
                    params.weth
                )
            );
        bytes32 byteCodeHash = keccak256(bytecode);
        address predictedCoreAddress;
        /* /// @dev salt selection loop
          for (uint256 i = 200 * 1e6; i < 400 * 1e6; i++) {
            predictedCoreAddress =
                Create2.computeAddress(bytes32(i), byteCodeHash, create2DeterministicDeployer);
            if (uint160(predictedCoreAddress) >> 136 == 0) {
                console2.log(predictedCoreAddress, i);
            }
        }
         revert("done");  
         */
    
        salt = bytes32(uint256(73465884)); // 0x000000006eB39f786Be5A299c8dAdf37dC8115d9
        predictedCoreAddress =
                Create2.computeAddress(salt, byteCodeHash, create2DeterministicDeployer);

        console2.log("Predicted Core address:", predictedCoreAddress);
        address deployed = Create2.deploy(0, salt, bytecode);
        console2.log("Deployed  Core address:", deployed);
        contracts.core = Core(payable(deployed));
        //------------------------------------------

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
    uint256 immutable deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address immutable DEPLOYER = vm.addr(deployerPrivateKey);
    uint256 immutable operatorPrivateKey = vm.envUint("OPERATOR_PRIVATE_KEY");
    address immutable OPERATOR = vm.addr(operatorPrivateKey);
    uint256 immutable factoryPrivateKey = vm.envUint("FACTORY_OPERATOR_PRIVATE_KEY");
    address immutable FACTORY_OPERATOR = vm.addr(factoryPrivateKey);

    function run() external {
        CoreDeploymentParams memory coreDeploymentParams = Constants.getDeploymentParams();

        vm.startBroadcast(deployerPrivateKey);
        CoreDeployment memory contracts = deployCore(coreDeploymentParams);
        vm.stopBroadcast();
        console2.log(
            "----------- Mellow ALM deployment addresses at chain ID", block.chainid, "-----------"
        );
        console2.log("                     Core: ", address(contracts.core));
        console2.log("        VeloDeployFactory: ", address(contracts.deployFactory));
        console2.log("      PulseStrategyModule: ", address(contracts.strategyModule));
        console2.log("                LpWrapper: ", address(contracts.lpWrapperImplementation));
        console2.log("            VeloAmmModule: ", address(contracts.ammModule));
        console2.log("VeloDepositWithdrawModule: ", address(contracts.depositWithdrawModule));
        console2.log("               VeloOracle: ", address(contracts.oracle));

        require(OPERATOR == coreDeploymentParams.coreOperator);
        require(FACTORY_OPERATOR == coreDeploymentParams.factoryOperator);

        revert("success");
/*         vm.startBroadcast(factoryPrivateKey);
        deployStrategies(contracts);
        vm.stopBroadcast();
 */
    }

    function deployStrategies(CoreDeployment memory contracts) internal {
        IVeloDeployFactory.DeployParams[] memory params =
            PoolParameters.getPoolDeployParams(contracts);

        for (uint256 i = 0; i < params.length; i++) {
            (,,, uint16 observationCardinality,,) = params[i].pool.slot0();
            params[i].pool.increaseObservationCardinalityNext(100);
            if (observationCardinality < params[i].securityParams.lookback) {
                params[i].pool.increaseObservationCardinalityNext(params[i].securityParams.lookback);
            }
            IERC20(params[i].pool.token0()).approve(
                address(contracts.deployFactory), params[i].maxAmount0
            );
            IERC20(params[i].pool.token1()).approve(
                address(contracts.deployFactory), params[i].maxAmount1
            );
            ILpWrapper lpWrapper = deployStrategy(contracts, params[i]);

            //console2.log("     pool", address(params[i].pool));
            console2.log("Pool/LpWrapper addresses: ", address(params[i].pool), address(lpWrapper));
        }
    }
}
