// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/Imports.sol";

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
        ICore core;
        IVeloAmmModule ammModule;
        IVeloDepositWithdrawModule depositWithdrawModule;
        IVeloOracle oracle;
        IPulseStrategyModule strategyModule;
        IVeloDeployFactory deployFactory;
        ILpWrapper lpWrapperImplementation;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("admin");
    bytes32 public constant OPERATOR = keccak256("operator");
    bytes32 public constant ADMIN_DELEGATE_ROLE = keccak256("admin_delegate");

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

        contracts.core.grantRole(ADMIN_ROLE, params.mellowAdmin);
        if (params.coreOperator != address(0)) {
            contracts.core.grantRole(ADMIN_DELEGATE_ROLE, params.deployer);
            contracts.core.grantRole(OPERATOR, params.coreOperator);
            contracts.core.renounceRole(ADMIN_DELEGATE_ROLE, params.deployer);
        }
        contracts.core.renounceRole(ADMIN_ROLE, params.deployer);
        contracts.core.renounceRole(OPERATOR, params.deployer);

        contracts.deployFactory.grantRole(ADMIN_ROLE, params.mellowAdmin);
        contracts.deployFactory.grantRole(ADMIN_DELEGATE_ROLE, params.deployer);
        contracts.deployFactory.grantRole(OPERATOR, params.factoryOperator);
        contracts.deployFactory.renounceRole(OPERATOR, params.deployer);
        contracts.deployFactory.renounceRole(ADMIN_DELEGATE_ROLE, params.deployer);
        contracts.deployFactory.renounceRole(ADMIN_ROLE, params.deployer);
    }

    function deployStrategy(
        CoreDeployment memory contracts,
        IVeloDeployFactory.DeployParams memory params
    ) internal returns (ILpWrapper) {
        return contracts.deployFactory.createStrategy(params);
    }

    function testDeployScript() internal pure {}
}
