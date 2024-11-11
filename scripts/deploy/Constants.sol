// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./DeployScript.sol";
import "./RebalancingBot.sol";

library Constants {
    address internal constant OPTIMISM_DEPLOYER = address(1);
    address internal constant OPTIMISM_MELLOW_ADMIN = address(2);
    address internal constant OPTIMISM_POSITION_MANAGER = 0x416b433906b1B72FA758e166e239c43d68dC6F29;
    bytes4 internal constant OPTIMISM_IS_POOL_SELECTOR = bytes4(keccak256("isPair(address)"));
    address internal constant OPTIMISM_SWAP_ROUTER = 0x0792a633F0c19c351081CF4B211F68F79bCc9676;

    address internal constant OPTIMISM_OP = 0x4200000000000000000000000000000000000042;
    address internal constant OPTIMISM_WETH = 0x4200000000000000000000000000000000000006;
    address internal constant OPTIMISM_WSTETH = 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;
    address internal constant OPTIMISM_LP_WRAPPER_ADMIN = address(3);
    address internal constant OPTIMISM_LP_WRAPPER_MANAGER = address(0);

    uint256 internal constant OPTIMISM_MIN_INITIAL_TOTAL_SUPPLY = 1000 wei;
    address internal constant OPTIMISM_FACTORY_OPERATOR = address(4);
    address internal constant OPTIMISM_CORE_OPERATOR = address(5);

    address internal constant OPTIMISM_MELLOW_TREASURY = address(6);
    uint32 internal constant OPTIMISM_FEE_D9 = 1e7; // 10% fee

    function getDeploymentParams()
        internal
        view
        returns (DeployScript.CoreDeploymentParams memory)
    {
        if (block.chainid == 10) {
            return DeployScript.CoreDeploymentParams({
                deployer: OPTIMISM_DEPLOYER,
                mellowAdmin: OPTIMISM_MELLOW_ADMIN,
                positionManager: OPTIMISM_POSITION_MANAGER,
                isPoolSelector: OPTIMISM_IS_POOL_SELECTOR,
                weth: OPTIMISM_WETH,
                lpWrapperAdmin: OPTIMISM_LP_WRAPPER_ADMIN,
                lpWrapperManager: OPTIMISM_LP_WRAPPER_MANAGER,
                minInitialTotalSupply: OPTIMISM_MIN_INITIAL_TOTAL_SUPPLY,
                factoryOperator: OPTIMISM_FACTORY_OPERATOR,
                coreOperator: OPTIMISM_CORE_OPERATOR,
                protocolParams: IVeloAmmModule.ProtocolParams({
                    treasury: OPTIMISM_MELLOW_TREASURY,
                    feeD9: OPTIMISM_FEE_D9
                })
            });
        }
        revert("Unsupported chain");
    }

    function testConstants() internal pure {}
}
