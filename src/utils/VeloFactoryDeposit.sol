// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/utils/IVeloFactoryDeposit.sol";

import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

contract VeloFactoryDeposit is IVeloFactoryDeposit {
    using SafeERC20 for IERC20;

    ICore public immutable core;
    IPulseStrategyModule public immutable strategyModule;
    INonfungiblePositionManager public immutable positionManager;

    uint16 constant MIN_OBSERVATION_CARDINALITY = 100;

    constructor(ICore core_, IPulseStrategyModule strategyModule_) {
        if (address(core_) == address(0)) {
            revert AddressZero();
        }
        if (address(strategyModule_) == address(0)) {
            revert AddressZero();
        }

        core = core_;
        strategyModule = strategyModule_;
        positionManager = INonfungiblePositionManager(core.ammModule().positionManager());
    }

    /// @inheritdoc IVeloFactoryDeposit
    function mint(
        address depositor,
        address to,
        ICLPool pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public returns (uint256 tokenId) {
        (,,,, uint16 observationCardinalityNext,) = pool.slot0();

        if (observationCardinalityNext < MIN_OBSERVATION_CARDINALITY) {
            pool.increaseObservationCardinalityNext(MIN_OBSERVATION_CARDINALITY);
        }

        (uint160 sqrtPriceX96,,,,,) = pool.slot0();
        IERC20 token0 = IERC20(pool.token0());
        IERC20 token1 = IERC20(pool.token1());
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity
        );

        {
            token0.safeTransferFrom(depositor, address(this), amount0);
            token1.safeTransferFrom(depositor, address(this), amount1);
            token0.safeIncreaseAllowance(address(positionManager), amount0);
            token1.safeIncreaseAllowance(address(positionManager), amount1);
        }

        (tokenId, liquidity,,) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                tickLower: tickLower,
                tickUpper: tickUpper,
                tickSpacing: pool.tickSpacing(),
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: to,
                deadline: block.timestamp + 1,
                sqrtPriceX96: 0
            })
        );

        if (tokenId == 0) {
            revert ZeroNFT();
        }
        if (liquidity == 0) {
            revert ZeroLiquidity();
        }

        _collect(depositor, token0);
        _collect(depositor, token1);

        return tokenId;
    }

    /// @inheritdoc IVeloFactoryDeposit
    function create(
        address depositor,
        address owner,
        PoolStrategyParameter calldata creationParameters
    ) external returns (uint256[] memory tokenIds) {
        if (!core.ammModule().isPool(address(creationParameters.pool))) {
            revert ForbiddenPool();
        }
        if (
            creationParameters.width % creationParameters.pool.tickSpacing() != 0
                || creationParameters.width <= 0 || creationParameters.tickNeighborhood < 0
                || (creationParameters.maxAmount0 == 0 && creationParameters.maxAmount1 == 0)
        ) {
            revert InvalidParams();
        }

        core.oracle().ensureNoMEV(
            address(creationParameters.pool), creationParameters.securityParams
        );

        int24[] memory tickLower;
        int24[] memory tickUpper;
        uint128[] memory liquidity;

        /// @dev get position property for provided parameters
        if (creationParameters.strategyType != IPulseStrategyModule.StrategyType.Tamper) {
            tokenIds = new uint256[](1);
            (tickLower, tickUpper, liquidity) = _getPositionParamPulse(creationParameters);
        } else {
            tokenIds = new uint256[](2);
            (tickLower, tickUpper, liquidity) = _getPositionParamTamper(creationParameters);
        }

        /// @dev check whether tokenId's are provided as parameters, if yes - check them, else mint
        if (
            creationParameters.tokenId.length > 0
                && creationParameters.tokenId.length != tokenIds.length
        ) {
            revert InvalidParams();
        } else if (creationParameters.tokenId.length != 0) {
            /// @dev check given tokenId's
            for (uint256 i = 0; i < creationParameters.tokenId.length; i++) {
                uint256 tokenId = creationParameters.tokenId[i];
                IAmmModule.AmmPosition memory position = core.ammModule().getAmmPosition(tokenId);

                if (
                    position.tickUpper - position.tickLower != tickUpper[i] - tickLower[i]
                        || int24(position.property) != creationParameters.pool.tickSpacing()
                        || position.token0 != creationParameters.pool.token0()
                        || position.token1 != creationParameters.pool.token1()
                ) {
                    revert InvalidParams();
                }
                tokenIds[i] = tokenId;
            }
        } else {
            /// @dev mint positions in favor of depositor
            for (uint256 i = 0; i < tokenIds.length; i++) {
                tokenIds[i] = mint(
                    depositor,
                    owner,
                    creationParameters.pool,
                    tickLower[i],
                    tickUpper[i],
                    liquidity[i]
                );
            }
        }
    }

    function _collect(address depositor, IERC20 token) internal {
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.transfer(depositor, balance);
        }
    }

    function _getPositionParamTamper(PoolStrategyParameter calldata poolParameter)
        private
        view
        returns (int24[] memory tickLower, int24[] memory tickUpper, uint128[] memory liquidity)
    {
        tickLower = new int24[](2);
        tickUpper = new int24[](2);
        liquidity = new uint128[](2);

        (uint160 sqrtPriceX96, int24 tick,,,,) = poolParameter.pool.slot0();

        IAmmModule.AmmPosition memory emptyPosition = IAmmModule.AmmPosition({
            token0: poolParameter.pool.token0(),
            token1: poolParameter.pool.token1(),
            property: uint24(poolParameter.pool.tickSpacing()),
            tickLower: 0,
            tickUpper: 0,
            liquidity: 0
        });

        IPulseStrategyModule.StrategyParams memory strategyParams = IPulseStrategyModule
            .StrategyParams({
            tickNeighborhood: poolParameter.tickNeighborhood,
            tickSpacing: poolParameter.pool.tickSpacing(),
            strategyType: poolParameter.strategyType,
            width: poolParameter.width,
            maxLiquidityRatioDeviationX96: poolParameter.maxLiquidityRatioDeviationX96
        });

        (, ICore.TargetPositionInfo memory target) = strategyModule.calculateTargetTamper(
            sqrtPriceX96, tick, emptyPosition, emptyPosition, strategyParams
        );

        for (uint256 i = 0; i < 2; i++) {
            tickLower[i] = target.lowerTicks[i];
            tickUpper[i] = target.upperTicks[i];
            liquidity[i] = _getLiquidity(
                poolParameter.maxAmount0 / 2,
                poolParameter.maxAmount1 / 2,
                sqrtPriceX96,
                tickLower[i],
                tickUpper[i]
            );
        }
    }

    function _getPositionParamPulse(PoolStrategyParameter calldata poolParameter)
        private
        view
        returns (int24[] memory tickLower, int24[] memory tickUpper, uint128[] memory liquidity)
    {
        tickLower = new int24[](1);
        tickUpper = new int24[](1);
        liquidity = new uint128[](1);

        (uint160 sqrtPriceX96, int24 tick,,,,) = poolParameter.pool.slot0();

        IPulseStrategyModule.StrategyParams memory strategyParams = IPulseStrategyModule
            .StrategyParams({
            tickNeighborhood: poolParameter.tickNeighborhood,
            tickSpacing: poolParameter.pool.tickSpacing(),
            strategyType: poolParameter.strategyType,
            width: poolParameter.width,
            maxLiquidityRatioDeviationX96: 0
        });

        (bool isRebalanceRequired, ICore.TargetPositionInfo memory target) =
            strategyModule.calculateTargetPulse(sqrtPriceX96, tick, 0, 0, strategyParams);

        assert(isRebalanceRequired);

        (tickLower[0], tickUpper[0]) = (target.lowerTicks[0], target.upperTicks[0]);
        liquidity[0] = _getLiquidity(
            poolParameter.maxAmount0,
            poolParameter.maxAmount1,
            sqrtPriceX96,
            tickLower[0],
            tickUpper[0]
        );
    }

    function _getLiquidity(
        uint256 maxAmount0,
        uint256 maxAmount1,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) private pure returns (uint128 liqudity) {
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        liqudity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96, sqrtPriceLowerX96, sqrtPriceUpperX96, maxAmount0, maxAmount1
        );
    }
}
