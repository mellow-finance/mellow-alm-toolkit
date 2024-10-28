// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    uint16 constant LOOKBACK = 1;
    int24 constant MAX_ALLOWED_DELTA = 100;
    uint32 constant MAX_AGE = 1 hours;
    uint128 INITIAL_LIQUIDITY = 1 ether;

    ICLPool public pool = ICLPool(factory.getPool(Constants.OP, Constants.WETH, 200));

    LpWrapper lpWrapper;
    StakingRewards stakingRewards;

    IERC20 token0 = IERC20(pool.token0());
    IERC20 token1 = IERC20(pool.token1());
    int24 tickSpacing = pool.tickSpacing();

    IVeloDeployFactory.DeployParams deployParams = IVeloDeployFactory.DeployParams({
        pool: pool,
        strategyType: IPulseStrategyModule.StrategyType.Original,
        width: tickSpacing * 10,
        maxAmount0: 1 ether,
        maxAmount1: 1 ether,
        tickNeighborhood: 0,
        slippageD9: 1e8,
        maxLiquidityRatioDeviationX96: 0,
        totalSupplyLimit: UINT256_MAX,
        securityParams: abi.encode(
            IVeloOracle.SecurityParams({
                lookback: LOOKBACK,
                maxAllowedDelta: MAX_ALLOWED_DELTA,
                maxAge: MAX_AGE
            })
        ),
        tokenId: new uint256[](0)
    });

    function testCreateStrategy()
        public
        returns (IVeloDeployFactory.PoolAddresses memory addresses)
    {
        vm.startPrank(Constants.OWNER);

        deal(address(token0), Constants.OWNER, 1000 ether);
        deal(address(token1), Constants.OWNER, 1000 ether);

        token0.approve(address(factoryDeposit), type(uint256).max);
        token1.approve(address(factoryDeposit), type(uint256).max);

        veloFactory.createStrategy(deployParams);

        addresses = veloFactory.poolToAddresses(address(pool));
        lpWrapper = LpWrapper(payable(addresses.lpWrapper));
        stakingRewards = StakingRewards(addresses.synthetixFarm);

        assertFalse(address(lpWrapper) == address(0));
        assertFalse(address(stakingRewards) == address(0));

        assertEq(core.positionCount(), 1);

        ICore.ManagedPositionInfo memory postition = core.managedPositionAt(0);
        assertEq(postition.slippageD9, deployParams.slippageD9);
        assertEq(postition.property, uint24(pool.tickSpacing()));
        assertEq(postition.owner, address(lpWrapper));
        assertEq(postition.pool, address(pool));

        IAmmModule.AmmPosition memory ammPosition =
            core.ammModule().getAmmPosition(postition.ammPositionIds[0]);
        assertEq(ammPosition.token0, address(token0));
        assertEq(ammPosition.token1, address(token1));
        assertEq(ammPosition.property, uint24(pool.tickSpacing()));
        assertEq(ammPosition.tickUpper - ammPosition.tickLower, deployParams.width);
        assertTrue(ammPosition.liquidity > 0);

        IPulseStrategyModule.StrategyParams memory strategyParams =
            abi.decode(postition.strategyParams, (IPulseStrategyModule.StrategyParams));
        assertEq(uint256(strategyParams.strategyType), uint256(deployParams.strategyType));
        assertEq(strategyParams.tickNeighborhood, deployParams.tickNeighborhood);
        assertEq(strategyParams.tickSpacing, pool.tickSpacing());
        assertEq(strategyParams.width, deployParams.width);
        assertEq(
            strategyParams.maxLiquidityRatioDeviationX96, deployParams.maxLiquidityRatioDeviationX96
        );

        IVeloAmmModule.CallbackParams memory callbackParams =
            abi.decode(postition.callbackParams, (IVeloAmmModule.CallbackParams));
        assertEq(callbackParams.farm, address(stakingRewards));
        assertEq(callbackParams.gauge, address(pool.gauge()));

        IVeloOracle.SecurityParams memory securityParams =
            abi.decode(postition.securityParams, (IVeloOracle.SecurityParams));
        assertEq(securityParams.lookback, LOOKBACK);
        assertEq(securityParams.maxAllowedDelta, MAX_ALLOWED_DELTA);
        assertEq(securityParams.maxAge, MAX_AGE);

        vm.stopPrank();
    }
}
