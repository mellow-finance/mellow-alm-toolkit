// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../scripts/deploy/Constants.sol";
import "../scripts/deploy/DeployScript.sol";

contract IntegrationTest is Test, DeployScript {
    using SafeERC20 for IERC20;

    CoreDeploymentParams private coreParams;
    CoreDeployment private contracts;
    ILpWrapper private wstethWeth1Wrapper;

    function setUp() external {
        coreParams = Constants.getDeploymentParams();
        vm.startPrank(coreParams.deployer);
        contracts = deployCore(coreParams);

        IVeloDeployFactory.DeployParams memory params;
        params.slippageD9 = 1e6;
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

    function testDeploy() external {
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

        uint256 n = 10;
        for (uint256 i = 0; i < n; i++) {
            wstethWeth1Wrapper.deposit(wstethAmount / n, wethAmount / n, 0, user, block.timestamp);
            skip(1 hours);
        }

        IERC20(address(wstethWeth1Wrapper)).safeTransfer(user, 0);

        IERC20 rewardToken = IERC20(wstethWeth1Wrapper.rewardToken());
        uint256 wrapperBalanceBefore = rewardToken.balanceOf(address(wstethWeth1Wrapper));
        uint256 userBalanceBefore = rewardToken.balanceOf(user);
        uint256 earned = wstethWeth1Wrapper.earned(user);

        wstethWeth1Wrapper.getRewards(user);

        uint256 wrapperBalanceAfter = rewardToken.balanceOf(address(wstethWeth1Wrapper));
        uint256 userBalanceAfter = rewardToken.balanceOf(user);

        console2.log("user: actual/expected:", userBalanceAfter - userBalanceBefore, earned);
        console2.log("lp wrapper delta:", wrapperBalanceBefore - wrapperBalanceAfter);
        console2.log(wstethWeth1Wrapper.earned(user));

        wstethWeth1Wrapper.withdraw(wstethWeth1Wrapper.balanceOf(user), 0, 0, user, block.timestamp);

        vm.stopPrank();
    }

    // function testPositionsNormal() external {
    //     uint256 tokenId =
    //         contracts.core.managedPositionAt(wstethWeth1Wrapper.positionId()).ammPositionIds[0];

    //     uint256 g_ = gasleft();
    //     // THIS positionManager.positions(...) CALL BREAKS THE COVERAGE TEST
    //     INonfungiblePositionManager(coreParams.positionManager).positions(tokenId);
    //     console2.log("Normal call usage:", g_ - gasleft());
    // }

    function testPositionsModified() external {
        uint256 tokenId =
            contracts.core.managedPositionAt(wstethWeth1Wrapper.positionId()).ammPositionIds[0];

        uint256 g_ = gasleft();
        PositionLibrary.getPosition(address(coreParams.positionManager), tokenId);
        console2.log("Modified call usage:", g_ - gasleft());
    }
}
