// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../../scripts/deploy/Constants.sol";

contract IntegrationTest is Test, DeployScript {
    using SafeERC20 for IERC20;

    CoreDeploymentParams private coreParams;
    CoreDeployment private contracts;
    ILpWrapper private wstethWeth1Wrapper;

    uint256 private constant Q96 = 2 ** 96;

    function setUp() external {
        coreParams = Constants.getDeploymentParams();
        coreParams.lpWrapperManager = address(0);
        vm.startPrank(coreParams.deployer);
        contracts = deployCore(coreParams);

        IVeloDeployFactory.DeployParams memory params;
        params.slippageD9 = 1e9 / 100 / 100;
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
        params.maxAmount0 = 1000 wei;
        params.maxAmount1 = 1000 wei;
        params.initialTotalSupply = 1000 wei;
        params.totalSupplyLimit = 1000 ether;

        vm.stopPrank();
        vm.startPrank(coreParams.factoryOperator);
        deal(Constants.OPTIMISM_WETH, address(contracts.deployFactory), 1 ether);
        deal(Constants.OPTIMISM_WSTETH, address(contracts.deployFactory), 1 ether);
        wstethWeth1Wrapper = deployStrategy(contracts, params);
        vm.stopPrank();
    }

    function logPositions() internal view {
        ICore.ManagedPositionInfo memory info =
            contracts.core.managedPositionAt(wstethWeth1Wrapper.positionId());

        (uint160 sqrtPriceX96,,,,,) = ICLPool(info.pool).slot0();
        uint256 totalAmount0 = 0;
        uint256 totalAmount1 = 0;
        for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
            uint256 tokenId = info.ammPositionIds[i];
            PositionLibrary.Position memory position =
                PositionLibrary.getPosition(coreParams.positionManager, tokenId);
            (uint256 amount0, uint256 amount1) =
                contracts.ammModule.tvl(tokenId, sqrtPriceX96, info.callbackParams, new bytes(0));

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

        uint256 wethAmount = 1 ether;
        uint256 wstethAmount = 1.5 ether;

        deal(Constants.OPTIMISM_WETH, user, wethAmount);
        deal(Constants.OPTIMISM_WSTETH, user, wstethAmount);

        IERC20(Constants.OPTIMISM_WETH).safeIncreaseAllowance(
            address(wstethWeth1Wrapper), wethAmount
        );
        IERC20(Constants.OPTIMISM_WSTETH).safeIncreaseAllowance(
            address(wstethWeth1Wrapper), wstethAmount
        );

        uint256 n = 20;
        for (uint256 i = 0; i < n; i++) {
            wstethWeth1Wrapper.deposit(wstethAmount / n, wethAmount / n, 0, user, block.timestamp);
            skip(1 hours);
        }

        IERC20(address(wstethWeth1Wrapper)).safeTransfer(user, 0);
        wstethWeth1Wrapper.getRewards(user);
        wstethWeth1Wrapper.withdraw(
            wstethWeth1Wrapper.balanceOf(user) / 2, 0, 0, user, block.timestamp
        );
        vm.stopPrank();

        vm.startPrank(coreParams.lpWrapperAdmin);

        wstethWeth1Wrapper.setStrategyParams(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.Tamper,
                tickNeighborhood: 0, // Neighborhood of ticks to consider for rebalancing
                tickSpacing: 1,
                width: 50, // Width of the interval
                maxLiquidityRatioDeviationX96: uint128(2 ** 96) / 100 // The maximum allowed deviation of the liquidity ratio for lower position.
            })
        );

        vm.stopPrank();
        RebalancingBot bot =
            new RebalancingBot(INonfungiblePositionManager(coreParams.positionManager));

        deal(Constants.OPTIMISM_WSTETH, address(bot), 1 ether);
        deal(Constants.OPTIMISM_WETH, address(bot), 1 ether);

        vm.startPrank(coreParams.coreOperator);
        logPositions();
        contracts.core.rebalance(
            ICore.RebalanceParams({
                id: wstethWeth1Wrapper.positionId(),
                callback: address(bot),
                data: new bytes(0)
            })
        );
        logPositions();
        vm.stopPrank();

        vm.startPrank(coreParams.lpWrapperAdmin);
        wstethWeth1Wrapper.setStrategyParams(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                tickNeighborhood: 0,
                tickSpacing: 1,
                width: 20,
                maxLiquidityRatioDeviationX96: 0
            })
        );
        vm.stopPrank();

        vm.startPrank(coreParams.coreOperator);
        logPositions();
        contracts.core.rebalance(
            ICore.RebalanceParams({
                id: wstethWeth1Wrapper.positionId(),
                callback: address(bot),
                data: new bytes(0)
            })
        );
        logPositions();
        vm.stopPrank();
    }
}
