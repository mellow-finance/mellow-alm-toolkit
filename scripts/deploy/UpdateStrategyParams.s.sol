// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./Pools.sol";

contract UpdateStrategyParams is Test {
    address internal constant ADMIN = 0x893df22649247AD4e57E4926731F9Cf0dA344829;
    address internal constant CORE = 0x0000000cE42D4981513060aB7E50B9e5e2D19AF1;

    /*
        Pool address                                LpWrapper address                           Symbol         Strategy    Width
        --------------------------------------------------------------------------------------------------------------------------------
        0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59  0xcd975e6a5F55137755487F0918b8ca74aCCe7925  WETH / USDC    lazySync    700
        0x70aCDF2Ad0bf2402C957154f944c19Ef4e1cbAE1  0xB9DB6804e84D960E139A2BdC33bfC30f8fb689Fe  WETH / cbBTC   lazySync    800
        0x4e962BB3889Bf030368F56810A9c96B83CB3E778  0x0Df5f2662e4a8C801c04D83Df717476509816250  USDC / cbBTC   lazySync    700
        0xc5E51044eB7318950B1aFb044FccFb25782C48c1  0xf7511B7433241A2873e089965578FF34b3eceb84  EURC / USDC    lazySync    2
        0xa41Bc0AFfbA7Fd420d186b84899d7ab2aC57fcD1  0x33DB29651B30C09c0a9184893215905E5F536130  USDC / USDT    lazySync    2
    */
    function run() external {
        vm.startPrank(ADMIN);
        getStrategyParams(0xcd975e6a5F55137755487F0918b8ca74aCCe7925, 700); // 0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59 WETH / USDC
        getStrategyParams(0xB9DB6804e84D960E139A2BdC33bfC30f8fb689Fe, 800); // 0x70aCDF2Ad0bf2402C957154f944c19Ef4e1cbAE1 WETH / cbBTC
        getStrategyParams(0x0Df5f2662e4a8C801c04D83Df717476509816250, 700); // 0x4e962BB3889Bf030368F56810A9c96B83CB3E778 USDC / cbBTC
        getStrategyParams(0xf7511B7433241A2873e089965578FF34b3eceb84, 2); // 0xc5E51044eB7318950B1aFb044FccFb25782C48c1 EURC / USDC
        getStrategyParams(0x33DB29651B30C09c0a9184893215905E5F536130, 2); // 0xa41Bc0AFfbA7Fd420d186b84899d7ab2aC57fcD1 USDC / USDT
        vm.stopPrank();
    }

    function getStrategyParams(address lpWrapper, int24 width) internal {
        /// @dev fetch existing position info
        ICore.ManagedPositionInfo memory positionInfo =
            ICore(CORE).managedPositionAt(ILpWrapper(lpWrapper).positionId());
        IPulseStrategyModule.StrategyParams memory strategyParams =
            abi.decode(positionInfo.strategyParams, (IPulseStrategyModule.StrategyParams));

        /// @dev update width and strategy type to LazySyncing
        uint24 oldWidth = uint24(strategyParams.width);
        strategyParams.width = width;
        strategyParams.strategyType = IPulseStrategyModule.StrategyType.LazySyncing;
        strategyParams.maxLiquidityRatioDeviationX96 = 0;

        /// @dev prepare raw calldata (to use later in Safe) and execute the update, save slippageD9/callback/security params as is
        bytes memory callData = abi.encodeWithSignature(
            "setPositionParams(uint32,bytes,bytes,bytes)",
            positionInfo.slippageD9,
            positionInfo.callbackParams,
            abi.encode(strategyParams),
            positionInfo.securityParams
        );
        lpWrapper.call(callData);

        /// @dev verify updated params
        positionInfo = ICore(CORE).managedPositionAt(ILpWrapper(lpWrapper).positionId());
        assertEq(
            width,
            abi.decode(positionInfo.strategyParams, (IPulseStrategyModule.StrategyParams)).width
        );

        console2.log(
            "\nCalldata to setPositionParams at LpWrapper %s, pool %s",
            lpWrapper,
            ILpWrapper(lpWrapper).pool()
        );
        console2.log("Change width %s -> %s calldata", oldWidth, uint24(strategyParams.width));
        console2.logBytes(callData);
    }
}
