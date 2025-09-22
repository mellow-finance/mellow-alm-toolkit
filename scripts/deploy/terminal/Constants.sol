// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./DeployScript.sol";
import "./RebalancingBot.sol";
import "forge-std/Test.sol";

library Constants {
    address internal constant TERMINAL_DEPLOYER = address(1);
    address internal constant TERMINAL_MELLOW_ADMIN = address(2);
    bytes4 internal constant TERMINAL_IS_POOL_SELECTOR = bytes4(0);

    address internal constant SEPOLIA_POSITION_MANAGER = 0xF0e998b8E2Cc3b989F1351bDCC4f12d336EE83b1;
    address internal constant SEPOLIA_WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;

    uint256 internal constant TERMINAL_MIN_INITIAL_TOTAL_SUPPLY = 1000 wei;

    uint32 internal constant TERMINAL_FEE_D9 = 1e7; // 10% fee

    address internal constant TERMINAL_LP_WRAPPER_ADMIN =
        address(uint160(uint256(keccak256("TERMINAL_LP_WRAPPER_ADMIN"))));
    address internal constant TERMINAL_LP_WRAPPER_MANAGER =
        address(uint160(uint256(keccak256("TERMINAL_LP_WRAPPER_MANAGER"))));
    address internal constant TERMINAL_LP_WRAPPER_OPERATOR =
        address(uint160(uint256(keccak256("TERMINAL_LP_WRAPPER_OPERATOR"))));

    address internal constant TERMINAL_FACTORY_OPERATOR =
        address(uint160(uint256(keccak256("TERMINAL_FACTORY_OPERATOR"))));
    address internal constant TERMINAL_CORE_OPERATOR =
        address(uint160(uint256(keccak256("TERMINAL_CORE_OPERATOR"))));

    address internal constant TERMINAL_MELLOW_TREASURY =
        address(uint160(uint256(keccak256("TERMINAL_MELLOW_TREASURY"))));
    address internal constant TERMINAL_FACTORY_PROPOSER =
        address(uint160(uint256(keccak256("TERMINAL_FACTORY_PROPOSER"))));

    function getDeploymentParams()
        internal
        view
        returns (DeployScript.CoreDeploymentParams memory)
    {
        if (block.chainid == 11155111) {
            return DeployScript.CoreDeploymentParams({
                deployer: TERMINAL_DEPLOYER,
                mellowAdmin: TERMINAL_MELLOW_ADMIN,
                positionManager: SEPOLIA_POSITION_MANAGER,
                isPoolSelector: TERMINAL_IS_POOL_SELECTOR,
                weth: SEPOLIA_WETH,
                lpWrapperAdmin: TERMINAL_LP_WRAPPER_ADMIN,
                lpWrapperManager: TERMINAL_LP_WRAPPER_MANAGER,
                lpWrapperOperator: TERMINAL_LP_WRAPPER_OPERATOR,
                minInitialTotalSupply: TERMINAL_MIN_INITIAL_TOTAL_SUPPLY,
                factoryManager: TERMINAL_FACTORY_OPERATOR,
                factoryProposer: TERMINAL_FACTORY_PROPOSER,
                coreOperator: TERMINAL_CORE_OPERATOR,
                protocolParams: IVeloAmmModule.ProtocolParams({
                    treasury: TERMINAL_MELLOW_TREASURY,
                    feeD9: TERMINAL_FEE_D9,
                    extraData: ""
                })
            });
        }
        revert("Unsupported chain");
    }

    function testConstants() internal pure {}
}
