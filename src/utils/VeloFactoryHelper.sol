// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/utils/IVeloFactoryHelper.sol";
import "../modules/strategies/PulseStrategyModule.sol";

contract VeloFactoryHelper is IVeloFactoryHelper {
    using SafeERC20 for IERC20;

    ICore public immutable core;
    IPulseStrategyModule public immutable strategyModule;
    INonfungiblePositionManager public immutable positionManager;

    uint16 public constant MIN_OBSERVATION_CARDINALITY = 100;
    uint256 public constant Q96 = 2 ** 96;

    constructor(ICore core_, IPulseStrategyModule strategyModule_) {
        if (address(core_) == address(0) || address(strategyModule_) == address(0)) {
            revert AddressZero();
        }

        core = core_;
        strategyModule = strategyModule_;
        positionManager = INonfungiblePositionManager(core.ammModule().positionManager());
    }

    /// @inheritdoc IVeloFactoryHelper
    function create(address depositor, PoolStrategyParameter calldata params)
        external
        returns (uint256[] memory tokenIds)
    {
        if (msg.sender != address(core)) {
            revert Forbidden();
        }
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
        _handleToken(depositor, token1, params.maxAmount0);

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
                    recipient: address(core),
                    deadline: type(uint256).max,
                    sqrtPriceX96: 0
                })
            );
        }
    }

    function collect(address depositor, IERC20 token) external {
        if (!core.hasRole(keccak256("operator"), msg.sender)) {
            revert Forbidden();
        }
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.transfer(depositor, balance);
        }
    }

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

    function _getPositionParamTamper(PoolStrategyParameter calldata params)
        private
        view
        returns (MintInfo[] memory mintInfo)
    {
        (uint160 sqrtPriceX96, int24 tick,,,,) = params.pool.slot0();
        ICore.TargetPositionInfo memory target;
        {
            IAmmModule.AmmPosition memory position;
            (, target) = TamperStrategyLibrary.calculateTarget(
                sqrtPriceX96, tick, position, position, params.strategyParams
            );
        }
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

    function _getPositionParamPulse(PoolStrategyParameter calldata params)
        private
        view
        returns (MintInfo[] memory mintInfo)
    {
        (uint160 sqrtPriceX96, int24 tick,,,,) = params.pool.slot0();
        (, ICore.TargetPositionInfo memory target) =
            PulseStrategyLibrary.calculateTarget(sqrtPriceX96, tick, 0, 0, params.strategyParams);
        mintInfo = new MintInfo[](1);
        mintInfo[0] = MintInfo({
            tickLower: target.lowerTicks[0],
            tickUpper: target.upperTicks[0],
            amount0: params.maxAmount0,
            amount1: params.maxAmount1
        });
    }
}
