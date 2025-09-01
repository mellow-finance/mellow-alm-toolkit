// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IVeloDeployFactory.sol";

import "../modules/strategies/PulseStrategyModule.sol";
import "./DefaultAccessControl.sol";

contract VeloDeployFactory is DefaultAccessControl, IVeloDeployFactory {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /// @dev Mapping of pool addresses to their corresponding LpWrapper sets
    mapping(address => EnumerableSet.AddressSet) private _poolWrappers;

    /// @dev Set of all deployed LP wrappers
    EnumerableSet.AddressSet private _lpWrappers;

    /// @dev Mapping of proposal DeployParams IDs
    mapping(bytes32 => DeployParams) private _deployParams;

    /// @dev Mapping of proposal DeployParams IDs to their corresponding status or LpWrapper address, see @param DeployParamsStatus
    mapping(bytes32 => uint160) private _deployParamsStatus;

    /// @dev Position parameters for minting

    address public lpWrapperAdmin;
    address public lpWrapperManager;
    uint256 public minInitialTotalSupply;

    ICore public immutable core;
    IAmmModule public immutable ammModule;
    IPulseStrategyModule public immutable strategyModule;
    address public immutable lpWrapperImplementation;

    /// ---------------------- INITIALIZER FUNCTIONS ----------------------

    constructor(
        address admin_,
        ICore core_,
        IPulseStrategyModule strategyModule_,
        address lpWrapperImplementation_
    ) initializer {
        __DefaultAccessControl_init(admin_);
        core = core_;
        strategyModule = strategyModule_;
        ammModule = core.ammModule();

        lpWrapperImplementation = lpWrapperImplementation_;
    }

    /// ---------------------- EXTERNAL MUTATING FUNCTIONS ----------------------

    receive() external payable {}

    /// @inheritdoc IVeloDeployFactory
    function claim(address token) external {
        _requireAtLeastOperator();
        address sender = msg.sender;
        if (token == address(0)) {
            Address.sendValue(payable(sender), address(this).balance);
        } else {
            IERC20(token).safeTransfer(sender, IERC20(token).balanceOf(address(this)));
        }
    }

    /// @inheritdoc IVeloDeployFactory
    function proposeDeployParams(DeployParams memory params)
        external
        returns (bytes32 proposalId)
    {
        _requireAtLeastProposer();
        if (!core.ammModule().isPool(params.pool)) {
            revert ForbiddenPool();
        }
        core.strategyModule().validateStrategyParams(abi.encode(params.strategyParams));
        core.oracle().validateSecurityParams(abi.encode(params.securityParams));
        if (
            ammModule.getProperty(params.pool) != uint24(params.strategyParams.tickSpacing)
                || minInitialTotalSupply > params.initialTotalSupply
        ) {
            revert InvalidDeployParams();
        }

        proposalId = deployParamsHash(params);

        if (_deployParamsStatus[proposalId] > uint160(DeployParamsStatus.None)) {
            revert DeployParamsAlreadyProposed(proposalId);
        }
        _deployParamsStatus[proposalId] = uint160(DeployParamsStatus.Proposed);
        _deployParams[proposalId] = params;

        emit DeployParamsProposed(proposalId, msg.sender, params);
    }

    /// @inheritdoc IVeloDeployFactory
    function acceptDeployParams(bytes32 proposalId) external {
        _requireAtLeastOperator();

        uint160 status = _deployParamsStatus[proposalId];
        if (status == uint160(DeployParamsStatus.None)) {
            revert DeployParamsNotProposed(proposalId);
        } else if (status == uint160(DeployParamsStatus.Accepted)) {
            revert DeployParamsAlreadyAccepted(proposalId);
        } else if (status != uint160(DeployParamsStatus.Proposed)) {
            revert DeployParamsAlreadyDeployed(proposalId, address(status));
        }
        _deployParamsStatus[proposalId] = uint160(DeployParamsStatus.Accepted);

        emit DeployParamsAccepted(proposalId);
    }

    /// @inheritdoc IVeloDeployFactory
    function deployStrategy(bytes32 proposalId) external returns (ILpWrapper lpWrapper) {
        _requireAtLeastOperator();

        uint160 status = _deployParamsStatus[proposalId];
        if (status == uint160(DeployParamsStatus.None)) {
            revert DeployParamsNotProposed(proposalId);
        } else if (status == uint160(DeployParamsStatus.Proposed)) {
            revert DeployParamsNotAccepted(proposalId);
        } else if (status > uint160(DeployParamsStatus.Accepted)) {
            revert DeployParamsAlreadyDeployed(proposalId, address(status));
        }

        DeployParams memory params = _deployParams[proposalId];

        lpWrapper = ILpWrapper(Clones.clone(lpWrapperImplementation));

        ICore.DepositParams memory depositParams;
        depositParams.ammPositionIds = _create(
            msg.sender,
            IPulseStrategyModule.PoolStrategyParameter({
                pool: params.pool,
                strategyParams: params.strategyParams,
                maxAmount0: params.maxAmount0,
                maxAmount1: params.maxAmount1,
                securityParams: abi.encode(params.securityParams)
            })
        );

        depositParams.slippageD9 = params.slippageD9;
        depositParams.owner = address(lpWrapper);
        depositParams.callbackParams = abi.encode(
            IVeloAmmModule.CallbackParams({
                farm: address(lpWrapper),
                gauge: address(ammModule.getGauge(params.pool))
            })
        );
        depositParams.strategyParams = abi.encode(params.strategyParams);
        depositParams.securityParams = abi.encode(params.securityParams);

        for (uint256 i = 0; i < depositParams.ammPositionIds.length; i++) {
            bytes memory response = Address.functionDelegateCall(
                address(ammModule),
                abi.encodeWithSelector(
                    IAmmModule.approveTokenId.selector,
                    address(core),
                    depositParams.ammPositionIds[i]
                )
            );
            if (response.length > 0) {
                revert NonfungiblePositionApproveFailed();
            }
        }

        uint256 positionId = core.deposit(depositParams);
        (string memory name, string memory symbol) = configureNameAndSymbol(params.pool);
        ILpWrapper(lpWrapper).initialize(
            positionId,
            params.initialTotalSupply,
            params.totalSupplyLimit,
            lpWrapperAdmin,
            lpWrapperManager,
            name,
            symbol
        );

        _poolWrappers[params.pool].add(address(lpWrapper));
        _deployParamsStatus[proposalId] = uint160(address(lpWrapper));
        if (!_lpWrappers.add(address(lpWrapper))) {
            revert LpWrapperAlreadyExists(address(lpWrapper));
        }

        _emitStrategyCreated(positionId, address(lpWrapper), params.strategyParams);
    }

    /// @inheritdoc IVeloDeployFactory
    function setLpWrapperAdmin(address lpWrapperAdmin_) external {
        _requireAdmin();
        if (lpWrapperAdmin_ == address(0)) {
            revert AddressZero();
        }
        lpWrapperAdmin = lpWrapperAdmin_;
        emit LpWrapperAdminSet(lpWrapperAdmin_, msg.sender);
    }

    /// @inheritdoc IVeloDeployFactory
    function setLpWrapperManager(address lpWrapperManager_) external {
        _requireAdmin();
        lpWrapperManager = lpWrapperManager_;
        emit LpWrapperManagerSet(lpWrapperManager_, msg.sender);
    }

    /// @inheritdoc IVeloDeployFactory
    function setMinInitialTotalSupply(uint256 minInitialTotalSupply_) external {
        _requireAdmin();
        if (minInitialTotalSupply_ == 0 || minInitialTotalSupply_ > 1 ether) {
            revert InvalidTotalSupplyValue();
        }
        minInitialTotalSupply = minInitialTotalSupply_;
        emit MinInitialTotalSupplySet(minInitialTotalSupply_, msg.sender);
    }

    /// ---------------------- EXTERNAL VIEW FUNCTIONS ----------------------

    /// @inheritdoc IVeloDeployFactory
    function deployParamsHash(DeployParams memory deployParams) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                deployParams.slippageD9,
                deployParams.strategyParams,
                deployParams.securityParams,
                deployParams.pool
            )
        );
    }

    /// @inheritdoc IVeloDeployFactory
    function getLpWrapperCount() external view returns (uint256) {
        return _lpWrappers.length();
    }

    /// @inheritdoc IVeloDeployFactory
    function getLpWrapperByIndex(uint256 index) external view returns (ILpWrapper) {
        if (index >= _lpWrappers.length()) {
            revert InvalidIndex();
        }
        return ILpWrapper(_lpWrappers.at(index));
    }

    /// @inheritdoc IVeloDeployFactory
    function getDeployParamsById(bytes32 proposalId) external view returns (DeployParams memory) {
        return _deployParams[proposalId];
    }

    /// @inheritdoc IVeloDeployFactory
    function getDeployParamsStatusById(bytes32 proposalId) external view returns (uint160) {
        return _deployParamsStatus[proposalId];
    }

    /// @inheritdoc IVeloDeployFactory
    function getDeployParamsStatus(DeployParams memory deployParams)
        external
        view
        returns (uint160)
    {
        return _deployParamsStatus[deployParamsHash(deployParams)];
    }

    /// @inheritdoc IVeloDeployFactory
    function isProposedDeployParams(DeployParams memory deployParams)
        external
        view
        returns (bool)
    {
        return _deployParamsStatus[deployParamsHash(deployParams)]
            == uint160(DeployParamsStatus.Proposed);
    }

    /// @inheritdoc IVeloDeployFactory
    function isAcceptedDeployParams(DeployParams memory deployParams)
        external
        view
        returns (bool)
    {
        return _deployParamsStatus[deployParamsHash(deployParams)]
            == uint160(DeployParamsStatus.Accepted);
    }

    /// @inheritdoc IVeloDeployFactory
    function isDeployedDeployParams(DeployParams memory deployParams)
        external
        view
        returns (bool)
    {
        return _deployParamsStatus[deployParamsHash(deployParams)]
            > uint160(DeployParamsStatus.Accepted);
    }

    /// @inheritdoc IVeloDeployFactory
    function deployParamsToWrapper(DeployParams memory deployParams)
        external
        view
        returns (ILpWrapper)
    {
        bytes32 proposalId = deployParamsHash(deployParams);
        uint160 status = _deployParamsStatus[proposalId];
        if (status <= uint160(DeployParamsStatus.Accepted)) {
            revert DeployParamsNotDeployed(proposalId);
        }
        return ILpWrapper(address(status));
    }

    /// @inheritdoc IVeloDeployFactory
    function isEntity(address lpWrapper) external view returns (bool) {
        return _lpWrappers.contains(lpWrapper);
    }

    /// @inheritdoc IVeloDeployFactory
    function isEntity(address lpWrapper, address pool) external view returns (bool) {
        return _poolWrappers[pool].contains(lpWrapper);
    }

    /// @inheritdoc IVeloDeployFactory
    function poolToWrappers(address pool) external view returns (address[] memory) {
        return _poolWrappers[pool].values();
    }

    /// @inheritdoc IVeloDeployFactory
    function configureNameAndSymbol(address pool)
        public
        view
        returns (string memory name, string memory symbol)
    {
        (address token0, address token1) = ammModule.getPoolTokens(pool);
        string memory suffix = string(
            abi.encodePacked(
                ":",
                IERC20Metadata(token0).symbol(),
                "-",
                IERC20Metadata(token1).symbol(),
                "-",
                Strings.toString(uint256(ammModule.getProperty(pool)))
            )
        );

        name = string(abi.encodePacked("Mellow", ammModule.protocolName(), "Strategy", suffix));
        symbol = string(abi.encodePacked("M", ammModule.protocolLetter(), "S", suffix));
    }

    /// ----------------  PRIVATE MUTABLE FUNCTIONS  ----------------

    function _create(address depositor, IPulseStrategyModule.PoolStrategyParameter memory params)
        private
        returns (uint256[] memory tokenIds)
    {
        core.oracle().ensureNoMEV(params.pool, params.securityParams);

        IAmmModule.MintInfo[] memory mintInfo = strategyModule.getMintParams(params, ammModule);

        bytes memory response = Address.functionDelegateCall(
            address(ammModule),
            abi.encodeWithSelector(IAmmModule.mint.selector, depositor, mintInfo)
        );

        if (response.length != 0x40 + 0x20 * mintInfo.length) {
            revert NonfungiblePositionMintError();
        }

        return abi.decode(response, (uint256[]));
    }

    function _emitStrategyCreated(
        uint256 positionId,
        address lpWrapper,
        IPulseStrategyModule.StrategyParams memory strategyParams
    ) private {
        ICore.ManagedPositionInfo memory position = core.managedPositionAt(positionId);
        StrategyCreatedParams memory strategyCreatedParams = StrategyCreatedParams({
            pool: position.pool,
            ammPosition: new IVeloAmmModule.AmmPosition[](position.ammPositionIds.length),
            strategyParams: strategyParams,
            lpWrapper: lpWrapper,
            caller: msg.sender
        });
        for (uint256 i = 0; i < position.ammPositionIds.length; i++) {
            strategyCreatedParams.ammPosition[i] =
                core.ammModule().getAmmPosition(position.ammPositionIds[i]);
        }

        emit StrategyCreated(strategyCreatedParams);
    }
}
