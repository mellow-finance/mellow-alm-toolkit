// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./Fixture.sol";

contract RebalanceTest is Fixture {
    using SafeERC20 for IERC20;

    CoreDeploymentParams private coreParams;
    CoreDeployment private contracts;
    ILpWrapper private lpWrapper;

    function setUp() external {
        coreParams = Constants.getDeploymentParams();
        coreParams.lpWrapperManager = address(123456);
        vm.startPrank(coreParams.deployer);
        contracts = deployCore(coreParams);

        int24 tickSpacing = poolAB.tickSpacing();

        IVeloDeployFactory.DeployParams memory params;
        params.slippageD9 = 1e9 / 100 / 100;
        params.strategyParams = IPulseStrategyModule.StrategyParams({
            strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
            tickNeighborhood: 0, // Neighborhood of ticks to consider for rebalancing
            tickSpacing: tickSpacing, // tickSpacing of the corresponding amm poolAB
            width: tickSpacing * 3, // Width of the interval
            maxLiquidityRatioDeviationX96: 0 // The maximum allowed deviation of the liquidity ratio for lower position.
        });

        params.securityParams = IVeloOracle.SecurityParams({
            lookback: 1,
            maxAge: 1 days,
            maxAllowedDelta: 100,
            extraData: ""
        });

        params.pool = address(poolAB);
        increaseObservationCardinality(poolAB, 100);

        params.maxAmount0 = 1000 wei;
        params.maxAmount1 = 1000 wei;
        params.initialTotalSupply = 1000 wei;
        params.totalSupplyLimit = 1000 ether;

        vm.stopPrank();

        vm.prank(coreParams.factoryProposer);
        bytes32 proposalId = contracts.deployFactory.proposeDeployParams(params);

        vm.startPrank(coreParams.factoryManager);
        deal(tokenA, address(contracts.deployFactory), 1 ether);
        deal(tokenB, address(contracts.deployFactory), 1 ether);
        contracts.deployFactory.acceptDeployParams(proposalId);
        vm.stopPrank();

        lpWrapper = contracts.deployFactory.deployStrategy(proposalId);
    }

    function logPositions() internal view {
        ICore.ManagedPositionInfo memory info =
            contracts.core.managedPositionAt(lpWrapper.positionId());

        (uint160 sqrtPriceX96,,,,,,,) = ITerminalPool(info.pool).slot0();
        uint256 totalAmount0 = 0;
        uint256 totalAmount1 = 0;
        for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
            uint256 tokenId = info.ammPositionIds[i];
            IVeloAmmModule.Position memory position = contracts.ammModule.getPosition(tokenId);
            (uint256 amount0, uint256 amount1) = contracts.ammModule.tvl(
                tokenId /* , sqrtPriceX96, info.callbackParams, new bytes(0) */
            );

            string memory positionStr = string(
                abi.encodePacked(
                    vm.toString(position.tickLower),
                    ":",
                    vm.toString(position.tickUpper),
                    " liquidity: ",
                    vm.toString(position.liquidity),
                    " amount0: ",
                    vm.toString(uint256(amount0)),
                    " amount1: ",
                    vm.toString(uint256(amount1))
                )
            );
            console2.log(positionStr);
            totalAmount0 += amount0;
            totalAmount1 += amount1;
        }
        uint256 priceX96 = Math.mulDiv(sqrtPriceX96, sqrtPriceX96, Q96);
        (bool isRebalanceRequired,) =
            contracts.strategyModule.getTargets(info, contracts.ammModule, contracts.oracle);
        console2.log("Is rebalance required ?", vm.toString(isRebalanceRequired));
        console2.log(
            "total value in token1: ",
            vm.toString(Math.mulDiv(totalAmount0, priceX96, Q96) + totalAmount1)
        );
        console2.log("--------");
    }

    function testRebalancePulseTamperPulse() external {
        address user = vm.createWallet("random-user").addr;

        vm.startPrank(user);

        uint256 amount0 = 1 ether;
        uint256 amount1 = 1.5 ether;

        deal(tokenA, user, amount0);
        deal(tokenB, user, amount1);

        IERC20(tokenA).safeIncreaseAllowance(address(lpWrapper), amount0);
        IERC20(tokenB).safeIncreaseAllowance(address(lpWrapper), amount1);

        uint256 n = 20;
        for (uint256 i = 0; i < n; i++) {
            lpWrapper.mint(
                ILpWrapper.MintParams({
                    lpAmount: Math.min(amount1, amount0) / n * 99 / 100,
                    amount0Max: amount1 / n,
                    amount1Max: amount0 / n,
                    recipient: user,
                    deadline: block.timestamp
                })
            );
            skip(1 hours);
        }

        IERC20(address(lpWrapper)).safeTransfer(user, 0);
        lpWrapper.getRewards(user);
        lpWrapper.withdraw(lpWrapper.balanceOf(user) / 2, 0, 0, user, block.timestamp);
        vm.stopPrank();

        int24 tickSpacing = poolAB.tickSpacing();
        vm.startPrank(coreParams.lpWrapperManager);

        lpWrapper.setStrategyParams(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.Tamper,
                tickNeighborhood: 0, // Neighborhood of ticks to consider for rebalancing
                tickSpacing: tickSpacing,
                width: tickSpacing * 8,
                maxLiquidityRatioDeviationX96: uint128(2 ** 96) / 100 // The maximum allowed deviation of the liquidity ratio for lower position.
            })
        );

        vm.stopPrank();
        RebalancingBot bot =
            new RebalancingBot(INonfungiblePositionManager(coreParams.positionManager));

        deal(tokenB, address(bot), 1 ether);
        deal(tokenA, address(bot), 1 ether);

        vm.startPrank(coreParams.coreOperator);
        logPositions();
        contracts.core.rebalance(
            ICore.RebalanceParams({
                id: lpWrapper.positionId(),
                callback: address(bot),
                data: new bytes(0)
            })
        );
        logPositions();
        vm.stopPrank();

        vm.startPrank(coreParams.lpWrapperManager);
        lpWrapper.setStrategyParams(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                tickNeighborhood: 0,
                tickSpacing: tickSpacing,
                width: tickSpacing * 11,
                maxLiquidityRatioDeviationX96: 0
            })
        );
        vm.stopPrank();

        vm.startPrank(coreParams.coreOperator);
        logPositions();
        contracts.core.rebalance(
            ICore.RebalanceParams({
                id: lpWrapper.positionId(),
                callback: address(bot),
                data: new bytes(0)
            })
        );
        logPositions();
        vm.stopPrank();
    }
}
