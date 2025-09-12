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
        address lpWrapperOperator;
        uint256 minInitialTotalSupply;
        address factoryOperator;
        address factoryProposer;
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
        ILpStaker lpStakerImplementation;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("admin");
    bytes32 public constant OPERATOR_ROLE = keccak256("operator");
    bytes32 public constant PROPOSER_ROLE = keccak256("proposer");
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
            params.weth
        );
        contracts.core.initialize(
            params.mellowAdmin, params.coreOperator, abi.encode(params.protocolParams)
        );

        contracts.lpWrapperImplementation = new LpWrapper(address(contracts.core));
        contracts.lpStakerImplementation = new LpStaker(address(contracts.core));
        contracts.deployFactory = new VeloDeployFactory(
            contracts.core,
            contracts.strategyModule,
            address(contracts.lpWrapperImplementation),
            address(contracts.lpStakerImplementation)
        );
        contracts.deployFactory.initialize(
            params.mellowAdmin,
            params.factoryOperator,
            params.factoryProposer,
            params.lpWrapperAdmin,
            params.lpWrapperManager,
            params.lpWrapperOperator,
            params.minInitialTotalSupply
        );
    }

    function deployStrategy(CoreDeployment memory contracts, bytes32 proposalId)
        internal
        returns (ILpWrapper)
    {
        return contracts.deployFactory.deployStrategy(proposalId);
    }

    function testDeployScript() internal pure {}
}
