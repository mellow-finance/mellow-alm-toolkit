// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import "../interfaces/utils/IVeloFactoryDeposit.sol";
import "src/libraries/external/LiquidityAmounts.sol";
import "src/libraries/external/TickMath.sol";

contract VeloFactoryDeposit is IVeloFactoryDeposit {
    using SafeERC20 for IERC20;

    ICore public immutable core;
    ICLFactory public immutable poolFactory;
    IVeloDeployFactory public immutable deployFactory;
    INonfungiblePositionManager public immutable positionManager;
    address private immutable depositor;

    uint16 constant MIN_OBSERVATION_CARDINALITY = 100;
    int24 constant TICK_NEIGHBORHOOD = 0;

    constructor(
        address depositor_,
        address core_,
        address deployFactory_,
        address poolFactory_,
        address positionManager_
    ) {
        if (depositor_ == address(0)) revert AddressZero();
        if (core_ == address(0)) revert AddressZero();
        if (deployFactory_ == address(0)) revert AddressZero();
        if (positionManager_ == address(0)) revert AddressZero();

        depositor = depositor_;
        core = ICore(core_);
        deployFactory = IVeloDeployFactory(deployFactory_);
        positionManager = INonfungiblePositionManager(positionManager_);
        poolFactory = ICLFactory(poolFactory_);
    }

    function _requireDepositior() internal view {
        if (msg.sender != depositor) {
            revert Forbidden();
        }
    }

    function mint(
        ICLPool pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public returns (uint256 tokenId) {
        _requireDepositior();

        (, , , , uint16 observationCardinalityNext, ) = pool.slot0();

        if (observationCardinalityNext < MIN_OBSERVATION_CARDINALITY) {
            pool.increaseObservationCardinalityNext(
                MIN_OBSERVATION_CARDINALITY
            );
        }

        IERC20 token0 = IERC20(pool.token0());
        IERC20 token1 = IERC20(pool.token1());
        (uint160 sqrtPriceX96, , , , , ) = pool.slot0();

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );

        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);

        token0.safeIncreaseAllowance(address(positionManager), amount0);
        token1.safeIncreaseAllowance(address(positionManager), amount1);

        (tokenId, , , ) = positionManager.mint(
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
                recipient: address(this),
                deadline: block.timestamp + 1,
                sqrtPriceX96: 0
            })
        );

        if (tokenId == 0) revert ZeroNFT();
        if (liquidity == 0) revert ZeroLiquidity();

        return tokenId;
    }

    function create(
        PoolStrategyParameter calldata creationParameters
    )
        external
        returns (
            IVeloDeployFactory.PoolAddresses memory poolAddresses,
            uint256 tokenId
        )
    {
        _requireDepositior();

        if (!poolFactory.isPool(address(creationParameters.pool)))
            revert ForbiddenPool();

        (uint160 sqrtPriceX96, , , , , ) = creationParameters.pool.slot0();
        if (
            creationParameters.strategyType !=
            IPulseStrategyModule.StrategyType.Tamper
        ) {
            (
                uint256 amount0,
                uint256 amount1,
                int24 tickLower,
                int24 tickUpper
            ) = _getPositionParamPulse(creationParameters);

            uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );

            tokenId = mint(
                creationParameters.pool,
                tickLower,
                tickUpper,
                liquidity
            );
        }
    }

    function _getPositionParamPulse(
        PoolStrategyParameter calldata poolParameter
    )
        private
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            int24 tickLower,
            int24 tickUpper
        )
    {
        (uint160 sqrtPriceX96, int24 tick, , , , ) = poolParameter.pool.slot0();

        IPulseStrategyModule.StrategyParams
            memory strategyParams = IPulseStrategyModule.StrategyParams({
                tickNeighborhood: TICK_NEIGHBORHOOD,
                tickSpacing: poolParameter.pool.tickSpacing(),
                strategyType: poolParameter.strategyType,
                width: poolParameter.width,
                maxLiquidityRatioDeviationX96: 0
            });

        IVeloDeployFactory.ImmutableParams memory params = deployFactory
            .getImmutableParams();
        IPulseStrategyModule strategyModule = IPulseStrategyModule(
            params.strategyModule
        );
        (, ICore.TargetPositionInfo memory target) = strategyModule
            .calculateTargetPulse(sqrtPriceX96, tick, 0, 0, strategyParams);

        (tickLower, tickUpper) = (target.lowerTicks[0], target.upperTicks[0]);
        (amount0, amount1) = _getAmounts(
            poolParameter.maxAmount0,
            poolParameter.maxAmount1,
            sqrtPriceX96,
            tickLower,
            tickUpper
        );
    }

    function _getAmounts(
        uint256 maxAmount0,
        uint256 maxAmount1,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) private pure returns (uint256 amount0, uint256 amount1) {
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        uint128 actualLiqudity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            maxAmount0,
            maxAmount1
        );

        //require(actualLiqudity > MIN_INITIAL_LIQUDITY, "too low liqudity");

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            actualLiqudity
        );

        //require(amount0 < maxAmount0, "too high liqudity for amount0");
        //require(amount1 < maxAmount1, "too high liqudity for amount1");
        //require(amount0 > MIN_AMOUNT_WEI, "too low liqudity for amount0");
        //require(amount1 > MIN_AMOUNT_WEI, "too low liqudity for amount1");
    }

    function collect(address token) external {
        _requireDepositior();

        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(depositor, balance);
        }
    }
}
