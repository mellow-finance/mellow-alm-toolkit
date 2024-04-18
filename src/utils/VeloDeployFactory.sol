// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@synthetix/contracts/StakingRewards.sol";

import "../interfaces/utils/IVeloDeployFactory.sol";

import "./Counter.sol";
import "./DefaultAccessControl.sol";

contract VeloDeployFactory is
    DefaultAccessControl,
    IERC721Receiver,
    IVeloDeployFactory
{
    mapping(address => PoolAddresses) private _poolToAddresses;
    ImmutableParams private _immutableParams;
    MutableParams private _mutableParams;

    constructor(
        address admin_,
        ICore core_,
        IVeloDepositWithdrawModule ammDepositWithdrawModule_,
        IVeloDeployFactoryHelper helper_
    ) DefaultAccessControl(admin_) {
        _immutableParams = ImmutableParams({
            core: core_,
            strategyModule: IPulseStrategyModule(
                address(core_.strategyModule())
            ),
            veloModule: IVeloAmmModule(address(core_.ammModule())),
            depositWithdrawModule: ammDepositWithdrawModule_,
            helper: helper_
        });
    }

    /// @inheritdoc IVeloDeployFactory
    function updateMutableParams(
        MutableParams memory newMutableParams
    ) external {
        _requireAdmin();
        _mutableParams = newMutableParams;
    }

    /// @inheritdoc IVeloDeployFactory
    function createStrategy(
        DeployParams calldata params
    ) external returns (PoolAddresses memory poolAddresses) {
        _requireAtLeastOperator();

        if (
            params.slippageD4 == 0 ||
            params.securityParams.length == 0 ||
            params.tokenId == 0
        ) {
            revert InvalidParams();
        }

        ImmutableParams memory immutableParams = _immutableParams;
        MutableParams memory mutableParams = _mutableParams;

        ICore core = immutableParams.core;
        IVeloAmmModule ammModule = immutableParams.veloModule;
        IAmmModule.AmmPosition memory position = ammModule.getAmmPosition(
            params.tokenId
        );
        if (position.liquidity < 1000) revert InvalidParams();

        ICLPool pool = ICLPool(
            ammModule.getPool(
                position.token0,
                position.token1,
                position.property
            )
        );

        if (_poolToAddresses[address(pool)].lpWrapper != address(0)) {
            revert LpWrapperAlreadyCreated();
        }

        core.oracle().ensureNoMEV(address(pool), params.securityParams);

        ILpWrapper lpWrapper = immutableParams.helper.createLpWrapper(
            core,
            immutableParams.depositWithdrawModule,
            string(
                abi.encodePacked(
                    "MellowVelodromeStrategy-",
                    IERC20Metadata(position.token0).symbol(),
                    "-",
                    IERC20Metadata(position.token1).symbol(),
                    "-",
                    Strings.toString(position.property)
                )
            ),
            string(
                abi.encodePacked(
                    "MVS-",
                    IERC20Metadata(position.token0).symbol(),
                    "-",
                    IERC20Metadata(position.token1).symbol(),
                    "-",
                    Strings.toString(position.property)
                )
            ),
            mutableParams.lpWrapperAdmin,
            mutableParams.farmOperator
        );

        ICore.DepositParams memory depositParams;
        depositParams.securityParams = params.securityParams;
        depositParams.slippageD4 = params.slippageD4;
        depositParams.ammPositionIds = new uint256[](1);
        depositParams.ammPositionIds[0] = params.tokenId;
        depositParams.owner = address(lpWrapper);
        poolAddresses.lpWrapper = address(lpWrapper);
        address gauge = pool.gauge();
        address rewardToken = ICLGauge(gauge).rewardToken();
        poolAddresses.synthetixFarm = immutableParams
            .helper
            .createStakingRewards(
                mutableParams.farmOwner,
                mutableParams.farmOperator,
                rewardToken,
                address(lpWrapper)
            );
        depositParams.callbackParams = abi.encode(
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
        depositParams.strategyParams = abi.encode(
            IPulseStrategyModule.StrategyParams({
                tickNeighborhood: params.tickNeighborhood,
                tickSpacing: int24(position.property),
                strategyType: params.strategyType,
                width: position.tickUpper - position.tickLower
            })
        );

        _poolToAddresses[address(pool)] = poolAddresses;
        INonfungiblePositionManager(ammModule.positionManager()).transferFrom(
            msg.sender,
            address(this),
            params.tokenId
        );
        INonfungiblePositionManager(ammModule.positionManager()).approve(
            address(core),
            params.tokenId
        );

        lpWrapper.initialize(core.deposit(depositParams), position.liquidity);
    }

    /// @inheritdoc IERC721Receiver
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @inheritdoc IVeloDeployFactory
    function poolToAddresses(
        address pool
    ) external view returns (PoolAddresses memory) {
        return _poolToAddresses[pool];
    }

    /// @inheritdoc IVeloDeployFactory
    function getImmutableParams()
        external
        view
        returns (ImmutableParams memory)
    {
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
