// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../scripts/deploy/Constants.sol";
import "../src/interfaces/external/velo/ISwapRouter.sol";

interface ICLVoter {
    function distribute(address[] memory _gauges) external;
}

contract IntegrationTest is Test {
    using SafeERC20 for IERC20;

    INonfungiblePositionManager public immutable positionManager =
        INonfungiblePositionManager(Constants.OPTIMISM_POSITION_MANAGER);
    ICLFactory public factory = ICLFactory(positionManager.factory());
    ISwapRouter public router = ISwapRouter(Constants.OPTIMISM_SWAP_ROUTER);

    function distributeRewards(ICLGauge gauge, bool isRevertExpected) internal {
        address voter = address(gauge.voter());
        if (isRevertExpected) {
            vm.expectRevert();
        }
        address[] memory gauges = new address[](1);
        gauges[0] = address(gauge);
        ICLVoter(voter).distribute(gauges);
    }

    function doSwap(ICLPool pool) internal {
        address swapper = vm.createWallet("swapper").addr;
        vm.startPrank(swapper);
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: pool.token0(),
            tokenOut: pool.token1(),
            tickSpacing: 1,
            recipient: swapper,
            deadline: type(uint256).max,
            amountOut: IERC20(pool.token1()).balanceOf(address(pool)) / 2,
            amountInMaximum: type(uint128).max,
            sqrtPriceLimitX96: 0
        });
        deal(pool.token0(), swapper, type(uint128).max);
        IERC20(pool.token0()).safeIncreaseAllowance(address(router), type(uint128).max);
        router.exactOutputSingle(params);
        vm.stopPrank();
    }

    function testVelo() external {
        ICLPool pool =
            ICLPool(factory.getPool(Constants.OPTIMISM_WSTETH, Constants.OPTIMISM_WETH, 1));
        ICLGauge gauge = ICLGauge(pool.gauge());

        skip(1 weeks);
        // ok
        distributeRewards(gauge, false);
        console2.log(gauge.fees0(), gauge.fees1());

        skip(1 weeks);
        distributeRewards(gauge, false);
        // must be zeros
        console2.log(gauge.fees0(), gauge.fees1());

        // generate fees
        doSwap(pool);

        // reverts
        skip(1 weeks);
        distributeRewards(gauge, true);
    }
}
