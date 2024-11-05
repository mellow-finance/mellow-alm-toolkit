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

        uint256 n = 20;
        for (uint256 i = 0; i < n; i++) {
            wstethWeth1Wrapper.deposit(wstethAmount / n, wethAmount / n, 0, user, block.timestamp);
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
        PositionLibrary.Position memory position =
            PositionLibrary.getPosition(address(coreParams.positionManager), tokenId);

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

    function logPosition(PositionLibrary.Position memory position) internal pure {
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
        Mock mock = new Mock();

        logPosition(PositionLibrary.getPosition(address(mock), 1));
        mock.setNonce(type(uint96).max);
        logPosition(PositionLibrary.getPosition(address(mock), 2));
        mock.setNonce(0);
        mock.setOperator(address(type(uint160).max));
        logPosition(PositionLibrary.getPosition(address(mock), 3));
        mock.setOperator(address(0));
        mock.setToken0(address(type(uint160).max));
        logPosition(PositionLibrary.getPosition(address(mock), 4));
        mock.setToken0(address(0));
        mock.setToken1(address(type(uint160).max));
        logPosition(PositionLibrary.getPosition(address(mock), 5));
        mock.setToken1(address(0));
        mock.setTickSpacing(type(int24).max);
        logPosition(PositionLibrary.getPosition(address(mock), 6));
        mock.setTickSpacing(0);
        mock.setTickLower(type(int24).max);
        logPosition(PositionLibrary.getPosition(address(mock), 7));
        mock.setTickLower(0);
        mock.setTickUpper(type(int24).max);
        logPosition(PositionLibrary.getPosition(address(mock), 8));
        mock.setTickUpper(0);
        mock.setLiquidity(type(uint128).max);
        logPosition(PositionLibrary.getPosition(address(mock), 9));
        mock.setLiquidity(0);
        mock.setFeeGrowthInside0LastX128(type(uint256).max);
        logPosition(PositionLibrary.getPosition(address(mock), 10));
        mock.setFeeGrowthInside0LastX128(0);
        mock.setFeeGrowthInside1LastX128(type(uint256).max);
        logPosition(PositionLibrary.getPosition(address(mock), 11));
        mock.setFeeGrowthInside1LastX128(0);
        mock.setTokensOwed0(type(uint128).max);
        logPosition(PositionLibrary.getPosition(address(mock), 12));
        mock.setTokensOwed0(0);
        mock.setTokensOwed1(type(uint128).max);
        logPosition(PositionLibrary.getPosition(address(mock), 13));
        mock.setTokensOwed1(0);
        mock.setTickLower(type(int24).min);
        logPosition(PositionLibrary.getPosition(address(mock), 14));
    }
}

contract Mock {
    uint96 nonce;
    address operator;
    address token0;
    address token1;
    int24 tickSpacing;
    int24 tickLower;
    int24 tickUpper;
    uint128 liquidity;
    uint256 feeGrowthInside0LastX128;
    uint256 feeGrowthInside1LastX128;
    uint128 tokensOwed0;
    uint128 tokensOwed1;

    function setNonce(uint96 _nonce) external {
        nonce = _nonce;
    }

    function setOperator(address _operator) external {
        operator = _operator;
    }

    function setToken0(address _token0) external {
        token0 = _token0;
    }

    function setToken1(address _token1) external {
        token1 = _token1;
    }

    function setTickSpacing(int24 _tickSpacing) external {
        tickSpacing = _tickSpacing;
    }

    function setTickLower(int24 _tickLower) external {
        tickLower = _tickLower;
    }

    function setTickUpper(int24 _tickUpper) external {
        tickUpper = _tickUpper;
    }

    function setLiquidity(uint128 _liquidity) external {
        liquidity = _liquidity;
    }

    function setFeeGrowthInside0LastX128(uint256 _feeGrowthInside0LastX128) external {
        feeGrowthInside0LastX128 = _feeGrowthInside0LastX128;
    }

    function setFeeGrowthInside1LastX128(uint256 _feeGrowthInside1LastX128) external {
        feeGrowthInside1LastX128 = _feeGrowthInside1LastX128;
    }

    function setTokensOwed0(uint128 _tokensOwed0) external {
        tokensOwed0 = _tokensOwed0;
    }

    function setTokensOwed1(uint128 _tokensOwed1) external {
        tokensOwed1 = _tokensOwed1;
    }

    function test() internal pure {}

    function positions(uint256 /* tokenId */ )
        external
        view
        returns (
            uint96,
            address,
            address,
            address,
            int24,
            int24,
            int24,
            uint128,
            uint256,
            uint256,
            uint128,
            uint128
        )
    {
        return (
            nonce,
            operator,
            token0,
            token1,
            tickSpacing,
            tickLower,
            tickUpper,
            liquidity,
            feeGrowthInside0LastX128,
            feeGrowthInside1LastX128,
            tokensOwed0,
            tokensOwed1
        );
    }
}
