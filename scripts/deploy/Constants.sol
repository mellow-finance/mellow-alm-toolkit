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
    //==============================================================================================

    address internal constant OPTIMISM_MELLOW_ADMIN = 0x893df22649247AD4e57E4926731F9Cf0dA344829; // actual mellow msig
    address internal constant SONEIUM_MELLOW_ADMIN = 0x978ba0e402e5Da4110D7243412887986cEf35e8c; // actual mellow msig
    address internal constant MODE_MELLOW_ADMIN = 0x978ba0e402e5Da4110D7243412887986cEf35e8c; // actual mellow msig
    address internal constant INK_MELLOW_ADMIN = 0xF5c8311038eE0f419adeE240F3CB4f061a9eecfd; // actual mellow msig
    address internal constant SWELL_MELLOW_ADMIN = 0x7d0051F3696E757b752d1301c1799e23A8001092; // actual mellow msig
    address internal constant UNI_MELLOW_ADMIN = 0x7d0051F3696E757b752d1301c1799e23A8001092; // actual mellow msig
    address internal constant CELO_MELLOW_ADMIN = 0xF5c8311038eE0f419adeE240F3CB4f061a9eecfd; // actual mellow msig
    address internal constant SUPERSEED_MELLOW_ADMIN = 0x978ba0e402e5Da4110D7243412887986cEf35e8c; // actual mellow msig

    address internal constant OPTIMISM_POSITION_MANAGER = 0x416b433906b1B72FA758e166e239c43d68dC6F29;
    address internal constant BASE_POSITION_MANAGER = 0x827922686190790b37229fd06084350E74485b72;
    address internal constant SONEIUM_POSITION_MANAGER = 0x991d5546C4B442B4c5fdc4c8B8b8d131DEB24702;
    address internal constant MODE_POSITION_MANAGER = 0x991d5546C4B442B4c5fdc4c8B8b8d131DEB24702;
    address internal constant INK_POSITION_MANAGER = 0x991d5546C4B442B4c5fdc4c8B8b8d131DEB24702;
    address internal constant SWELL_POSITION_MANAGER = 0x991d5546C4B442B4c5fdc4c8B8b8d131DEB24702;
    address internal constant UNI_POSITION_MANAGER = 0x991d5546C4B442B4c5fdc4c8B8b8d131DEB24702;
    address internal constant CELO_POSITION_MANAGER = 0x991d5546C4B442B4c5fdc4c8B8b8d131DEB24702;
    address internal constant SUPERSEED_POSITION_MANAGER = 0x991d5546C4B442B4c5fdc4c8B8b8d131DEB24702;

    bytes4 internal constant IS_PAIR_SELECTOR = bytes4(keccak256("isPair(address)"));
    bytes4 internal constant IS_POOL_SELECTOR = bytes4(keccak256("isPool(address)"));

    address internal constant OPTIMISM_SWAP_ROUTER = 0x0792a633F0c19c351081CF4B211F68F79bCc9676;

    address internal constant OPTIMISM_OP = 0x4200000000000000000000000000000000000042;

    address internal constant OPTIMISM_WETH = 0x4200000000000000000000000000000000000006;
    address internal constant BASE_WETH = 0x4200000000000000000000000000000000000006;
    address internal constant SONEIUM_WETH = 0x4200000000000000000000000000000000000006;
    address internal constant MODE_WETH = 0x4200000000000000000000000000000000000006;
    address internal constant INK_WETH = 0x4200000000000000000000000000000000000006;
    address internal constant SWELL_WETH = 0x4200000000000000000000000000000000000006;
    address internal constant UNI_WETH = 0x4200000000000000000000000000000000000006;
    address internal constant CELO_WETH = 0x4200000000000000000000000000000000000006;
    address internal constant SUPERSEED_WETH = 0x4200000000000000000000000000000000000006;

    address internal constant BASE_WSTETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
    address internal constant OPTIMISM_WSTETH = 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;

    address internal constant OPTIMISM_LP_WRAPPER_ADMIN = OPTIMISM_MELLOW_ADMIN; // mellow msig
    address internal constant BASE_LP_WRAPPER_ADMIN = OPTIMISM_MELLOW_ADMIN; // mellow msig
    address internal constant SONEIUM_LP_WRAPPER_ADMIN = SONEIUM_MELLOW_ADMIN; // mellow msig
    address internal constant MODE_LP_WRAPPER_ADMIN = MODE_MELLOW_ADMIN; // mellow msig
    address internal constant INK_LP_WRAPPER_ADMIN = INK_MELLOW_ADMIN; // mellow msig
    address internal constant SWELL_LP_WRAPPER_ADMIN = SWELL_MELLOW_ADMIN; // mellow msig
    address internal constant UNI_LP_WRAPPER_ADMIN = UNI_MELLOW_ADMIN; // mellow msig
    address internal constant CELO_LP_WRAPPER_ADMIN = CELO_MELLOW_ADMIN; // mellow msig
    address internal constant SUPERSEED_LP_WRAPPER_ADMIN = SUPERSEED_MELLOW_ADMIN; // mellow msig

    address internal constant OPTIMISM_LP_WRAPPER_MANAGER =
        0x64781bebFE7eD2f49aB55225B4E097EBbc3AfB38; // msig Velo+Mellow
    address internal constant BASE_LP_WRAPPER_MANAGER = 0x64781bebFE7eD2f49aB55225B4E097EBbc3AfB38; // msig Velo+Mellow
    address internal constant MODE_LP_WRAPPER_MANAGER = 0xA4443abEb1A04CDcdff5939Ae9Fa3d2e021D7DC9; // msig Velo+Mellow
    address internal constant SONEIUM_LP_WRAPPER_MANAGER = 0x660b1d9DF381B8141F066653CeBc047d5eD690D5; // msig Velo+Mellow
    address internal constant INK_LP_WRAPPER_MANAGER = 0xDaC1293A165c073B787b60223c76Dd8c3f538d8C; // msig Velo+Mellow
    address internal constant SWELL_LP_WRAPPER_MANAGER = 0xA4443abEb1A04CDcdff5939Ae9Fa3d2e021D7DC9; // msig Velo+Mellow
    address internal constant UNI_LP_WRAPPER_MANAGER = 0xA4443abEb1A04CDcdff5939Ae9Fa3d2e021D7DC9; // msig Velo+Mellow
    address internal constant CELO_LP_WRAPPER_MANAGER = 0xDaC1293A165c073B787b60223c76Dd8c3f538d8C; // msig Velo+Mellow
    address internal constant SUPERSEED_LP_WRAPPER_MANAGER = 0xA4443abEb1A04CDcdff5939Ae9Fa3d2e021D7DC9; // msig Velo+Mellow

    uint256 internal constant OPTIMISM_MIN_INITIAL_TOTAL_SUPPLY = 1000 wei;
    address internal constant FACTORY_OPERATOR = 0xd82019856027bf7E7183Bd76FE6ed31e2CcE534C; // actual
    address internal constant CORE_OPERATOR = 0x0A16Bc694EeA56cbFc808a271178556d3f8c23aD; // actual

    address internal constant OPTIMISM_MELLOW_TREASURY = 0xf0E36e9186Dbe927505d2588a6E6D56083Dd4a56; // actual msig mellow
    address internal constant BASE_MELLOW_TREASURY = 0xf0E36e9186Dbe927505d2588a6E6D56083Dd4a56; // actual msig mellow
    address internal constant MODE_MELLOW_TREASURY = MODE_MELLOW_ADMIN; // actual msig mellow
    address internal constant SONEIUM_MELLOW_TREASURY = SONEIUM_MELLOW_ADMIN; // actual msig mellow
    address internal constant INK_MELLOW_TREASURY = INK_MELLOW_ADMIN; // actual msig mellow
    address internal constant SWELL_MELLOW_TREASURY = SWELL_MELLOW_ADMIN; // mellow msig
    address internal constant UNI_MELLOW_TREASURY = UNI_MELLOW_ADMIN; // mellow msig
    address internal constant CELO_MELLOW_TREASURY = CELO_MELLOW_ADMIN; // mellow msig
    address internal constant SUPERSEED_MELLOW_TREASURY = SUPERSEED_MELLOW_ADMIN; // mellow msig
    uint32 internal constant FEE_D9 = 1e8; // 10% fee

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
                isPoolSelector: IS_PAIR_SELECTOR,
                weth: OPTIMISM_WETH,
                lpWrapperAdmin: OPTIMISM_LP_WRAPPER_ADMIN,
                lpWrapperManager: OPTIMISM_LP_WRAPPER_MANAGER,
                minInitialTotalSupply: OPTIMISM_MIN_INITIAL_TOTAL_SUPPLY,
                factoryOperator: FACTORY_OPERATOR,
                coreOperator: CORE_OPERATOR,
                protocolParams: IVeloAmmModule.ProtocolParams({
                    treasury: OPTIMISM_MELLOW_TREASURY,
                    feeD9: FEE_D9
                })
            });
        } else if (block.chainid == 8453) {
            return DeployScript.CoreDeploymentParams({
                deployer: OPTIMISM_DEPLOYER,
                mellowAdmin: OPTIMISM_MELLOW_ADMIN,
                positionManager: BASE_POSITION_MANAGER,
                isPoolSelector: IS_POOL_SELECTOR,
                weth: BASE_WETH,
                lpWrapperAdmin: BASE_LP_WRAPPER_ADMIN,
                lpWrapperManager: BASE_LP_WRAPPER_MANAGER,
                minInitialTotalSupply: OPTIMISM_MIN_INITIAL_TOTAL_SUPPLY,
                factoryOperator: FACTORY_OPERATOR,
                coreOperator: CORE_OPERATOR,
                protocolParams: IVeloAmmModule.ProtocolParams({
                    treasury: BASE_MELLOW_TREASURY,
                    feeD9: FEE_D9
                })
            });
        } else if (block.chainid == 34443) {
            return DeployScript.CoreDeploymentParams({
                deployer: OPTIMISM_DEPLOYER,
                mellowAdmin: MODE_MELLOW_ADMIN,
                positionManager: MODE_POSITION_MANAGER,
                isPoolSelector: IS_PAIR_SELECTOR,
                weth: MODE_WETH,
                lpWrapperAdmin: MODE_LP_WRAPPER_ADMIN,
                lpWrapperManager: MODE_LP_WRAPPER_MANAGER,
                minInitialTotalSupply: OPTIMISM_MIN_INITIAL_TOTAL_SUPPLY,
                factoryOperator: FACTORY_OPERATOR,
                coreOperator: CORE_OPERATOR,
                protocolParams: IVeloAmmModule.ProtocolParams({
                    treasury: MODE_MELLOW_TREASURY,
                    feeD9: FEE_D9
                })
            });
        } else if (block.chainid == 1868) {
            return DeployScript.CoreDeploymentParams({
                deployer: OPTIMISM_DEPLOYER,
                mellowAdmin: SONEIUM_MELLOW_ADMIN,
                positionManager: SONEIUM_POSITION_MANAGER,
                isPoolSelector: IS_PAIR_SELECTOR,
                weth: SONEIUM_WETH,
                lpWrapperAdmin: SONEIUM_LP_WRAPPER_ADMIN,
                lpWrapperManager: SONEIUM_LP_WRAPPER_MANAGER,
                minInitialTotalSupply: OPTIMISM_MIN_INITIAL_TOTAL_SUPPLY,
                factoryOperator: FACTORY_OPERATOR,
                coreOperator: CORE_OPERATOR,
                protocolParams: IVeloAmmModule.ProtocolParams({
                    treasury: SONEIUM_MELLOW_TREASURY,
                    feeD9: FEE_D9
                })
            });
        } else if (block.chainid == 34443) {
            return DeployScript.CoreDeploymentParams({
                deployer: OPTIMISM_DEPLOYER,
                mellowAdmin: MODE_MELLOW_ADMIN,
                positionManager: MODE_POSITION_MANAGER,
                isPoolSelector: IS_PAIR_SELECTOR,
                weth: MODE_WETH,
                lpWrapperAdmin: MODE_LP_WRAPPER_ADMIN,
                lpWrapperManager: MODE_LP_WRAPPER_MANAGER,
                minInitialTotalSupply: OPTIMISM_MIN_INITIAL_TOTAL_SUPPLY,
                factoryOperator: FACTORY_OPERATOR,
                coreOperator: CORE_OPERATOR,
                protocolParams: IVeloAmmModule.ProtocolParams({
                    treasury: MODE_MELLOW_TREASURY,
                    feeD9: FEE_D9
                })
            });
        } else if (block.chainid == 57073) {
            return DeployScript.CoreDeploymentParams({
                deployer: OPTIMISM_DEPLOYER,
                mellowAdmin: INK_MELLOW_ADMIN,
                positionManager: INK_POSITION_MANAGER,
                isPoolSelector: IS_PAIR_SELECTOR,
                weth: INK_WETH,
                lpWrapperAdmin: INK_LP_WRAPPER_ADMIN,
                lpWrapperManager: INK_LP_WRAPPER_MANAGER,
                minInitialTotalSupply: OPTIMISM_MIN_INITIAL_TOTAL_SUPPLY,
                factoryOperator: FACTORY_OPERATOR,
                coreOperator: CORE_OPERATOR,
                protocolParams: IVeloAmmModule.ProtocolParams({
                    treasury: INK_MELLOW_TREASURY,
                    feeD9: FEE_D9
                })
            });
        } else if (block.chainid == 1923) {
            return DeployScript.CoreDeploymentParams({
                deployer: OPTIMISM_DEPLOYER,
                mellowAdmin: SWELL_MELLOW_ADMIN,
                positionManager: SWELL_POSITION_MANAGER,
                isPoolSelector: IS_PAIR_SELECTOR,
                weth: SWELL_WETH,
                lpWrapperAdmin: SWELL_LP_WRAPPER_ADMIN,
                lpWrapperManager: SWELL_LP_WRAPPER_MANAGER,
                minInitialTotalSupply: OPTIMISM_MIN_INITIAL_TOTAL_SUPPLY,
                factoryOperator: FACTORY_OPERATOR,
                coreOperator: CORE_OPERATOR,
                protocolParams: IVeloAmmModule.ProtocolParams({
                    treasury: SWELL_MELLOW_TREASURY,
                    feeD9: FEE_D9
                })
            });
        } else if (block.chainid == 130) {
            return DeployScript.CoreDeploymentParams({
                deployer: OPTIMISM_DEPLOYER,
                mellowAdmin: UNI_MELLOW_ADMIN,
                positionManager: UNI_POSITION_MANAGER,
                isPoolSelector: IS_PAIR_SELECTOR,
                weth: UNI_WETH,
                lpWrapperAdmin: UNI_LP_WRAPPER_ADMIN,
                lpWrapperManager: UNI_LP_WRAPPER_MANAGER,
                minInitialTotalSupply: OPTIMISM_MIN_INITIAL_TOTAL_SUPPLY,
                factoryOperator: FACTORY_OPERATOR,
                coreOperator: CORE_OPERATOR,
                protocolParams: IVeloAmmModule.ProtocolParams({
                    treasury: UNI_MELLOW_TREASURY,
                    feeD9: FEE_D9
                })
            });
        } else if (block.chainid == 42220) {
            return DeployScript.CoreDeploymentParams({
                deployer: OPTIMISM_DEPLOYER,
                mellowAdmin: CELO_MELLOW_ADMIN,
                positionManager: CELO_POSITION_MANAGER,
                isPoolSelector: IS_PAIR_SELECTOR,
                weth: CELO_WETH,
                lpWrapperAdmin: CELO_LP_WRAPPER_ADMIN,
                lpWrapperManager: CELO_LP_WRAPPER_MANAGER,
                minInitialTotalSupply: OPTIMISM_MIN_INITIAL_TOTAL_SUPPLY,
                factoryOperator: FACTORY_OPERATOR,
                coreOperator: CORE_OPERATOR,
                protocolParams: IVeloAmmModule.ProtocolParams({
                    treasury: CELO_MELLOW_TREASURY,
                    feeD9: FEE_D9
                })
            });
        } else if (block.chainid == 5330) {
            return DeployScript.CoreDeploymentParams({
                deployer: OPTIMISM_DEPLOYER,
                mellowAdmin: SUPERSEED_MELLOW_ADMIN,
                positionManager: SUPERSEED_POSITION_MANAGER,
                isPoolSelector: IS_PAIR_SELECTOR,
                weth: SUPERSEED_WETH,
                lpWrapperAdmin: SUPERSEED_LP_WRAPPER_ADMIN,
                lpWrapperManager: SUPERSEED_LP_WRAPPER_MANAGER,
                minInitialTotalSupply: OPTIMISM_MIN_INITIAL_TOTAL_SUPPLY,
                factoryOperator: FACTORY_OPERATOR,
                coreOperator: CORE_OPERATOR,
                protocolParams: IVeloAmmModule.ProtocolParams({
                    treasury: SUPERSEED_MELLOW_TREASURY,
                    feeD9: FEE_D9
                })
            });
        }
        revert("Unsupported chain");
    }

    function getCoreDeployment() internal view returns (CoreDeployment memory) {
        /// @notice Core deployment addresses are the same on all chains
        return CoreDeployment({
            core: Core(payable(0x0000000cE42D4981513060aB7E50B9e5e2D19AF1)),
            ammModule: IVeloAmmModule(0x3240847946E112Db9C7D3BBB4FC3CDc38Cb6bFB5),
            depositWithdrawModule: IVeloDepositWithdrawModule(
                0x794070c3CB9366F066D837BFdCDe67fD981CDA56
            ),
            oracle: IVeloOracle(0xc96ED9f6C8f546DCf7953c9df8Ff270330F45213),
            strategyModule: IPulseStrategyModule(0xdebea4AF183d323132AD5AB7C0b7Cd2091094eee),
            deployFactory: VeloDeployFactory(payable(0xE46EC96906fc6dEC53De25F013639969Fe10180d)),
            lpWrapperImplementation: ILpWrapper(0xfd61E98a352ed8cA2C364DCd5B6C21dc126959F5)
        });
    }

    function testConstants() internal pure {}
}
