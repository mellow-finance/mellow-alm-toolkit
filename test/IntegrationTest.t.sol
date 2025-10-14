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
            priceOracle: address(0), // The address of the custom price oracle used for market data
            maxLiquidityRatioDeviationX96: 0 // The maximum allowed deviation of the liquidity ratio for lower position.
        });

        params.securityParams = IVeloOracle.SecurityParams({
            lookback: 100,
            maxAge: 5 days,
            maxAllowedDelta: 10,
            extraData: ""
        });

        INonfungiblePositionManager positionManager =
            INonfungiblePositionManager(coreParams.positionManager);
        params.pool = ICLFactory(positionManager.factory()).getPool(
            Constants.OPTIMISM_WETH, Constants.OPTIMISM_WSTETH, 1
        );
        params.maxAmount0 = 1000 wei;
        params.maxAmount1 = 1000 wei;
        params.initialTotalSupply = 1000 wei;
        params.totalSupplyLimit = 1000 ether;
        vm.stopPrank();

        vm.prank(coreParams.factoryProposer);
        bytes32 proposalId = contracts.deployFactory.proposeDeployParams(params);

        vm.startPrank(coreParams.factoryManager);
        deal(Constants.OPTIMISM_WETH, address(contracts.deployFactory), 1 ether);
        deal(Constants.OPTIMISM_WSTETH, address(contracts.deployFactory), 1 ether);
        contracts.deployFactory.acceptDeployParams(proposalId);
        vm.stopPrank();

        wstethWeth1Wrapper = contracts.deployFactory.deployStrategy(proposalId);
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

        uint256 n = 20;
        for (uint256 i = 0; i < n; i++) {
            wstethWeth1Wrapper.mint(
                ILpWrapper.MintParams({
                    lpAmount: Math.min(wstethAmount, wethAmount) / n * 99 / 100,
                    amount0Max: wstethAmount / n,
                    amount1Max: wethAmount / n,
                    recipient: user,
                    deadline: block.timestamp
                })
            );
            skip(1 hours);
        }
        if (true) {
            return;
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

    function testPositionsModified() external view {
        uint256 tokenId =
            contracts.core.managedPositionAt(wstethWeth1Wrapper.positionId()).ammPositionIds[0];

        uint256 g_ = gasleft();
        IVeloAmmModule.Position memory position = contracts.ammModule.getPosition(tokenId);

        console2.log("Modified call usage:", g_ - gasleft());

        console2.log(position.tokenId);
        console2.log(position.liquidity);
    }

    // function testPositionsRegular() external view {
    //     uint256 tokenId =
    //         contracts.core.managedPositionAt(wstethWeth1Wrapper.positionId()).ammPositionIds[0];

    //     uint256 g_ = gasleft();
    //     INonfungiblePositionManager(coreParams.positionManager).positions(tokenId);
    //     console2.log("Regular call usage:", g_ - gasleft());
    // }

    function logPosition(IVeloAmmModule.Position memory position) internal pure {
        console2.log("tokenId:", vm.toString(position.tokenId));
        console2.log("nonce:", vm.toString(position.nonce));
        console2.log("operator:", vm.toString(position.operator));
        console2.log("token0:", vm.toString(position.token0));
        console2.log("token1:", vm.toString(position.token1));
        console2.log("tickSpacing:", vm.toString(position.tickSpacing));
        console2.log("tickLower:", vm.toString(position.tickLower));
        console2.log("tickUpper:", vm.toString(position.tickUpper));
        console2.log("liquidity:", vm.toString(position.liquidity));
        console2.log("feeGrowthInside0LastX128:", vm.toString(position.feeGrowthInside0LastX128));
        console2.log("feeGrowthInside1LastX128:", vm.toString(position.feeGrowthInside1LastX128));
        console2.log("tokensOwed0:", vm.toString(position.tokensOwed0));
        console2.log("tokensOwed1:", vm.toString(position.tokensOwed1));
        console2.log();
    }

    function testStepByStep() external {
        NonfungiblePositionManagerMock mock =
            new NonfungiblePositionManagerMock(coreParams.positionManager);

        IVeloAmmModule ammModule =
            new VeloAmmModule(INonfungiblePositionManager(address(mock)), 0xe5e31b13);

        logPosition(ammModule.getPosition(1));
        mock.setNonce(type(uint96).max);
        logPosition(ammModule.getPosition(2));
        mock.setNonce(0);
        mock.setOperator(address(type(uint160).max));
        logPosition(ammModule.getPosition(3));
        mock.setOperator(address(0));
        mock.setToken0(address(type(uint160).max));
        logPosition(ammModule.getPosition(4));
        mock.setToken0(address(0));
        mock.setToken1(address(type(uint160).max));
        logPosition(ammModule.getPosition(5));
        mock.setToken1(address(0));
        mock.setTickSpacing(type(int24).max);
        logPosition(ammModule.getPosition(6));
        mock.setTickSpacing(0);
        mock.setTickLower(type(int24).max);
        logPosition(ammModule.getPosition(7));
        mock.setTickLower(0);
        mock.setTickUpper(type(int24).max);
        logPosition(ammModule.getPosition(8));
        mock.setTickUpper(0);
        mock.setLiquidity(type(uint128).max);
        logPosition(ammModule.getPosition(9));
        mock.setLiquidity(0);
        mock.setFeeGrowthInside0LastX128(type(uint256).max);
        logPosition(ammModule.getPosition(10));
        mock.setFeeGrowthInside0LastX128(0);
        mock.setFeeGrowthInside1LastX128(type(uint256).max);
        logPosition(ammModule.getPosition(11));
        mock.setFeeGrowthInside1LastX128(0);
        mock.setTokensOwed0(type(uint128).max);
        logPosition(ammModule.getPosition(12));
        mock.setTokensOwed0(0);
        mock.setTokensOwed1(type(uint128).max);
        logPosition(ammModule.getPosition(13));
        mock.setTokensOwed1(0);
        mock.setTickLower(type(int24).min);
        logPosition(ammModule.getPosition(14));
    }
}
