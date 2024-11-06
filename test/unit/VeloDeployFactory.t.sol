// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    ICLPool public pool =
        ICLPool(factory.getPool(Constants.OPTIMISM_OP, Constants.OPTIMISM_WETH, 200));

    IERC20 token0 = IERC20(pool.token0());
    IERC20 token1 = IERC20(pool.token1());
    int24 tickSpacing = pool.tickSpacing();

    function testCreateStrategy() public returns (ILpWrapper lpWrapper) {
        DeployScript.CoreDeployment memory contracts = deployContracts();
        IVeloDeployFactory.DeployParams memory deployParams;
        (lpWrapper, deployParams) = deployLpWrapper(pool, contracts);
        assertFalse(address(lpWrapper) == address(0));
        assertEq(contracts.core.positionCount(), 1);

        ICore.ManagedPositionInfo memory postition = contracts.core.managedPositionAt(0);
        assertEq(postition.slippageD9, deployParams.slippageD9);
        assertEq(postition.property, uint24(tickSpacing));
        assertEq(postition.owner, address(lpWrapper));
        assertEq(postition.pool, address(pool));

        IAmmModule.AmmPosition memory ammPosition =
            contracts.core.ammModule().getAmmPosition(postition.ammPositionIds[0]);
        assertEq(ammPosition.token0, address(token0));
        assertEq(ammPosition.token1, address(token1));
        assertEq(ammPosition.property, uint24(tickSpacing));
        assertEq(ammPosition.tickUpper - ammPosition.tickLower, deployParams.strategyParams.width);
        assertTrue(ammPosition.liquidity > 0);

        IPulseStrategyModule.StrategyParams memory strategyParams =
            abi.decode(postition.strategyParams, (IPulseStrategyModule.StrategyParams));
        assertEq(
            uint256(strategyParams.strategyType), uint256(deployParams.strategyParams.strategyType)
        );
        assertEq(strategyParams.tickNeighborhood, deployParams.strategyParams.tickNeighborhood);
        assertEq(strategyParams.tickSpacing, tickSpacing);
        assertEq(strategyParams.width, deployParams.strategyParams.width);
        assertEq(
            strategyParams.maxLiquidityRatioDeviationX96,
            deployParams.strategyParams.maxLiquidityRatioDeviationX96
        );

        IVeloAmmModule.CallbackParams memory callbackParams =
            abi.decode(postition.callbackParams, (IVeloAmmModule.CallbackParams));
        assertEq(callbackParams.gauge, address(pool.gauge()));

        IVeloOracle.SecurityParams memory securityParams =
            abi.decode(postition.securityParams, (IVeloOracle.SecurityParams));
        assertEq(securityParams.lookback, deployParams.securityParams.lookback);
        assertEq(securityParams.maxAllowedDelta, deployParams.securityParams.maxAllowedDelta);
        assertEq(securityParams.maxAge, deployParams.securityParams.maxAge);
    }
}
