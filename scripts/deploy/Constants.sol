// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./DeployScript.sol";
import "./RebalancingBot.sol";
import "forge-std/Test.sol";

library Constants {
    address internal constant OPTIMISM_DEPLOYER = address(1);
    address internal constant OPTIMISM_MELLOW_ADMIN = address(2);
    address internal constant OPTIMISM_POSITION_MANAGER = 0x416b433906b1B72FA758e166e239c43d68dC6F29;
    bytes4 internal constant OPTIMISM_IS_POOL_SELECTOR = bytes4(keccak256("isPair(address)"));
    address internal constant OPTIMISM_SWAP_ROUTER = 0x0792a633F0c19c351081CF4B211F68F79bCc9676;

    address internal constant OPTIMISM_OP = 0x4200000000000000000000000000000000000042;
    address internal constant OPTIMISM_WETH = 0x4200000000000000000000000000000000000006;
    address internal constant OPTIMISM_WSTETH = 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;

    uint256 internal constant OPTIMISM_MIN_INITIAL_TOTAL_SUPPLY = 1000 wei;

    uint32 internal constant OPTIMISM_FEE_D9 = 1e7; // 10% fee

    address internal constant OPTIMISM_LP_WRAPPER_ADMIN =
        address(uint160(uint256(keccak256("OPTIMISM_LP_WRAPPER_ADMIN"))));
    address internal constant OPTIMISM_LP_WRAPPER_MANAGER =
        address(uint160(uint256(keccak256("OPTIMISM_LP_WRAPPER_MANAGER"))));
    address internal constant OPTIMISM_LP_WRAPPER_OPERATOR =
        address(uint160(uint256(keccak256("OPTIMISM_LP_WRAPPER_OPERATOR"))));

    address internal constant OPTIMISM_FACTORY_OPERATOR =
        address(uint160(uint256(keccak256("OPTIMISM_FACTORY_OPERATOR"))));
    address internal constant OPTIMISM_CORE_OPERATOR =
        address(uint160(uint256(keccak256("OPTIMISM_CORE_OPERATOR"))));

    address internal constant OPTIMISM_MELLOW_TREASURY =
        address(uint160(uint256(keccak256("OPTIMISM_MELLOW_TREASURY"))));
    address internal constant OPTIMISM_FACTORY_PROPOSER =
        address(uint160(uint256(keccak256("OPTIMISM_FACTORY_PROPOSER"))));

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
                lpWrapperOperator: OPTIMISM_LP_WRAPPER_OPERATOR,
                minInitialTotalSupply: OPTIMISM_MIN_INITIAL_TOTAL_SUPPLY,
                factoryManager: OPTIMISM_FACTORY_OPERATOR,
                factoryProposer: OPTIMISM_FACTORY_PROPOSER,
                coreOperator: OPTIMISM_CORE_OPERATOR,
                protocolParams: IVeloAmmModule.ProtocolParams({
                    treasury: OPTIMISM_MELLOW_TREASURY,
                    feeD9: OPTIMISM_FEE_D9,
                    extraData: ""
                })
            });
        }
        revert("Unsupported chain");
    }

    function testConstants() internal pure {}
}
