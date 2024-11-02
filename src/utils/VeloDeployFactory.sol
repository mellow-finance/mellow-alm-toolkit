// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/utils/IVeloDeployFactory.sol";
import "./DefaultAccessControl.sol";

contract VeloDeployFactory is DefaultAccessControl, IERC721Receiver, IVeloDeployFactory {
    using SafeERC20 for IERC20;

    string public constant factoryName = "MellowVelodromeStrategy";
    string public constant factorySymbol = "MVS";
    mapping(address => address) public poolToWrapper;
    ICore public immutable core; // Core contract interface
    IPulseStrategyModule public immutable strategyModule; // Pulse strategy module contract interface
    IVeloAmmModule public immutable veloModule; // Velo AMM module contract interface
    IVeloDepositWithdrawModule public immutable depositWithdrawModule; // Velo deposit/withdraw module contract interface
    IVeloFactoryDeposit public immutable factoryDeposit; // Contract for creating NFT postion with specific parameters.
    address public immutable lpWrapperImplementation;

    MutableParams private _mutableParams;

    constructor(
        address admin_,
        ICore core_,
        IVeloDepositWithdrawModule ammDepositWithdrawModule_,
        IVeloFactoryDeposit factoryDeposit_,
        address lpWrapperImplementation_
    ) {
        __DefaultAccessControl_init(admin_);
        core = core_;
        strategyModule = IPulseStrategyModule(address(core_.strategyModule()));
        veloModule = IVeloAmmModule(address(core_.ammModule()));
        depositWithdrawModule = ammDepositWithdrawModule_;
        factoryDeposit = factoryDeposit_;
        lpWrapperImplementation = lpWrapperImplementation_;
    }

    /// @inheritdoc IVeloDeployFactory
    function updateMutableParams(MutableParams memory newMutableParams) external {
        _requireAdmin();
        if (
            newMutableParams.lpWrapperAdmin == address(0)
                || newMutableParams.minInitialTotalSupply == 0
        ) {
            revert InvalidParams();
        }
        _mutableParams = newMutableParams;
    }

    function createStrategy(DeployParams calldata params) external returns (ILpWrapper lpWrapper) {
        _requireAtLeastOperator();

        core.strategyModule().validateStrategyParams(abi.encode(params.strategyParams));
        MutableParams memory mutableParams = _mutableParams;
        if (
            params.pool.tickSpacing() != params.strategyParams.tickSpacing
                || mutableParams.minInitialTotalSupply > params.initialTotalSupply
        ) {
            revert InvalidParams();
        }

        lpWrapper = ILpWrapper(Clones.clone(lpWrapperImplementation));

        ICore.DepositParams memory depositParams;
        depositParams.ammPositionIds = factoryDeposit.create(
            msg.sender,
            address(this),
            IVeloFactoryDeposit.PoolStrategyParameter({
                tokenId: params.tokenId,
                pool: params.pool,
                strategyType: params.strategyParams.strategyType,
                width: params.strategyParams.width,
                maxAmount0: params.maxAmount0,
                maxAmount1: params.maxAmount1,
                tickNeighborhood: params.strategyParams.tickNeighborhood,
                maxLiquidityRatioDeviationX96: params.strategyParams.maxLiquidityRatioDeviationX96,
                securityParams: params.securityParams
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
        depositParams.securityParams = params.securityParams;

        INonfungiblePositionManager positionManager =
            INonfungiblePositionManager(veloModule.positionManager());

        for (uint256 i = 0; i < depositParams.ammPositionIds.length; i++) {
            positionManager.approve(address(core), depositParams.ammPositionIds[i]);
        }

        uint256 positionId = core.deposit(depositParams);
        (string memory name, string memory symbol) = configureNameAndSymbol(params.pool);
        ILpWrapper(lpWrapper).initialize(
            positionId,
            params.initialTotalSupply,
            params.totalSupplyLimit,
            mutableParams.lpWrapperAdmin,
            mutableParams.lpWrapperManager,
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
    function getMutableParams() external view returns (MutableParams memory) {
        return _mutableParams;
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
                " ",
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
