// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../interfaces/ICore.sol";
import "../interfaces/modules/velo/IVeloAmmModule.sol";
import "../interfaces/modules/velo/IVeloDepositWithdrawModule.sol";

import "../modules/strategies/PulseStrategyModule.sol";

import "./LpWrapper.sol";
import "./DefaultAccessControl.sol";

import "./external/synthetix/StakingRewards.sol";

contract VeloDeployFactory is DefaultAccessControl {
    using SafeERC20 for IERC20;

    error LpWrapperAlreadyCreated();
    error InvalidStrategyParams();
    error InvalidState();
    error PriceManipulationDetected();

    struct ImmutableParams {
        ICore core;
        PulseStrategyModule strategyModule;
        IVeloAmmModule veloModule;
        IVeloDepositWithdrawModule depositWithdrawModule;
    }

    struct MutableParams {
        address lpWrapperAdmin;
        address farmOwner;
        address farmOperator;
        address rewardsToken;
    }

    struct Storage {
        ImmutableParams immutableParams;
        MutableParams mutableParams;
    }

    struct StrategyParams {
        int24 tickNeighborhood;
        int24 intervalWidth;
        uint128 initialLiquidity;
        uint128 minInitialLiquidity;
    }

    struct PoolAddresses {
        address synthetixFarm;
        address lpWrapper;
    }

    mapping(address => PoolAddresses) private _poolToAddresses;
    mapping(int24 => StrategyParams) public tickSpacingToStrategyParams;
    mapping(int24 => ICore.DepositParams) public tickSpacingToDepositParams;

    bytes32 public constant STORAGE_SLOT = keccak256("VeloDeployFactory");

    function _contractStorage() internal pure returns (Storage storage s) {
        bytes32 position = STORAGE_SLOT;

        assembly {
            s.slot := position
        }
    }

    constructor(
        address admin_,
        ICore core_,
        IVeloDepositWithdrawModule ammDepositWithdrawModule_
    ) DefaultAccessControl(admin_) {
        ImmutableParams memory immutableParams = ImmutableParams({
            core: core_,
            strategyModule: PulseStrategyModule(
                address(core_.strategyModule())
            ),
            veloModule: IVeloAmmModule(address(core_.ammModule())),
            depositWithdrawModule: ammDepositWithdrawModule_
        });
        _contractStorage().immutableParams = immutableParams;
    }

    function updateStrategyParams(
        int24 tickSpacing,
        StrategyParams memory params
    ) external {
        _requireAdmin();
        tickSpacingToStrategyParams[tickSpacing] = params;
    }

    function updateDepositParams(
        int24 tickSpacing,
        ICore.DepositParams memory params
    ) external {
        _requireAdmin();
        tickSpacingToDepositParams[tickSpacing] = params;
    }

    function updateMutableParams(MutableParams memory params) external {
        _requireAdmin();
        _contractStorage().mutableParams = params;
    }

    function _mint(
        ICore core,
        PulseStrategyModule strategyModule,
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
            ICore.TargetNftsInfo memory target
        ) = strategyModule.calculateTarget(
                tick,
                type(int24).min,
                type(int24).min + strategyParams.intervalWidth,
                PulseStrategyModule.StrategyParams({
                    tickNeighborhood: strategyParams.tickNeighborhood,
                    tickSpacing: tickSpacing
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
            {
                uint256 balance = IERC20(token0).balanceOf(address(this));
                if (balance < amount0) {
                    IERC20(token0).safeTransferFrom(
                        msg.sender,
                        address(this),
                        amount0 - balance
                    );
                }
                IERC20(token0).safeIncreaseAllowance(
                    address(positionManager),
                    amount0
                );
            }

            address token1 = pool.token1();
            {
                uint256 balance = IERC20(token1).balanceOf(address(this));
                if (balance < amount1) {
                    IERC20(token1).safeTransferFrom(
                        msg.sender,
                        address(this),
                        amount1 - balance
                    );
                }
                IERC20(token1).safeIncreaseAllowance(
                    address(positionManager),
                    amount1
                );
            }

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

    function createStrategy(
        address token0,
        address token1,
        int24 tickSpacing
    ) external returns (ILpWrapper) {
        _requireAtLeastOperator();

        Storage memory s = _contractStorage();
        ICLPool pool = ICLPool(
            s.immutableParams.veloModule.getPool(
                token0,
                token1,
                uint24(tickSpacing)
            )
        );

        if (_poolToAddresses[address(pool)].lpWrapper != address(0)) {
            revert LpWrapperAlreadyCreated();
        }

        ILpWrapper lpWrapper = new LpWrapper(
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
            )
        );

        StrategyParams memory strategyParams = tickSpacingToStrategyParams[
            tickSpacing
        ];
        if (strategyParams.intervalWidth == 0) {
            revert InvalidStrategyParams();
        }

        uint256 nftId;
        {
            ICore.DepositParams
                memory depositParams = tickSpacingToDepositParams[tickSpacing];
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
            depositParams.farm = pool.gauge();
            depositParams.vault = address(
                new StakingRewards(
                    s.mutableParams.farmOwner,
                    s.mutableParams.farmOperator,
                    s.mutableParams.rewardsToken,
                    address(lpWrapper)
                )
            );
            nftId = s.immutableParams.core.deposit(depositParams);
            _poolToAddresses[address(pool)] = PoolAddresses({
                lpWrapper: address(lpWrapper),
                synthetixFarm: depositParams.vault
            });
        }

        ICore.NftsInfo memory info = s.immutableParams.core.nfts(nftId);
        uint256 initialTotalSupply = 0;
        for (uint256 i = 0; i < info.tokenIds.length; i++) {
            IAmmModule.Position memory position = s
                .immutableParams
                .veloModule
                .getPositionInfo(info.tokenIds[i]);
            initialTotalSupply += position.liquidity;
        }
        lpWrapper.initialize(
            nftId,
            initialTotalSupply,
            s.mutableParams.lpWrapperAdmin
        );

        return lpWrapper;
    }

    function poolToAddresses(
        address pool
    ) external view returns (PoolAddresses memory) {
        return _poolToAddresses[pool];
    }

    function removeAddressesForPool(address pool) external {
        _requireAdmin();
        delete _poolToAddresses[pool];
    }
}
