// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IVeloDeployFactory.sol";
import "./DefaultAccessControl.sol";

contract VeloDeployFactory is DefaultAccessControl, IERC721Receiver, IVeloDeployFactory {
    using SafeERC20 for IERC20;

    string public constant factoryName = "MellowVelodromeStrategy";
    string public constant factorySymbol = "MVS";
    mapping(address => address) public poolToWrapper;
    ICore public immutable core; // Core contract interface
    IERC721 public immutable positionManager; // NFT position manager contract interface
    IVeloFactoryHelper public immutable factoryHelper; // Contract for creating NFT postion with specific parameters.
    address public immutable lpWrapperImplementation;

    address public lpWrapperAdmin;
    address public lpWrapperManager;
    uint256 public minInitialTotalSupply;

    constructor(
        address admin_,
        ICore core_,
        IVeloFactoryHelper factoryHelper_,
        address lpWrapperImplementation_
    ) initializer {
        __DefaultAccessControl_init(admin_);
        core = core_;
        positionManager = IERC721(core.ammModule().positionManager());
        factoryHelper = factoryHelper_;
        lpWrapperImplementation = lpWrapperImplementation_;
    }

    function setLpWrapperAdmin(address lpWrapperAdmin_) external {
        _requireAdmin();
        if (lpWrapperAdmin_ == address(0)) {
            revert AddressZero();
        }
        lpWrapperAdmin = lpWrapperAdmin_;
    }

    function setLpWrapperManager(address lpWrapperManager_) external {
        _requireAdmin();
        lpWrapperAdmin = lpWrapperManager_;
    }

    function setMinInitialTotalSupply(uint256 minInitialTotalSupply_) external {
        _requireAdmin();
        if (minInitialTotalSupply_ == 0) {
            revert InvalidParams();
        }
        minInitialTotalSupply = minInitialTotalSupply_;
    }

    function createStrategy(DeployParams calldata params) external returns (ILpWrapper lpWrapper) {
        _requireAtLeastOperator();

        core.strategyModule().validateStrategyParams(abi.encode(params.strategyParams));
        if (
            params.pool.tickSpacing() != params.strategyParams.tickSpacing
                || minInitialTotalSupply > params.initialTotalSupply
        ) {
            revert InvalidParams();
        }

        lpWrapper = ILpWrapper(Clones.clone(lpWrapperImplementation));

        ICore.DepositParams memory depositParams;
        depositParams.ammPositionIds = factoryHelper.create(
            msg.sender,
            IVeloFactoryHelper.PoolStrategyParameter({
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
                gauge: address(params.pool.gauge())
            })
        );
        depositParams.strategyParams = abi.encode(params.strategyParams);
        depositParams.securityParams = abi.encode(params.securityParams);

        for (uint256 i = 0; i < depositParams.ammPositionIds.length; i++) {
            positionManager.approve(address(core), depositParams.ammPositionIds[i]);
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
        poolToWrapper[address(params.pool)] = address(lpWrapper);

        _emitStrategyCreated(positionId, params.strategyParams);
    }

    function _emitStrategyCreated(
        uint256 positionId,
        IPulseStrategyModule.StrategyParams memory strategyParams
    ) private {
        ICore.ManagedPositionInfo memory position = core.managedPositionAt(positionId);
        StrategyCreatedParams memory strategyCreatedParams = StrategyCreatedParams({
            pool: position.pool,
            ammPosition: new IVeloAmmModule.AmmPosition[](position.ammPositionIds.length),
            strategyParams: strategyParams,
            lpWrapper: poolToWrapper[position.pool],
            caller: msg.sender
        });
        for (uint256 i = 0; i < position.ammPositionIds.length; i++) {
            strategyCreatedParams.ammPosition[i] =
                core.ammModule().getAmmPosition(position.ammPositionIds[i]);
        }
        strategyCreatedParams.ammPosition;

        emit StrategyCreated(strategyCreatedParams);
    }

    /// @inheritdoc IERC721Receiver
    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @inheritdoc IVeloDeployFactory
    function removeWrapperForPool(address pool) external {
        _requireAdmin();
        delete poolToWrapper[pool];
    }

    function configureNameAndSymbol(ICLPool pool)
        public
        view
        returns (string memory name, string memory symbol)
    {
        string memory suffix = string(
            abi.encodePacked(
                ":",
                IERC20Metadata(pool.token0()).symbol(),
                "-",
                IERC20Metadata(pool.token1()).symbol(),
                "-",
                Strings.toString(uint256(int256(ICLPool(pool).tickSpacing())))
            )
        );

        name = string(abi.encodePacked(factoryName, suffix));
        symbol = string(abi.encodePacked(factorySymbol, suffix));
    }
}
