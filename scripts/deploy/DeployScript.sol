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
        console2.log("Deployer address:", params.deployer);
        for (uint256 index = 0; index < 10; index++) {
            address(params.deployer).call{value: 1 ether / 1000000}("");
        }

        //return contracts;

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
        /// @dev salt selection loop

        /*         for (uint256 i = 500 * 1e6; i < 700 * 1e6; i++) {
            predictedCoreAddress =
                Create2.computeAddress(bytes32(i), byteCodeHash, create2DeterministicDeployer);
            if (uint160(predictedCoreAddress) >> 136 == 0) {
                console2.log(predictedCoreAddress, i);
                if (predictedCoreAddress == 0x0000000cE42D4981513060aB7E50B9e5e2D19AF1) {
                    break;
                }
            }
        } */
        //0x0000000cE42D4981513060aB7E50B9e5e2D19AF1 65105670
        //revert("done"); //*/
        salt = bytes32(uint256(65105670)); // 0x0000000cE42D4981513060aB7E50B9e5e2D19AF1 65105670 Base+Optimism

        predictedCoreAddress =
            Create2.computeAddress(salt, byteCodeHash, create2DeterministicDeployer);

        // console2.log("Desired   Core address:", 0x0000000cE42D4981513060aB7E50B9e5e2D19AF1);
        console2.log("Predicted Core address:", predictedCoreAddress);
        address deployed = Create2.deploy(0, salt, bytecode);
        console2.log("Deployed  Core address:", deployed);
        require(deployed == 0x0000000cE42D4981513060aB7E50B9e5e2D19AF1, "unexpected Core address"); // Base+Optimism+Soneium+Mode

        contracts.core = Core(payable(deployed));
        //------------------------------------------

        contracts.lpWrapperImplementation = new LpWrapper(address(contracts.core));
        contracts.deployFactory = new VeloDeployFactory(
            params.deployer,
            contracts.core,
            contracts.strategyModule,
            address(contracts.lpWrapperImplementation)
        );

        checkDeploymentAddresses(contracts);

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
        IERC20(params.pool.token0()).approve(address(contracts.deployFactory), params.maxAmount0);
        IERC20(params.pool.token1()).approve(address(contracts.deployFactory), params.maxAmount1);

        bytes memory data =
            abi.encodeWithSelector(contracts.deployFactory.createStrategy.selector, params);

        try contracts.deployFactory.createStrategy(params) returns (ILpWrapper lpWrapper) {
            console2.log("Approves for factory:", address(contracts.deployFactory));
            console2.log("              Token0:", address(params.pool.token0()), params.maxAmount0);
            console2.log("              Token1:", address(params.pool.token1()), params.maxAmount1);
            console2.log("                Pool:", address(params.pool));
            return lpWrapper;
        } catch {
            return ILpWrapper(address(0));
        }
    }

    function testDeployScript() internal pure {}

    function checkDeploymentAddresses(CoreDeployment memory deployed) internal view {
        CoreDeploymentParams memory coreDeploymentParams = Constants.getDeploymentParams();

        CoreDeployment memory expected = Constants.getCoreDeployment();
        require(address(expected.core) == address(deployed.core), "core mismatch");
        require(address(expected.ammModule) == address(deployed.ammModule), "ammModule mismatch");
        require(
            address(expected.depositWithdrawModule) == address(deployed.depositWithdrawModule),
            "depositWithdrawModule mismatch"
        );
        require(address(expected.oracle) == address(deployed.oracle), "oracle mismatch");
        require(
            address(expected.strategyModule) == address(deployed.strategyModule),
            "strategyModule mismatch"
        );
        require(
            address(expected.deployFactory) == address(deployed.deployFactory),
            "deployFactory mismatch"
        );
        require(
            address(expected.lpWrapperImplementation) == address(deployed.lpWrapperImplementation),
            "lpWrapperImplementation mismatch"
        );

        console2.log(
            "----------- Mellow ALM deployment addresses at chain ID", block.chainid, "-----------"
        );
        console2.log("                     Core: ", address(deployed.core));
        console2.log("        VeloDeployFactory: ", address(deployed.deployFactory));
        console2.log("      PulseStrategyModule: ", address(deployed.strategyModule));
        console2.log("                LpWrapper: ", address(deployed.lpWrapperImplementation));
        console2.log("            VeloAmmModule: ", address(deployed.ammModule));
        console2.log("VeloDepositWithdrawModule: ", address(deployed.depositWithdrawModule));
        console2.log("               VeloOracle: ", address(deployed.oracle));
        console2.log("                 Deployer: ", address(coreDeploymentParams.deployer));
        console2.log("               Core Admin: ", address(coreDeploymentParams.mellowAdmin));
        console2.log("            Core Operator: ", address(coreDeploymentParams.coreOperator));
        console2.log("         Factory Operator: ", address(coreDeploymentParams.factoryOperator));
        console2.log("     Core LpWrapper Admin: ", address(coreDeploymentParams.lpWrapperAdmin));
        console2.log("   Core LpWrapper Manager: ", address(coreDeploymentParams.lpWrapperManager));
        console2.log(
            "        Protocol treasury: ", address(coreDeploymentParams.protocolParams.treasury)
        );
    }
}

contract Deploy is Script, DeployScript, PoolParameters {
    uint256 immutable deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address immutable DEPLOYER = vm.addr(deployerPrivateKey);

    function run() external {
        CoreDeploymentParams memory coreDeploymentParams = Constants.getDeploymentParams();

        //    require(OPERATOR == coreDeploymentParams.coreOperator);
        //    require(FACTORY_OPERATOR == coreDeploymentParams.factoryOperator);
        /* 
        vm.startBroadcast(deployerPrivateKey);
        CoreDeployment memory contracts = deployCore(coreDeploymentParams);
        vm.stopBroadcast();

        revert("success");
         */

        CoreDeployment memory contracts = Constants.getCoreDeployment();
        transferTokensToFactoryOperator(contracts);
        //return;

        console2.log("         FACTORY_OPERATOR: ", coreDeploymentParams.factoryOperator);
        console2.log("                     Core: ", address(contracts.core));
        console2.log("        VeloDeployFactory: ", address(contracts.deployFactory));
        console2.log("      PulseStrategyModule: ", address(contracts.strategyModule));
        console2.log("                LpWrapper: ", address(contracts.lpWrapperImplementation));
        console2.log("            VeloAmmModule: ", address(contracts.ammModule));
        console2.log("VeloDepositWithdrawModule: ", address(contracts.depositWithdrawModule));
        console2.log("               VeloOracle: ", address(contracts.oracle));

        deployStrategies(contracts);
        // revert("success");
    }

    function deployStrategies(CoreDeployment memory contracts) internal {
        CoreDeploymentParams memory coreDeploymentParams = Constants.getDeploymentParams();

        vm.startPrank(coreDeploymentParams.factoryOperator);
        IVeloDeployFactory.DeployParams[] memory params = getPoolDeployParams(contracts);

        uint256 firstIndex = 69;
        uint256 lastIndex = params.length;
        string memory batchJson = '{"transactions":[';
        for (uint256 i = firstIndex; i < lastIndex; i++) {
            console2.log("-----------------------------------------------------");
            ILpWrapper lpWrapper =
                ILpWrapper(contracts.deployFactory.poolToWrapper(address(params[i].pool)));
            if (address(lpWrapper) != address(0)) {
                console2.log("[EXISTS] Strategy is deployed", address(lpWrapper));
                continue; // already deployed
            } else {
                lpWrapper = deployStrategy(contracts, params[i]);
                if (address(lpWrapper) != address(0)) {
                    string memory semicolon = i < lastIndex - 1 ? "," : "";
                    batchJson = string(
                        abi.encodePacked(
                            batchJson, jsonDeploymentEntity(contracts, params[i]), semicolon
                        )
                    );

                    console2.log("[SUCCESS] Strategy is deployed");
                } else {
                    console2.log("[FAILED] Strategy deployment");
                }
            }
            console2.log("For Pool :", address(params[i].pool));
            console2.log("LpWrapper:", address(lpWrapper));
        }

        batchJson = string(abi.encodePacked(batchJson, "]}"));

        vm.writeFile(
            string(
                abi.encodePacked(
                    "cache/deployment/",
                    vm.toString(block.chainid),
                    "_batch_",
                    vm.toString(firstIndex),
                    "-",
                    vm.toString(lastIndex - 1),
                    ".json"
                )
            ),
            batchJson
        );
        vm.stopPrank();
    }

    function transferTokensToFactoryOperator(CoreDeployment memory contracts) internal {
        IVeloDeployFactory.DeployParams[] memory params = getPoolDeployParams(contracts);
        CoreDeploymentParams memory coreDeploymentParams = Constants.getDeploymentParams();

        for (uint256 i = 0; i < params.length; i++) {
            ICLPool pool = params[i].pool;
            sendAssets(pool.token0(), coreDeploymentParams.factoryOperator);
            sendAssets(pool.token1(), coreDeploymentParams.factoryOperator);
        }
    }

    function sendAssets(address token, address to) internal {
        uint256 senderPrivateKey = vm.envUint("OPERATOR_PRIVATE_KEY");
        address SENDER = vm.addr(senderPrivateKey);

        if (token == 0x471EcE3750Da237f93B8E339c536989b8978a438) {
            vm.startBroadcast(senderPrivateKey);
            to.call{value: 3.5e18}("");
            vm.stopBroadcast();
            // skip CELO token
            return;
        }

        require(token != address(0), "token is zero address");
        require(to != address(0), "to is zero address");

        uint256 balance = IERC20(token).balanceOf(SENDER);
        if (balance > 0) {
            vm.startBroadcast(senderPrivateKey);
            IERC20(token).transfer(to, balance);
            vm.stopBroadcast();
            console2.log("Transferred", IERC20Metadata(token).symbol(), balance, to);
        }
    }

    function jsonDeploymentEntity(
        CoreDeployment memory contracts,
        IVeloDeployFactory.DeployParams memory params
    ) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                jsonTransaction(
                    params.pool.token0(),
                    abi.encodeWithSelector(
                        IERC20.approve.selector, address(contracts.deployFactory), params.maxAmount0
                    )
                ),
                ",",
                jsonTransaction(
                    params.pool.token1(),
                    abi.encodeWithSelector(
                        IERC20.approve.selector, address(contracts.deployFactory), params.maxAmount1
                    )
                ),
                ",",
                jsonTransaction(
                    address(contracts.deployFactory),
                    abi.encodeWithSelector(IVeloDeployFactory.createStrategy.selector, params)
                )
            )
        );
    }

    function jsonTransaction(address to, bytes memory data) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '{"to":"',
                vm.toString(to),
                '","value":"0","data":"',
                vm.toString(data),
                '","operation":"0"}'
            )
        );
    }
}
