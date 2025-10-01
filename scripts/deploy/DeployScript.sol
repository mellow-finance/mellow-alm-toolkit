// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../test/CommonImports.sol";

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
        address factoryManager;
        address factoryProposer;
        // Core
        address coreOperator;
        IVeloAmmModule.ProtocolParams protocolParams;
    }

    struct CoreDeployment {
        ICore core;
        IVeloAmmModule ammModule;
        IAmmDepositWithdrawModule depositWithdrawModule;
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
        virtual
        returns (CoreDeployment memory contracts);

    function deployStrategy(CoreDeployment memory contracts, bytes32 proposalId)
        internal
        virtual
        returns (ILpWrapper);

    function test() internal pure {}
}
