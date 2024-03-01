// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/utils/IVeloDeployFactory.sol";

import "./DefaultAccessControl.sol";

contract VeloDeployFactory is IVeloDeployFactory, DefaultAccessControl {
    using SafeERC20 for IERC20;

    mapping(address => PoolAddresses) private _poolToAddresses;
    mapping(int24 => IVeloDeployFactory.StrategyParams)
        private _tickSpacingToStrategyParams;
    mapping(int24 => ICore.DepositParams) private _tickSpacingToDepositParams;

    bytes32 internal constant STORAGE_SLOT = keccak256("VeloDeployFactory");

    function _contractStorage() internal pure returns (Storage storage s) {
        bytes32 position = STORAGE_SLOT;

        assembly {
            s.slot := position
        }
    }

    constructor(
        address admin_,
        ICore core_,
        IVeloDepositWithdrawModule ammDepositWithdrawModule_,
        IVeloDeployFactoryHelper helper_
    ) DefaultAccessControl(admin_) {
        ImmutableParams memory immutableParams = ImmutableParams({
            core: core_,
            strategyModule: IPulseStrategyModule(
                address(core_.strategyModule())
            ),
            veloModule: IVeloAmmModule(address(core_.ammModule())),
            depositWithdrawModule: ammDepositWithdrawModule_,
            helper: helper_
        });
        _contractStorage().immutableParams = immutableParams;
    }

    /// @inheritdoc IVeloDeployFactory
    function updateStrategyParams(
        int24 tickSpacing,
        StrategyParams memory params
    ) external {
        _requireAdmin();
        _tickSpacingToStrategyParams[tickSpacing] = params;
    }

    /// @inheritdoc IVeloDeployFactory
    function updateDepositParams(
        int24 tickSpacing,
        ICore.DepositParams memory params
    ) external {
        _requireAdmin();
        _tickSpacingToDepositParams[tickSpacing] = params;
    }

    /// @inheritdoc IVeloDeployFactory
    function updateMutableParams(MutableParams memory params) external {
        _requireAdmin();
        _contractStorage().mutableParams = params;
    }

    function _prepareToken(address token, address to, uint256 amount) private {
        IERC20(token).safeIncreaseAllowance(address(to), amount);
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance >= amount) return;
        amount -= balance;
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        uint256 userBalance = IERC20(token).balanceOf(msg.sender);
        if (allowance < amount || userBalance < amount)
            revert(
                string(
                    abi.encodePacked(
                        "Invalid ",
                        IERC20Metadata(token).symbol(),
                        " allowance or balance. Required: ",
                        Strings.toString(amount),
                        "; User balance: ",
                        Strings.toString(userBalance),
                        "; User allowance: ",
                        Strings.toString(allowance),
                        "."
                    )
                )
            );
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    function _mint(
        ICore core,
        IPulseStrategyModule strategyModule,
        IVeloAmmModule veloModule,
        IOracle oracle,
        StrategyParams memory strategyParams,
        ICLPool pool
    ) private returns (uint256 tokenId) {
        INonfungiblePositionManager positionManager = INonfungiblePositionManager(
                veloModule.positionManager()
            );

        (uint160 sqrtPriceX96, int24 tick) = oracle.getOraclePrice(
            address(pool)
        );

        int24 tickSpacing = pool.tickSpacing();

        (
            bool isRebalanceRequired,
            ICore.TargetPositionInfo memory target
        ) = strategyModule.calculateTarget(
                tick,
                type(int24).min,
                type(int24).min,
                IPulseStrategyModule.StrategyParams({
                    tickNeighborhood: strategyParams.tickNeighborhood,
                    tickSpacing: tickSpacing,
                    strategyType: IPulseStrategyModule.StrategyType.Original,
                    width: strategyParams.intervalWidth
                })
            );

        if (!isRebalanceRequired) revert InvalidState();
        {
            (uint256 amount0, uint256 amount1) = veloModule
                .getAmountsForLiquidity(
                    strategyParams.initialLiquidity,
                    sqrtPriceX96,
                    target.lowerTicks[0],
                    target.upperTicks[0]
                );
            address token0 = pool.token0();
            address token1 = pool.token1();
            _prepareToken(token0, address(positionManager), amount0);
            _prepareToken(token1, address(positionManager), amount1);

            uint128 actualMintedLiquidity;
            (tokenId, actualMintedLiquidity, , ) = positionManager.mint(
                INonfungiblePositionManager.MintParams({
                    token0: token0,
                    token1: token1,
                    tickSpacing: tickSpacing,
                    tickLower: target.lowerTicks[0],
                    tickUpper: target.upperTicks[0],
                    amount0Desired: amount0,
                    amount1Desired: amount1,
                    amount0Min: 0,
                    amount1Min: 0,
                    recipient: address(this),
                    deadline: block.timestamp
                })
            );
            if (actualMintedLiquidity < strategyParams.minInitialLiquidity) {
                revert PriceManipulationDetected();
            }
        }

        positionManager.approve(address(core), tokenId);
    }

    /// @inheritdoc IVeloDeployFactory
    function createStrategy(
        address token0,
        address token1,
        int24 tickSpacing
    ) external returns (PoolAddresses memory poolAddresses) {
        _requireAtLeastOperator();

        Storage memory s = _contractStorage();
        ICLPool pool = ICLPool(
            s.immutableParams.veloModule.getPool(
                token0,
                token1,
                uint24(tickSpacing)
            )
        );

        if (address(pool) == address(0)) {
            revert PoolNotFound();
        }

        if (_poolToAddresses[address(pool)].lpWrapper != address(0)) {
            revert LpWrapperAlreadyCreated();
        }

        StrategyParams memory strategyParams = _tickSpacingToStrategyParams[
            tickSpacing
        ];
        if (strategyParams.intervalWidth == 0) {
            revert InvalidStrategyParams();
        }

        ILpWrapper lpWrapper = s.immutableParams.helper.createLpWrapper(
            s.immutableParams.core,
            s.immutableParams.depositWithdrawModule,
            string(
                abi.encodePacked(
                    "MellowVelodromeStrategy-",
                    IERC20Metadata(token0).symbol(),
                    "-",
                    IERC20Metadata(token1).symbol(),
                    "-",
                    Strings.toString(tickSpacing)
                )
            ),
            string(
                abi.encodePacked(
                    "MVS-",
                    IERC20Metadata(token0).symbol(),
                    "-",
                    IERC20Metadata(token1).symbol(),
                    "-",
                    Strings.toString(tickSpacing)
                )
            ),
            s.mutableParams.lpWrapperAdmin
        );

        uint256 positionId;
        {
            ICore.DepositParams
                memory depositParams = _tickSpacingToDepositParams[tickSpacing];
            depositParams.tokenIds = new uint256[](1);
            depositParams.tokenIds[0] = _mint(
                s.immutableParams.core,
                s.immutableParams.strategyModule,
                s.immutableParams.veloModule,
                s.immutableParams.core.oracle(),
                strategyParams,
                pool
            );

            depositParams.owner = address(lpWrapper);
            address farm = address(
                new StakingRewards(
                    s.mutableParams.farmOwner,
                    s.mutableParams.farmOperator,
                    s.mutableParams.rewardsToken,
                    address(lpWrapper)
                )
            );
            depositParams.callbackParams = abi.encode(
                IVeloAmmModule.CallbackParams({
                    farm: farm,
                    gauge: address(pool.gauge())
                })
            );
            depositParams.strategyParams = abi.encode(
                IPulseStrategyModule.StrategyParams({
                    tickNeighborhood: strategyParams.tickNeighborhood,
                    tickSpacing: pool.tickSpacing(),
                    strategyType: strategyParams.strategyType,
                    width: strategyParams.intervalWidth
                })
            );

            positionId = s.immutableParams.core.deposit(depositParams);
            poolAddresses = PoolAddresses({
                lpWrapper: address(lpWrapper),
                synthetixFarm: farm
            });
            _poolToAddresses[address(pool)] = poolAddresses;
        }

        ICore.PositionInfo memory info = s.immutableParams.core.position(
            positionId
        );
        uint256 initialTotalSupply = 0;
        for (uint256 i = 0; i < info.tokenIds.length; i++) {
            IAmmModule.Position memory position = s
                .immutableParams
                .veloModule
                .getPositionInfo(info.tokenIds[i]);
            initialTotalSupply += position.liquidity;
        }
        lpWrapper.initialize(positionId, initialTotalSupply);
    }

    /// @inheritdoc IVeloDeployFactory
    function poolToAddresses(
        address pool
    ) external view returns (PoolAddresses memory) {
        return _poolToAddresses[pool];
    }

    /// @inheritdoc IVeloDeployFactory
    function tickSpacingToStrategyParams(
        int24 tickSpacing
    ) external view returns (StrategyParams memory) {
        return _tickSpacingToStrategyParams[tickSpacing];
    }

    /// @inheritdoc IVeloDeployFactory
    function tickSpacingToDepositParams(
        int24 tickSpacing
    ) external view returns (ICore.DepositParams memory) {
        return _tickSpacingToDepositParams[tickSpacing];
    }

    /// @inheritdoc IVeloDeployFactory
    function removeAddressesForPool(address pool) external {
        _requireAdmin();
        delete _poolToAddresses[pool];
    }

    /// @inheritdoc IVeloDeployFactory
    function getStorage() external pure returns (Storage memory) {
        return _contractStorage();
    }
}
