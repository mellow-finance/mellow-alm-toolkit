// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    Core public core;
    VeloOracle public oracle = new VeloOracle();
    VeloAmmModule public ammModule =
        new VeloAmmModule(
            positionManager,
            Constants.PROTOCOL_TREASURY,
            Constants.PROTOCOL_FEE_D9
        );

    function testConstants() external {}
}
