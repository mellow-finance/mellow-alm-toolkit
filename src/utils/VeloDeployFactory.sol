// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IVeloDeployFactory.sol";

import
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "src/libraries/PulseStrategyModuleHelper.sol";

contract VeloDeployFactory is AccessControlEnumerableUpgradeable, IVeloDeployFactory {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    bytes32 public constant MANAGER_ROLE = keccak256("utils.VeloDeployFactory.MANAGER_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("utils.VeloDeployFactory.PROPOSER_ROLE");

    /// @dev Mapping of pool addresses to their corresponding LpWrapper sets
    mapping(address => EnumerableSet.AddressSet) private _poolWrappers;

    /// @dev Set of all deployed LP wrappers
    EnumerableSet.AddressSet private _lpWrappers;

    /// @dev Mapping of LpWrapper addresses to their corresponding LpStaker
    mapping(address => address) private _lpWrapperStaker;

    /// @dev Mapping of proposal DeployParams IDs
    mapping(bytes32 => DeployParams) private _deployParams;

    /// @dev Mapping of proposal DeployParams IDs to their corresponding status or LpWrapper address, see @param DeployParamsStatus
    mapping(bytes32 => uint160) private _deployParamsStatus;

    /// @dev Mapping of LpWrapper to their LpStaker deploy parameters
    mapping(address => LpStakerParams) private _lpStakerParams;

    address public lpWrapperAdmin;
    address public lpWrapperManager;
    address public lpWrapperOperator;

    uint256 public minInitialTotalSupply;

    ICore public immutable core;
    IAmmModule public immutable ammModule;
    IPulseStrategyModule public immutable strategyModule;
    address public immutable lpWrapperImplementation;
    address public immutable lpStakerImplementation;

    /// ---------------------- INITIALIZER FUNCTIONS ----------------------

    constructor(
        ICore core_,
        IPulseStrategyModule strategyModule_,
        address lpWrapperImplementation_,
        address lpStakerImplementation_
    ) {
        if (
            address(core_) == address(0) || address(strategyModule_) == address(0)
                || lpWrapperImplementation_ == address(0) || lpStakerImplementation_ == address(0)
        ) {
            revert AddressZero();
        }
        core = core_;
        strategyModule = strategyModule_;
        ammModule = core.ammModule();

        lpWrapperImplementation = lpWrapperImplementation_;
        lpStakerImplementation = lpStakerImplementation_;
    }

    function initialize(
        address admin_,
        address manager_,
        address proposer_,
        address lpWrapperAdmin_,
        address lpWrapperManager_,
        address lpWrapperOperator_,
        uint256 minInitialTotalSupply_
    ) external initializer {
        if (
            admin_ == address(0) || manager_ == address(0) || proposer_ == address(0)
                || lpWrapperAdmin_ == address(0) || lpWrapperManager_ == address(0)
                || lpWrapperOperator_ == address(0)
        ) {
            revert AddressZero();
        }
        __AccessControlEnumerable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MANAGER_ROLE, manager_);
        _grantRole(PROPOSER_ROLE, proposer_);
        lpWrapperAdmin = lpWrapperAdmin_;
        lpWrapperManager = lpWrapperManager_;
        lpWrapperOperator = lpWrapperOperator_;

        _setMinInitialTotalSupply(minInitialTotalSupply_);
    }

    /// ---------------------- EXTERNAL MUTATING FUNCTIONS ----------------------

    receive() external payable {}

    /// @inheritdoc IVeloDeployFactory
    function claim(address token) external onlyRole(MANAGER_ROLE) {
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
        onlyRole(PROPOSER_ROLE)
        returns (bytes32 proposalId)
    {
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

        if (params.slippageD9 > core.MAX_SLIPPAGE_D9() || params.slippageD9 == 0) {
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
    function acceptDeployParams(bytes32 proposalId) external onlyRole(MANAGER_ROLE) {
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
            PulseStrategyModuleHelper.PoolStrategyParameter({
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
                gauge: address(ammModule.getGauge(params.pool)),
                extraData: params.callbackExtraData
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
    function approveLpStaker(address lpWrapper, LpStakerParams memory params)
        external
        onlyRole(MANAGER_ROLE)
    {
        if (!_lpWrappers.contains(lpWrapper)) {
            revert LpWrapperNotExists(lpWrapper);
        }
        if (_lpWrapperStaker[lpWrapper] != address(0)) {
            revert LpWrapperAlreadyHasStaker(lpWrapper, _lpWrapperStaker[lpWrapper]);
        }
        if (
            params.timeLock < ILpStaker(lpStakerImplementation).MIN_TIMELOCK_DURATION()
                || params.timeLock > ILpStaker(lpStakerImplementation).MAX_TIMELOCK_DURATION()
        ) {
            revert InvalidDeployParams();
        }
        LpStakerParams memory deployedParams = _lpStakerParams[lpWrapper];
        if (deployedParams.timeLock != 0 || deployedParams.minStakeAmount != 0) {
            revert LpStakerAlreadyApproved();
        }
        _lpStakerParams[lpWrapper] = params;
        emit LpStakerApproved(
            ILpWrapper(lpWrapper).pool(), lpWrapper, params.timeLock, params.minStakeAmount
        );
    }

    /// @inheritdoc IVeloDeployFactory
    function deployStaker(address lpWrapper) external returns (ILpStaker lpStaker) {
        if (!_lpWrappers.contains(lpWrapper)) {
            revert LpWrapperNotExists(lpWrapper);
        }
        if (_lpWrapperStaker[lpWrapper] != address(0)) {
            revert LpWrapperAlreadyHasStaker(lpWrapper, _lpWrapperStaker[lpWrapper]);
        }
        LpStakerParams memory params = _lpStakerParams[lpWrapper];
        if (params.timeLock == 0 || params.minStakeAmount == 0) {
            revert LpStakerNotApproved();
        }

        lpStaker = ILpStaker(Clones.clone(lpStakerImplementation));
        lpStaker.initialize(
            ILpWrapper(lpWrapper),
            lpWrapperAdmin,
            lpWrapperOperator,
            params.timeLock,
            params.minStakeAmount
        );

        _lpWrapperStaker[lpWrapper] = address(lpStaker);

        emit LpStakerDeployed(address(lpStaker), lpWrapper, msg.sender);
    }

    /// @inheritdoc IVeloDeployFactory
    function setLpWrapperAdmin(address lpWrapperAdmin_) external onlyRole(MANAGER_ROLE) {
        if (lpWrapperAdmin_ == address(0)) {
            revert AddressZero();
        }
        lpWrapperAdmin = lpWrapperAdmin_;
        emit LpWrapperAdminSet(lpWrapperAdmin_, msg.sender);
    }

    /// @inheritdoc IVeloDeployFactory
    function setLpWrapperManager(address lpWrapperManager_) external onlyRole(MANAGER_ROLE) {
        lpWrapperManager = lpWrapperManager_;
        emit LpWrapperManagerSet(lpWrapperManager_, msg.sender);
    }

    /// @inheritdoc IVeloDeployFactory
    function setLpWrapperOperator(address lpWrapperOperator_) external onlyRole(MANAGER_ROLE) {
        lpWrapperOperator = lpWrapperOperator_;
        emit LpWrapperOperatorSet(lpWrapperOperator_, msg.sender);
    }

    /// @inheritdoc IVeloDeployFactory

    function setMinInitialTotalSupply(uint256 minInitialTotalSupply_)
        external
        onlyRole(MANAGER_ROLE)
    {
        _setMinInitialTotalSupply(minInitialTotalSupply_);
    }

    function _setMinInitialTotalSupply(uint256 minInitialTotalSupply_) internal {
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
    function lpWrapperToStaker(address lpWrapper) external view returns (address) {
        return _lpWrapperStaker[lpWrapper];
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

    function _create(
        address depositor,
        PulseStrategyModuleHelper.PoolStrategyParameter memory params
    ) private returns (uint256[] memory tokenIds) {
        core.oracle().ensureNoMEV(params.pool, params.securityParams);

        IAmmModule.MintInfo[] memory mintInfo =
            PulseStrategyModuleHelper.getMintParams(params, ammModule, strategyModule);

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

        emit StrategyCreated(
            ILpWrapper(lpWrapper).pool(), lpWrapper, msg.sender, strategyCreatedParams
        );
    }
}
