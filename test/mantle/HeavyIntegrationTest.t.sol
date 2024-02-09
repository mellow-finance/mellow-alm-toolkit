// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Integration is Fixture {
    using SafeERC20 for IERC20;

    struct DepositParams {
        int24 width;
        int24 tickNeighborhood;
        int24 tickSpacing;
        uint16 slippageD4;
    }

    function makeDeposit(DepositParams memory params) public returns (uint256) {
        ICore.DepositParams memory depositParams;
        depositParams.tokenIds = new uint256[](1);
        depositParams.tokenIds[0] = mint(
            Constants.USDC,
            Constants.WETH,
            FEE,
            params.width,
            1e9
        );
        depositParams.owner = Constants.OWNER;
        depositParams.farm = address(0);
        depositParams.strategyParams = abi.encode(
            PulseStrategyModule.StrategyParams({
                tickNeighborhood: params.tickNeighborhood,
                tickSpacing: params.tickSpacing
            })
        );
        depositParams.securityParams = new bytes(0);
        depositParams.slippageD4 = params.slippageD4;
        depositParams.owner = address(lpWrapper);
        depositParams.vault = address(stakingRewards);

        vm.startPrank(Constants.OWNER);
        positionManager.approve(address(core), depositParams.tokenIds[0]);
        uint256 nftId = core.deposit(depositParams);
        lpWrapper.initialize(nftId, 5e5);
        vm.stopPrank();
        return nftId;
    }

    function testHeavy() external {
        int24 tickSpacing = pool.tickSpacing();
        makeDeposit(
            DepositParams({
                tickSpacing: tickSpacing,
                width: tickSpacing * 10,
                tickNeighborhood: tickSpacing,
                slippageD4: 100
            })
        );

        vm.startPrank(Constants.DEPOSITOR);
        uint256 usdcAmount = 1e6 * 1e6;
        uint256 wethAmount = 500 ether;
        deal(Constants.USDC, Constants.DEPOSITOR, usdcAmount);
        deal(Constants.WETH, Constants.DEPOSITOR, wethAmount);
        IERC20(Constants.USDC).safeApprove(
            address(lpWrapper),
            type(uint256).max
        );
        IERC20(Constants.WETH).safeApprove(
            address(lpWrapper),
            type(uint256).max
        );
        {
            (, , uint256 lpAmount) = lpWrapper.deposit(
                usdcAmount / 1e6,
                wethAmount / 1e6,
                1e8,
                Constants.DEPOSITOR
            );
            require(lpAmount > 1e8, "Invalid lp amount");
            console2.log("Actual lp amount:", lpAmount);
            lpWrapper.approve(address(stakingRewards), type(uint256).max);
            stakingRewards.stake(
                lpWrapper.balanceOf(Constants.DEPOSITOR),
                Constants.DEPOSITOR
            );
        }
        vm.stopPrank();

        for (uint256 i = 0; i < 5; i++) {
            vm.startPrank(Constants.DEPOSITOR);
            stakingRewards.withdraw(
                stakingRewards.balanceOf(Constants.DEPOSITOR) / 2
            );
            uint256 lpAmount = lpWrapper.balanceOf(Constants.DEPOSITOR);
            (
                uint256 amount0,
                uint256 amount1,
                uint256 actualAmountLp
            ) = lpWrapper.withdraw(lpAmount, 0, 0, Constants.DEPOSITOR);

            console2.log(
                "Actual withdrawal amounts for depositor:",
                amount0,
                amount1,
                actualAmountLp
            );
            vm.stopPrank();
        }

        uint256 balance0 = IERC20(Constants.USDC).balanceOf(
            Constants.DEPOSITOR
        );
        uint256 balance1 = IERC20(Constants.WETH).balanceOf(
            Constants.DEPOSITOR
        );

        for (uint256 i = 1; i <= 5; i++) {
            vm.startPrank(Constants.DEPOSITOR);
            uint256 amount0 = balance0 / 2 ** i;
            uint256 amount1 = balance1 / 2 ** i;

            (
                uint256 actualAmount0,
                uint256 actualAmount1,
                uint256 lpAmount
            ) = lpWrapper.deposit(amount0, amount1, 0, Constants.DEPOSITOR);

            console2.log(
                "Actual deposit amounts for depositor:",
                actualAmount0,
                actualAmount1,
                lpAmount
            );
            vm.stopPrank();
        }
    }
}
