// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/utils/IVeloDeployFactory.sol";

import "./Counter.sol";
import "./DefaultAccessControl.sol";
import "./StakingRewards.sol";

contract VeloDeployFactory is DefaultAccessControl, IERC721Receiver, IVeloDeployFactory {
    using SafeERC20 for IERC20;

    string public constant factoryName = "MellowVelodromeStrategy";
    string public constant factorySymbol = "MVS";
    mapping(address => PoolAddresses) private _poolToAddresses;
    ImmutableParams private _immutableParams;
    MutableParams private _mutableParams;

    constructor(
        address admin_,
        ICore core_,
        IVeloDepositWithdrawModule ammDepositWithdrawModule_,
        IVeloDeployFactoryHelper helper_,
        IVeloFactoryDeposit factoryDeposit_
    ) DefaultAccessControl(admin_) {
        _immutableParams = ImmutableParams({
            core: core_,
            strategyModule: IPulseStrategyModule(address(core_.strategyModule())),
            veloModule: IVeloAmmModule(address(core_.ammModule())),
            depositWithdrawModule: ammDepositWithdrawModule_,
            helper: helper_,
            factoryDeposit: factoryDeposit_
        });
    }

    /// @inheritdoc IVeloDeployFactory
    function updateMutableParams(MutableParams memory newMutableParams) external {
        _requireAdmin();
        if (
            newMutableParams.farmOperator == address(0) || newMutableParams.farmOwner == address(0)
                || newMutableParams.lpWrapperAdmin == address(0)
                || newMutableParams.minInitialLiquidity == 0
        ) {
            revert InvalidParams();
        }
        _mutableParams = newMutableParams;
    }

    function createLpWrapper(
        ICLPool pool,
        int24 property //tICore.ManagedPositionInfo memory position
    ) internal returns (ILpWrapper lpWrapper) {
        if (_poolToAddresses[address(pool)].lpWrapper != address(0)) {
            revert LpWrapperAlreadyCreated();
        }

        lpWrapper = _immutableParams.helper.createLpWrapper(
            _immutableParams.core,
            string(
                abi.encodePacked(
                    factoryName,
                    "-",
                    IERC20Metadata(pool.token0()).symbol(),
                    "-",
                    IERC20Metadata(pool.token1()).symbol(),
                    "-",
                    Strings.toString(property)
                )
            ),
            string(
                abi.encodePacked(
                    factorySymbol,
                    "-",
                    IERC20Metadata(pool.token0()).symbol(),
                    "-",
                    IERC20Metadata(pool.token1()).symbol(),
                    "-",
                    Strings.toString(property)
                )
            ),
            _mutableParams.lpWrapperAdmin,
            _mutableParams.lpWrapperManager,
            address(pool)
        );
    }

    function createStrategy(DeployParams calldata params)
        external
        returns (PoolAddresses memory poolAddresses)
    {
        _requireAtLeastOperator();

        if (
            params.slippageD9 == 0 || params.securityParams.length == 0
                || (params.tokenId.length == 0 && params.maxAmount0 == 0 && params.maxAmount1 == 0)
                || (
                    params.strategyType == IPulseStrategyModule.StrategyType.Tamper
                        && params.maxLiquidityRatioDeviationX96 == 0
                )
        ) {
            revert InvalidParams();
        }

        ImmutableParams memory immutableParams = _immutableParams;
        MutableParams memory mutableParams = _mutableParams;
        ICore core = immutableParams.core;

        ICore.DepositParams memory depositParams;
        depositParams.ammPositionIds = immutableParams.factoryDeposit.create(
            msg.sender,
            address(this),
            IVeloFactoryDeposit.PoolStrategyParameter({
                tokenId: params.tokenId,
                pool: params.pool,
                strategyType: params.strategyType,
                width: params.width,
                maxAmount0: params.maxAmount0,
                maxAmount1: params.maxAmount1,
                tickNeighborhood: params.tickNeighborhood,
                maxLiquidityRatioDeviationX96: params.maxLiquidityRatioDeviationX96,
                securityParams: params.securityParams
            })
        );

        IPulseStrategyModule.StrategyParams memory strategyParams;
        bytes memory callbackParams;

        {
            poolAddresses.lpWrapper =
                address(createLpWrapper(params.pool, params.pool.tickSpacing()));

            address gauge = params.pool.gauge();
            address rewardToken = ICLGauge(gauge).rewardToken();
            poolAddresses.synthetixFarm = address(
                new StakingRewards(
                    mutableParams.farmOwner,
                    mutableParams.farmOperator,
                    rewardToken,
                    poolAddresses.lpWrapper
                )
            );
            callbackParams = abi.encode(
                IVeloAmmModule.CallbackParams({
                    farm: poolAddresses.synthetixFarm,
                    gauge: address(gauge),
                    counter: address(
                        new Counter(
                            mutableParams.farmOperator,
                            address(core),
                            rewardToken,
                            poolAddresses.synthetixFarm
                        )
                    )
                })
            );
        }

        {
            IAmmModule.AmmPosition memory ammPosition =
                immutableParams.veloModule.getAmmPosition(depositParams.ammPositionIds[0]);

            strategyParams = IPulseStrategyModule.StrategyParams({
                tickNeighborhood: params.tickNeighborhood,
                tickSpacing: int24(params.pool.tickSpacing()),
                strategyType: params.strategyType,
                width: ammPosition.tickUpper - ammPosition.tickLower,
                maxLiquidityRatioDeviationX96: params.maxLiquidityRatioDeviationX96
            });
        }

        depositParams.slippageD9 = params.slippageD9;
        depositParams.owner = poolAddresses.lpWrapper;
        depositParams.callbackParams = callbackParams;
        depositParams.strategyParams = abi.encode(strategyParams);
        depositParams.securityParams = params.securityParams;

        INonfungiblePositionManager positionManager =
            INonfungiblePositionManager(immutableParams.veloModule.positionManager());

        for (uint256 i = 0; i < depositParams.ammPositionIds.length; i++) {
            positionManager.approve(address(core), depositParams.ammPositionIds[i]);
        }

        uint256 positionId = core.deposit(depositParams);

        ILpWrapper(poolAddresses.lpWrapper).initialize(positionId, 1 ether, params.totalSupplyLimit);

        _poolToAddresses[address(params.pool)] = poolAddresses;

        _emitStrategyCreated(core, positionId, strategyParams);
    }

    function _emitStrategyCreated(
        ICore core,
        uint256 positionId, //
        IPulseStrategyModule.StrategyParams memory strategyParams
    ) private {
        ICore.ManagedPositionInfo memory position = core.managedPositionAt(positionId);
        StrategyCreatedParams memory strategyCreatedParams = StrategyCreatedParams({
            pool: position.pool,
            ammPosition: new IVeloAmmModule.AmmPosition[](position.ammPositionIds.length),
            strategyParams: strategyParams,
            lpWrapper: _poolToAddresses[position.pool].lpWrapper,
            synthetixFarm: _poolToAddresses[position.pool].synthetixFarm,
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
    function poolToAddresses(address pool) external view returns (PoolAddresses memory) {
        return _poolToAddresses[pool];
    }

    /// @inheritdoc IVeloDeployFactory
    function getImmutableParams() external view returns (ImmutableParams memory) {
        return _immutableParams;
    }

    /// @inheritdoc IVeloDeployFactory
    function getMutableParams() external view returns (MutableParams memory) {
        return _mutableParams;
    }

    /// @inheritdoc IVeloDeployFactory
    function removeAddressesForPool(address pool) external {
        _requireAdmin();
        delete _poolToAddresses[pool];
    }
}
