// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "./Fixture.sol";

contract IntegrationTest is DeployScriptTerm, Fixture {
    using SafeERC20 for IERC20;

    CoreDeploymentParams private coreParams;
    CoreDeployment private contracts;
    ILpWrapper private lpWrapper;

    address pool = 0xdA01f6A7CcfA9D23F5B7347C026BE895F28E379c;
    address tokenA = 0xD85c100f5A456781f7f5Bb3f468CeC0B768620A1;
    address tokenB = 0xEd24a13936A5C307F90e1543189c9514160c1509;

    function setUp() external {
        coreParams = Constants.getDeploymentParams();
        vm.startPrank(coreParams.deployer);
        contracts = deployCore(coreParams);

        IVeloDeployFactory.DeployParams memory params;
        params.slippageD9 = 1e6;
        params.strategyParams = IPulseStrategyModule.StrategyParams({
            strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
            tickNeighborhood: 0, // Neighborhood of ticks to consider for rebalancing
            tickSpacing: 200, // tickSpacing of the corresponding amm pool
            width: 400, // Width of the interval
            maxLiquidityRatioDeviationX96: 0 // The maximum allowed deviation of the liquidity ratio for lower position.
        });

        params.securityParams = IVeloOracle.SecurityParams({
            lookback: 1,
            maxAge: 1 seconds,
            maxAllowedDelta: 10,
            extraData: ""
        });

        INonfungiblePositionManager positionManager =
            INonfungiblePositionManager(coreParams.positionManager);
        params.pool = ITerminalPoolFactory(positionManager.factory()).getPool(tokenA, tokenB, 200);

        increaseObservationCardinality(ITerminalPool(params.pool), 2);
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

    function testDeploy() external {
        address user = vm.createWallet("random-user").addr;

        vm.startPrank(user);

        uint256 amountA = 1 ether;
        uint256 amountB = 1.5 ether;

        deal(tokenA, user, amountA);
        deal(tokenB, user, amountB);

        IERC20(tokenA).safeIncreaseAllowance(address(lpWrapper), amountA);
        IERC20(tokenB).safeIncreaseAllowance(address(lpWrapper), amountB);

        uint256 n = 20;
        for (uint256 i = 0; i < n; i++) {
            lpWrapper.mint(
                ILpWrapper.MintParams({
                    lpAmount: Math.min(amountB, amountA) / n * 99 / 100,
                    amount0Max: amountB / n,
                    amount1Max: amountA / n,
                    recipient: user,
                    deadline: block.timestamp
                })
            );
            skip(1 hours);
        }

        IERC20(address(lpWrapper)).safeTransfer(user, 0);

        IERC20 rewardToken = IERC20(lpWrapper.rewardToken());
        uint256 wrapperBalanceBefore = rewardToken.balanceOf(address(lpWrapper));
        uint256 userBalanceBefore = rewardToken.balanceOf(user);
        uint256 earned = lpWrapper.earned(user);

        lpWrapper.getRewards(user);

        uint256 wrapperBalanceAfter = rewardToken.balanceOf(address(lpWrapper));
        uint256 userBalanceAfter = rewardToken.balanceOf(user);

        console2.log("user: actual/expected:", userBalanceAfter - userBalanceBefore, earned);
        console2.log("lp wrapper delta:", wrapperBalanceBefore - wrapperBalanceAfter);
        console2.log(lpWrapper.earned(user));

        vm.stopPrank();
    }

    function testPositionsModified() external view {
        uint256 tokenId = contracts.core.managedPositionAt(lpWrapper.positionId()).ammPositionIds[0];

        uint256 g_ = gasleft();
        IVeloAmmModule.Position memory position = contracts.ammModule.getPosition(tokenId);

        console2.log("Modified call usage:", g_ - gasleft());

        console2.log(position.tokenId);
        console2.log(position.liquidity);
    }
}
