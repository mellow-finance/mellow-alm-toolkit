// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./DeployScript.sol";

import "./RebalancingBot.sol";
import "./RebalancingBotHelper.sol";

library Constants {
    address internal constant TEST_OPTIMISM_DEPLOYER = 0xf785Ee037A85aa079e84b1ba8674E4091f93d304;
    address internal constant TEST_OPTIMISM_OPERATOR_ADMIN =
        0x63B6E180e86E845d47Ce34324F8409ea898AD13c;
    //==============================================================================================
    address internal constant OPTIMISM_DEPLOYER = 0xBe440AeE8c8D54aC7bb7D93506460492Df5812ea; // actual deployer
    address internal constant OPTIMISM_MELLOW_ADMIN = 0x893df22649247AD4e57E4926731F9Cf0dA344829; // actual mellow msig
    address internal constant OPTIMISM_POSITION_MANAGER = 0x416b433906b1B72FA758e166e239c43d68dC6F29;
    address internal constant BASE_POSITION_MANAGER = 0x827922686190790b37229fd06084350E74485b72;
    bytes4 internal constant OPTIMISM_IS_POOL_SELECTOR = bytes4(keccak256("isPair(address)"));
    bytes4 internal constant BASE_IS_POOL_SELECTOR = bytes4(keccak256("isPool(address)"));
    address internal constant OPTIMISM_SWAP_ROUTER = 0x0792a633F0c19c351081CF4B211F68F79bCc9676;

    address internal constant OPTIMISM_OP = 0x4200000000000000000000000000000000000042;
    address internal constant OPTIMISM_WETH = 0x4200000000000000000000000000000000000006;
    address internal constant BASE_WETH = 0x4200000000000000000000000000000000000006;
    address internal constant BASE_WSTETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
    address internal constant OPTIMISM_LP_WRAPPER_ADMIN = OPTIMISM_MELLOW_ADMIN; // mellow msig
    address internal constant OPTIMISM_LP_WRAPPER_MANAGER = 0x64781bebFE7eD2f49aB55225B4E097EBbc3AfB38; // msig Velo+Mellow

    uint256 internal constant OPTIMISM_MIN_INITIAL_TOTAL_SUPPLY = 1000 wei;
    address internal constant OPTIMISM_FACTORY_OPERATOR = 0xd82019856027bf7E7183Bd76FE6ed31e2CcE534C; // actual
    address internal constant OPTIMISM_CORE_OPERATOR = 0x0A16Bc694EeA56cbFc808a271178556d3f8c23aD; // actual

    address internal constant OPTIMISM_MELLOW_TREASURY = 0xf0E36e9186Dbe927505d2588a6E6D56083Dd4a56; // actual msig mellow
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
        } else if (block.chainid == 8453) {
            return DeployScript.CoreDeploymentParams({
                deployer: OPTIMISM_DEPLOYER,
                mellowAdmin: OPTIMISM_MELLOW_ADMIN,
                positionManager: BASE_POSITION_MANAGER,
                isPoolSelector: BASE_IS_POOL_SELECTOR,
                weth: BASE_WETH,
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
