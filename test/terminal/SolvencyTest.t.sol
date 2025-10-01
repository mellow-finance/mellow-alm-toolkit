// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./SolvencyRunner.sol";

contract SolvencyTest is SolvencyRunner {
    using SafeERC20 for IERC20;
    using RandomLib for RandomLib.Storage;

    function _setup(bool isPulse) internal {
        CoreDeploymentParams memory coreParams = Constants.getDeploymentParams();
        vm.startPrank(coreParams.deployer);
        CoreDeployment memory contracts = deployCore(coreParams);
        vm.stopPrank();

        int24 tickSpacing = poolAB.tickSpacing();

        IVeloDeployFactory.DeployParams memory params;
        params.slippageD9 = 1e9 / 100 / 100; // 0.01%
        if (isPulse) {
            params.strategyParams = IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                tickNeighborhood: 0, // Neighborhood of ticks to consider for rebalancing
                tickSpacing: tickSpacing, // tickSpacing of the corresponding amm poolAB
                width: tickSpacing * 3, // Width of the interval
                maxLiquidityRatioDeviationX96: 0 // The maximum allowed deviation of the liquidity ratio for lower position.
            });
        } else {
            params.strategyParams = IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.Tamper,
                tickNeighborhood: 0, // Neighborhood of ticks to consider for rebalancing
                tickSpacing: tickSpacing, // tickSpacing of the corresponding amm poolAB
                width: tickSpacing * 8, // Width of the interval
                maxLiquidityRatioDeviationX96: uint256(2) ** 96 / 100 // The maximum allowed deviation of the liquidity ratio for lower position.
            });
        }
        params.securityParams = IVeloOracle.SecurityParams({
            lookback: 1,
            maxAge: 1 days,
            maxAllowedDelta: 100,
            extraData: ""
        });

        params.pool = address(poolAB);

        params.maxAmount0 = 1000 gwei;
        params.maxAmount1 = 1000 gwei;
        params.initialTotalSupply = 1000 gwei;
        params.totalSupplyLimit = 1e6 ether;

        vm.prank(coreParams.factoryProposer);
        bytes32 proposalId = contracts.deployFactory.proposeDeployParams(params);

        __initPoolTokens();

        vm.startPrank(coreParams.factoryManager);
        deal(address(token0), address(contracts.deployFactory), 1000 gwei);
        deal(address(token1), address(contracts.deployFactory), 1000 gwei);
        contracts.deployFactory.acceptDeployParams(proposalId);
        vm.stopPrank();

        ILpWrapper wrapper = contracts.deployFactory.deployStrategy(proposalId);

        __SolvencyRunner_init(contracts.core, wrapper);
    }

    function testSolvencyPulse() external {
        _setup(true);
        rnd.seed = 4076137254;
        _runSolvency(211, 125);
    }

    function testSolvencyTamper() external {
        _setup(false);
        _runSolvency(200, type(uint256).max);
    }

    function testSolvencyPulseDepositsOnly() external {
        _setup(true);
        _runSolvency(200, type(uint256).max ^ 2); // second bit is for withdrawals
    }

    function testFuzz_testSolvencyFullMask(uint256 seed_) external {
        if (true) {
            console2.log("Fuzz test is disabled by default");
            return;
        }
        rnd.seed = seed_;
        _setup(rnd.randBool());
        _runSolvency(10, type(uint256).max);
    }

    function testFuzz_FullSolvency(uint256 seed_, uint8 length, uint8 mask) external {
        if (true) {
            console2.log("Fuzz test is disabled by default");
            return;
        }
        rnd.seed = seed_;
        _setup(rnd.randBool());
        _runSolvency(uint256(length), uint256(mask));
    }
}
