// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IVeloDeployFactory.sol";

import "../modules/strategies/PulseStrategyModule.sol";
import "./DefaultAccessControl.sol";

contract VeloDeployFactory is DefaultAccessControl, IVeloDeployFactory {
    using SafeERC20 for IERC20;

    string public constant factoryName = "MellowVelodromeStrategy";
    string public constant factorySymbol = "MVS";
    mapping(address => address) public poolToWrapper;
    address public immutable lpWrapperImplementation;

    address public lpWrapperAdmin;
    address public lpWrapperManager;
    uint256 public minInitialTotalSupply;

    ICore public immutable core;
    IPulseStrategyModule public immutable strategyModule;
    INonfungiblePositionManager public immutable positionManager;

    uint16 public constant MIN_OBSERVATION_CARDINALITY = 100;
    uint256 public constant Q96 = 2 ** 96;

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
        positionManager = INonfungiblePositionManager(core.ammModule().positionManager());

        lpWrapperImplementation = lpWrapperImplementation_;
    }

    /// ---------------------- EXTERNAL MUTATING FUNCTIONS ----------------------

    /// @inheritdoc IVeloDeployFactory
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
        depositParams.ammPositionIds = _create(
            msg.sender,
            PoolStrategyParameter({
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

    /// @inheritdoc IVeloDeployFactory
    function removeWrapperForPool(address pool) external {
        _requireAdmin();
        delete poolToWrapper[pool];
        emit WrapperRemoved(pool, msg.sender);
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
            revert InvalidParams();
        }
        minInitialTotalSupply = minInitialTotalSupply_;
        emit MinInitialTotalSupplySet(minInitialTotalSupply_, msg.sender);
    }

    /// ---------------------- PUBLIC VIEW FUNCTIONS ----------------------

    /// @inheritdoc IVeloDeployFactory
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

    /// ----------------  INTERNAL MUTABLE FUNCTIONS  ----------------

    function _create(address depositor, PoolStrategyParameter memory params)
        internal
        returns (uint256[] memory tokenIds)
    {
        ICLPool pool = params.pool;
        if (!core.ammModule().isPool(address(pool))) {
            revert ForbiddenPool();
        }

        core.oracle().ensureNoMEV(address(pool), params.securityParams);
        pool.increaseObservationCardinalityNext(MIN_OBSERVATION_CARDINALITY);

        bool isTamper =
            params.strategyParams.strategyType == IPulseStrategyModule.StrategyType.Tamper;
        tokenIds = new uint256[](isTamper ? 2 : 1);
        MintInfo[] memory mintInfo =
            (isTamper ? _getPositionParamTamper : _getPositionParamPulse)(params);

        IERC20 token0 = IERC20(pool.token0());
        IERC20 token1 = IERC20(pool.token1());
        int24 tickSpacing = pool.tickSpacing();

        _handleToken(depositor, token0, params.maxAmount0);
        _handleToken(depositor, token1, params.maxAmount1);

        for (uint256 i = 0; i < mintInfo.length; i++) {
            (tokenIds[i],,,) = positionManager.mint(
                INonfungiblePositionManager.MintParams({
                    token0: address(token0),
                    token1: address(token1),
                    tickLower: mintInfo[i].tickLower,
                    tickUpper: mintInfo[i].tickUpper,
                    tickSpacing: tickSpacing,
                    amount0Desired: mintInfo[i].amount0,
                    amount1Desired: mintInfo[i].amount1,
                    amount0Min: 0,
                    amount1Min: 0,
                    recipient: address(this),
                    deadline: type(uint256).max,
                    sqrtPriceX96: 0
                })
            );
        }
    }

    /// ----------------  PRIVATE MUTABLE FUNCTIONS  ----------------

    function _handleToken(address depositor, IERC20 token, uint256 amount) private {
        address this_ = address(this);
        uint256 balance = token.balanceOf(this_);
        if (balance < amount) {
            token.safeTransferFrom(depositor, this_, amount - balance);
        }
        if (token.allowance(this_, address(positionManager)) == 0) {
            token.forceApprove(address(positionManager), type(uint256).max);
        }
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

    /// ----------------  PRIVATE VIEW FUNCTIONS  ----------------

    function _getPositionParamTamper(PoolStrategyParameter memory params)
        private
        view
        returns (MintInfo[] memory mintInfo)
    {
        (uint160 sqrtPriceX96, int24 tick,,,,) = params.pool.slot0();
        (, ICore.TargetPositionInfo memory target) = strategyModule.calculateTargetTamper(
            sqrtPriceX96, tick, new IAmmModule.AmmPosition[](0), params.strategyParams
        );
        (uint256 lowerAmount0X96, uint256 lowerAmount1X96) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(target.lowerTicks[0]),
            TickMath.getSqrtRatioAtTick(target.upperTicks[0]),
            uint128(target.liquidityRatiosX96[0])
        );
        (uint256 upperAmount0X96, uint256 upperAmount1X96) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(target.lowerTicks[1]),
            TickMath.getSqrtRatioAtTick(target.upperTicks[1]),
            uint128(Q96 - target.liquidityRatiosX96[0])
        );
        uint256 coefficient = Math.max(
            Math.ceilDiv(lowerAmount0X96 + upperAmount0X96, params.maxAmount0),
            Math.ceilDiv(lowerAmount1X96 + upperAmount1X96, params.maxAmount1)
        );

        mintInfo = new MintInfo[](2);
        mintInfo[0] = MintInfo({
            tickLower: target.lowerTicks[0],
            tickUpper: target.upperTicks[0],
            amount0: lowerAmount0X96 / coefficient,
            amount1: lowerAmount1X96 / coefficient
        });
        mintInfo[1] = MintInfo({
            tickLower: target.lowerTicks[1],
            tickUpper: target.upperTicks[1],
            amount0: upperAmount0X96 / coefficient,
            amount1: upperAmount1X96 / coefficient
        });
    }

    function _getPositionParamPulse(PoolStrategyParameter memory params)
        private
        view
        returns (MintInfo[] memory mintInfo)
    {
        (uint160 sqrtPriceX96, int24 tick,,,,) = params.pool.slot0();
        (, ICore.TargetPositionInfo memory target) = strategyModule.calculateTargetPulse(
            sqrtPriceX96, tick, new IAmmModule.AmmPosition[](0), params.strategyParams
        );
        mintInfo = new MintInfo[](1);
        mintInfo[0] = MintInfo({
            tickLower: target.lowerTicks[0],
            tickUpper: target.upperTicks[0],
            amount0: params.maxAmount0,
            amount1: params.maxAmount1
        });
    }
}
