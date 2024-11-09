// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./SolvencyRunner.sol";

contract IntegrationTest is SolvencyRunner {
    using SafeERC20 for IERC20;
    using RandomLib for RandomLib.Storage;

    function setUp() external {
        CoreDeploymentParams memory coreParams = Constants.getDeploymentParams();
        vm.startPrank(coreParams.deployer);
        CoreDeployment memory contracts = deployCore(coreParams);
        vm.stopPrank();

        IVeloDeployFactory.DeployParams memory params;
        params.slippageD9 = 1e9 / 100 / 100; // 0.01%
        params.strategyParams = IPulseStrategyModule.StrategyParams({
            strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
            tickNeighborhood: 0, // Neighborhood of ticks to consider for rebalancing
            tickSpacing: 1, // tickSpacing of the corresponding amm pool
            width: 50, // Width of the interval
            maxLiquidityRatioDeviationX96: 0 // The maximum allowed deviation of the liquidity ratio for lower position.
        });

        params.securityParams =
            IVeloOracle.SecurityParams({lookback: 100, maxAge: 5 days, maxAllowedDelta: 10});

        INonfungiblePositionManager positionManager =
            INonfungiblePositionManager(coreParams.positionManager);
        params.pool = ICLPool(
            ICLFactory(positionManager.factory()).getPool(
                Constants.OPTIMISM_WETH, Constants.OPTIMISM_WSTETH, 1
            )
        );
        params.maxAmount0 = 1000 gwei;
        params.maxAmount1 = 1000 gwei;
        params.initialTotalSupply = 1000 gwei;
        params.totalSupplyLimit = 1e6 ether;

        vm.startPrank(coreParams.factoryOperator);
        deal(Constants.OPTIMISM_WETH, address(contracts.deployFactory), 1000 gwei);
        deal(Constants.OPTIMISM_WSTETH, address(contracts.deployFactory), 1000 gwei);
        ILpWrapper wrapper = deployStrategy(contracts, params);
        vm.stopPrank();

        __SolvencyRunner_init(contracts.core, wrapper);
    }

    function testSolvency() external {
        _runSolvency(100, 0xffffff);
    }
}
