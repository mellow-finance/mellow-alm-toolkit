// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@zodiac/core/Module.sol";

import "./UniV3AmmModule.sol";

contract UniV3AmmGnosisModule is UniV3AmmModule {
    using SafeERC20 for IERC20;

    constructor(
        INonfungiblePositionManager positionManager_
    ) UniV3AmmModule(positionManager_) {}

    function beforeRebalance(
        address,
        address vault,
        uint256 tokenId
    ) external override {
        positionManager.transferFrom(address(this), address(vault), tokenId);
    }

    function afterRebalance(
        address,
        address vault,
        uint256
    ) external override {}
}
