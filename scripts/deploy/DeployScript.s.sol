// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./PoolsV2.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

abstract contract DeployScript {
    bool internal TEST_ENV = false;
    uint256 internal startSalt = 65105671;
    uint256 private deployedContracts;
    mapping(string => bytes32) internal contractSalts;

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

    function setUp() external virtual {
        /*
            salt 392948948 | VeloAmmModule: 0x00000006B0B357F48F4fC9D20b9b23F7640b8893;
            salt 599636895 | VeloDepositWithdrawModule: 0x00000003350B8343889AA9A30A32b4C883452456;
            salt 775961490 | VeloOracle: 0x0000000f70629Adc6E46c8E222a150B1123dBeb6;
            salt 1052119663 | PulseStrategyModule: 0x000000006AE6F1FcbE56af05027B2650bC8E9C7A;
            salt 743084019 | Core: 0x0000C08e4b22Cb937B5d5A65C0243De612E9E60c;
            salt 570694638 | LpWrapper: 0x0000000639f91FaB752c414eF0993D36e6d16ba1;
            salt 919107586 | VeloDeployFactory: 0x0000000d2D5f153C468Ad8D69946f1c5c99eCD2c;
        */
        contractSalts["VeloAmmModule"] = bytes32(uint256(392948948));
        contractSalts["VeloDepositWithdrawModule"] = bytes32(uint256(599636895));
        contractSalts["VeloOracle"] = bytes32(uint256(775961490));
        contractSalts["PulseStrategyModule"] = bytes32(uint256(1052119663));
        contractSalts["Core"] = bytes32(uint256(743084019));
        contractSalts["LpWrapper"] = bytes32(uint256(570694638));
        contractSalts["VeloDeployFactory"] = bytes32(uint256(919107586));
    }

    function deployCore(CoreDeploymentParams memory params)
        internal
        returns (CoreDeployment memory contracts)
    {
        console2.log("Deployer address:", params.deployer);
        //------------------------------------------
        contracts.ammModule = IVeloAmmModule(
            _deployWithOptimalSalt(
                "VeloAmmModule",
                type(VeloAmmModule).creationCode,
                abi.encode(
                    INonfungiblePositionManager(params.positionManager), params.isPoolSelector
                )
            )
        );
        //------------------------------------------
        contracts.depositWithdrawModule = IVeloDepositWithdrawModule(
            _deployWithOptimalSalt(
                "VeloDepositWithdrawModule",
                type(VeloDepositWithdrawModule).creationCode,
                abi.encode(INonfungiblePositionManager(params.positionManager))
            )
        );
        //------------------------------------------
        contracts.oracle = IVeloOracle(
            _deployWithOptimalSalt("VeloOracle", type(VeloOracle).creationCode, abi.encode())
        );
        //------------------------------------------
        contracts.strategyModule = IPulseStrategyModule(
            _deployWithOptimalSalt(
                "PulseStrategyModule", type(PulseStrategyModule).creationCode, abi.encode()
            )
        );
        // -----------------------------------------
        contracts.core = Core(
            payable(
                _deployWithOptimalSalt(
                    "Core",
                    type(Core).creationCode,
                    abi.encode(
                        contracts.ammModule,
                        contracts.depositWithdrawModule,
                        contracts.strategyModule,
                        contracts.oracle,
                        params.deployer,
                        params.weth
                    )
                )
            )
        );
        //------------------------------------------
        contracts.lpWrapperImplementation = ILpWrapper(
            _deployWithOptimalSalt(
                "LpWrapper", type(LpWrapper).creationCode, abi.encode(address(contracts.core))
            )
        );
        //------------------------------------------
        contracts.deployFactory = VeloDeployFactory(
            payable(
                _deployWithOptimalSalt(
                    "VeloDeployFactory",
                    type(VeloDeployFactory).creationCode,
                    abi.encode(
                        params.deployer,
                        contracts.core,
                        contracts.strategyModule,
                        address(contracts.lpWrapperImplementation)
                    )
                )
            )
        );

        if (!TEST_ENV) {
            checkDeploymentAddresses(contracts);
        }

        require(contracts.core.hasRole(contracts.core.ADMIN_ROLE(), params.deployer));

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

        checkRoles(contracts, params.deployer);

        if (!TEST_ENV) {
           // revert("Core deployed successfully");
        }
    }

    function deployStrategy(
        CoreDeployment memory contracts,
        IVeloDeployFactory.DeployParams memory params
    ) internal returns (ILpWrapper) {
        IERC20(params.pool.token0()).approve(address(contracts.deployFactory), params.maxAmount0);
        IERC20(params.pool.token1()).approve(address(contracts.deployFactory), params.maxAmount1);

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

    function checkDeploymentAddresses(CoreDeployment memory deployed) internal view {
        CoreDeploymentParams memory coreDeploymentParams = Constants.getDeploymentParams();

        /*  CoreDeployment memory expected = Constants.getCoreDeployment();
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
        ); */

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

    function checkRoles(CoreDeployment memory contracts, address deployer) internal view {
        require(
            contracts.core.getRoleMemberCount(contracts.core.ADMIN_ROLE()) == 1,
            "more than one or zero Core admins"
        );
        require(
            contracts.core.getRoleMemberCount(contracts.core.ADMIN_DELEGATE_ROLE()) == 0,
            "more than zero Core admin delegates"
        );
        require(
            contracts.core.getRoleMemberCount(contracts.core.OPERATOR()) == 1,
            "more than one or zero Core operators"
        );
        require(
            contracts.deployFactory.getRoleMemberCount(contracts.deployFactory.ADMIN_ROLE()) == 1,
            "more than one or zero DeployFactory admins"
        );
        require(
            contracts.deployFactory.getRoleMemberCount(
                contracts.deployFactory.ADMIN_DELEGATE_ROLE()
            ) == 0,
            "more than zero DeployFactory admin delegates"
        );
        require(
            contracts.deployFactory.getRoleMemberCount(contracts.deployFactory.OPERATOR()) == 1,
            "more than one or zero DeployFactory operators"
        );

        _checkRoles(address(contracts.core), deployer, contracts.core.ADMIN_ROLE());
        _checkRoles(address(contracts.core), deployer, contracts.core.ADMIN_DELEGATE_ROLE());
        _checkRoles(address(contracts.core), deployer, contracts.core.OPERATOR());

        _checkRoles(
            address(contracts.deployFactory), deployer, contracts.deployFactory.ADMIN_ROLE()
        );
        _checkRoles(
            address(contracts.deployFactory),
            deployer,
            contracts.deployFactory.ADMIN_DELEGATE_ROLE()
        );
        _checkRoles(address(contracts.deployFactory), deployer, contracts.deployFactory.OPERATOR());

        CoreDeploymentParams memory coreDeploymentParams = Constants.getDeploymentParams();

        require(
            contracts.core.hasRole(contracts.core.ADMIN_ROLE(), coreDeploymentParams.mellowAdmin),
            "mellowAdmin missing Core admin role"
        );
        require(
            contracts.deployFactory.hasRole(
                contracts.deployFactory.ADMIN_ROLE(), coreDeploymentParams.mellowAdmin
            ),
            "mellowAdmin missing DeployFactory admin role"
        );
        require(
            contracts.core.hasRole(contracts.core.OPERATOR(), coreDeploymentParams.coreOperator),
            "coreOperator missing Core operator role"
        );
        require(
            contracts.deployFactory.hasRole(
                contracts.deployFactory.OPERATOR(), coreDeploymentParams.factoryOperator
            ),
            "factoryOperator missing DeployFactory operator role"
        );
    }

    function _checkRoles(address contractAddress, address deployer, bytes32 role) internal view {
        for (
            uint256 i = 0;
            i < IAccessControlEnumerable(contractAddress).getRoleMemberCount(role);
            i++
        ) {
            require(
                IAccessControlEnumerable(contractAddress).getRoleMember(role, i) != deployer,
                "deployer has unexpected role"
            );
        }
    }

    function _findOptSalt(
        uint256 startSalt_,
        bytes memory creationCode,
        bytes memory constructorParams
    ) internal pure returns (bytes32 salt, address addr) {
        bytes32 bytecodeHash = keccak256(abi.encodePacked(creationCode, constructorParams));
        address create2Deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        salt = bytes32(startSalt_);

        uint256 thershold = 1 << (160 - 28);
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x40), bytecodeHash)
            mstore(ptr, create2Deployer)
            let start := add(ptr, 0x0b)
            mstore8(start, 0xff)

            ptr := add(ptr, 0x20)

            for {} 1 { salt := add(salt, 1) } {
                mstore(ptr, salt)
                addr := and(keccak256(start, 85), 0xffffffffffffffffffffffffffffffffffffffff)
                if lt(addr, thershold) { break }
            }
        }
    }

    // Finds a salt whose CREATE2 address starts with 0x0000C05E or 0x0000C08E (case-insensitive).
    function _findOptSaltCore(
        uint256 startSalt_,
        bytes memory creationCode,
        bytes memory constructorParams
    ) internal pure returns (bytes32 salt, address addr) {
        bytes32 bytecodeHash = keccak256(abi.encodePacked(creationCode, constructorParams));
        address create2Deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        salt = bytes32(startSalt_);

        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(add(ptr, 0x40), bytecodeHash)
            mstore(ptr, create2Deployer)
            let start := add(ptr, 0x0b)
            mstore8(start, 0xff)

            ptr := add(ptr, 0x20)
            //mstore(ptr, salt)
            //addr := and(keccak256(salt, 85), 0xffffffffffffffffffffffffffffffffffffffff)

            for {} 1 { salt := add(salt, 1) } {
                mstore(ptr, salt)
                addr := and(keccak256(start, 85), 0xffffffffffffffffffffffffffffffffffffffff)
                // top 4 bytes of the 20-byte address sit in bits 159-128
                let prefix := shr(128, addr)
                if eq(prefix, 0x0000C08E) { break }
            }
        }
    }

    function _deployWithOptimalSalt(
        string memory title,
        bytes memory creationCode,
        bytes memory constructorParams
    ) internal returns (address a) {
        if (!TEST_ENV) {
            bytes32 salt;
            address addr;
            if (keccak256(abi.encodePacked(title)) == keccak256(abi.encodePacked("Core"))) {
                //(salt, addr) = _findOptSaltCore(startSalt, creationCode, constructorParams);
                salt = contractSalts[title];
            } else {
                if (contractSalts[title] != bytes32(0)) {
                    salt = contractSalts[title];
                } else {
                    (salt, addr) = _findOptSalt(startSalt, creationCode, constructorParams);
                    startSalt = uint256(salt) + 1;
                }
            }
            a = Create2.deploy(0, salt, abi.encodePacked(creationCode, constructorParams));
            //require(a == addr, "mismatched address");
            console2.log("salt %s | %s: %s;", uint256(salt), title, a);
        } else {
            a = Create2.deploy(
                0,
                bytes32(uint256(123456789) + deployedContracts),
                abi.encodePacked(creationCode, constructorParams)
            );
            deployedContracts++;
        }
    }
}

contract Deploy is Script, DeployScript, PoolParameters {
    uint256 immutable deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address immutable DEPLOYER = vm.addr(deployerPrivateKey);

    function run() external {
        CoreDeploymentParams memory coreDeploymentParams = Constants.getDeploymentParams();
        deployStrategies();
        vm.startBroadcast(deployerPrivateKey);
        //deployCore(coreDeploymentParams);
        vm.stopBroadcast();
    }

    function deployStrategies() internal {
        CoreDeploymentParams memory coreDeploymentParams = Constants.getDeploymentParams();

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

        _deployStrategies(contracts);
        revert("success");
    }

    function _deployStrategies(CoreDeployment memory contracts) internal {
        CoreDeploymentParams memory coreDeploymentParams = Constants.getDeploymentParams();

        vm.startPrank(coreDeploymentParams.factoryOperator);
        IVeloDeployFactory.DeployParams[] memory params = getPoolDeployParams(contracts);

        uint256 firstIndex = 0;
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
            (bool success,) = to.call{value: 3.5e18}("");
            require(success, "CELO transfer failed");
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
