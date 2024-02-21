// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Test {
    using SafeERC20 for IERC20;

    PulseStrategyModule public pulseStrategyModule = new PulseStrategyModule();

    function _testCalculateTargetOriginal() external {
        int24 k = 5;
        for (int24 tickLower = -k; tickLower <= k; tickLower++) {
            for (int24 width = 1; width <= k; width++) {
                int24 tickUpper = tickLower + width;
                for (
                    int24 spotTick = tickLower - width;
                    spotTick <= tickUpper + width;
                    spotTick++
                ) {
                    (
                        bool isRebalanceRequired,
                        ICore.TargetNftsInfo memory target
                    ) = pulseStrategyModule.calculateTarget(
                            spotTick,
                            tickLower,
                            tickUpper,
                            IPulseStrategyModule.StrategyParams({
                                strategyType: IPulseStrategyModule
                                    .StrategyType
                                    .Original,
                                tickSpacing: width >= 4 ? int24(4) : int24(1),
                                tickNeighborhood: width >= 4
                                    ? width - 3
                                    : int24(1)
                            })
                        );
                    string memory response = string(
                        abi.encodePacked(
                            "initial: {",
                            vm.toString(tickLower),
                            ", ",
                            vm.toString(tickUpper),
                            "} spot=",
                            vm.toString(spotTick),
                            " tickSpacing=",
                            vm.toString(width >= 4 ? int24(4) : int24(1))
                        )
                    );

                    if (isRebalanceRequired) {
                        response = string(
                            abi.encodePacked(
                                response,
                                "\ttarget: {",
                                vm.toString(target.lowerTicks[0]),
                                ", ",
                                vm.toString(target.upperTicks[0]),
                                "}"
                            )
                        );
                    } else {
                        response = string(
                            abi.encodePacked(
                                response,
                                "\tnothing to rebalance."
                            )
                        );
                    }
                    console2.log(response);
                }
            }
        }
        console2.log("OK");
    }

    function testCalculateLazySyncing() external {
        int24 k = 6;
        for (int24 width = 1; width <= k; width++) {
            int24 tickSpacing = width >= 4 ? int24(2) : int24(1);
            if (width % tickSpacing != 0) continue;
            for (int24 tickLower = -k; tickLower <= k; tickLower++) {
                if (tickLower % tickSpacing != 0) continue;
                int24 tickUpper = tickLower + width;

                for (
                    int24 spotTick = tickLower - width;
                    spotTick <= tickUpper + width;
                    spotTick++
                ) {
                    if (width % tickSpacing != 0) continue;
                    (
                        bool isRebalanceRequired,
                        ICore.TargetNftsInfo memory target
                    ) = pulseStrategyModule.calculateTarget(
                            spotTick,
                            tickLower,
                            tickUpper,
                            IPulseStrategyModule.StrategyParams({
                                strategyType: IPulseStrategyModule
                                    .StrategyType
                                    .LazySyncing,
                                tickSpacing: tickSpacing,
                                tickNeighborhood: 0
                            })
                        );
                    string memory response = string(
                        abi.encodePacked(
                            "initial: {",
                            vm.toString(tickLower),
                            ", ",
                            vm.toString(tickUpper),
                            "} spot=",
                            vm.toString(spotTick),
                            "\ttickSpacing=",
                            vm.toString(tickSpacing)
                        )
                    );

                    if (isRebalanceRequired) {
                        response = string(
                            abi.encodePacked(
                                response,
                                "\ttarget: {",
                                vm.toString(target.lowerTicks[0]),
                                ", ",
                                vm.toString(target.upperTicks[0]),
                                "}"
                            )
                        );
                    } else {
                        response = string(
                            abi.encodePacked(
                                response,
                                "\tnothing to rebalance."
                            )
                        );
                    }
                    console2.log(response);
                }
            }
        }
        console2.log("OK");
    }
}
