// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../DeployScript.sol";
import "test/Imports.sol";

abstract contract DeployScriptVelo is DeployScript {
    function deployCore(CoreDeploymentParams memory params)
        internal
        override
        returns (CoreDeployment memory contracts)
    {
        contracts.ammModule = new VeloAmmModule(
            INonfungiblePositionManager(params.positionManager), params.isPoolSelector
        );
        contracts.depositWithdrawModule = IAmmDepositWithdrawModule(
            address(
                new VeloDepositWithdrawModule(INonfungiblePositionManager(params.positionManager))
            )
        );
        contracts.oracle = new VeloOracle();
        contracts.strategyModule = new PulseStrategyModule();
        contracts.core = new Core(
            contracts.ammModule,
            contracts.depositWithdrawModule,
            contracts.strategyModule,
            contracts.oracle
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
            params.factoryManager,
            params.factoryProposer,
            params.lpWrapperAdmin,
            params.lpWrapperManager,
            params.lpWrapperOperator,
            params.minInitialTotalSupply
        );
    }

    function deployStrategy(CoreDeployment memory contracts, bytes32 proposalId)
        internal
        override
        returns (ILpWrapper)
    {
        return contracts.deployFactory.deployStrategy(proposalId);
    }

    function testDeployScript() internal pure {}
}
