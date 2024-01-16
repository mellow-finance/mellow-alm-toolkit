// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@zodiac/core/Module.sol";

import "./UniV3AmmModule.sol";

contract UniV3AmmGnosisModule is UniV3AmmModule, Module {
    error InvalidState();
    error Forbidden();

    using SafeERC20 for IERC20;

    constructor(
        INonfungiblePositionManager positionManager_
    ) UniV3AmmModule(positionManager_) {}

    function setUp(bytes memory) public override {}

    function beforeRebalance(
        address,
        address vault,
        uint256 tokenId
    ) external override {
        if (msg.sender != address(this)) revert();
        (bool success, ) = execAndReturnData(
            vault,
            0,
            abi.encodeWithSelector(
                positionManager.approve.selector,
                address(this),
                tokenId
            ),
            Enum.Operation.Call
        );
        if (!success) revert InvalidState();
        positionManager.transferFrom(vault, address(this), tokenId);
    }

    function afterRebalance(
        address,
        address vault,
        uint256 tokenId
    ) external override {
        positionManager.transferFrom(address(this), address(vault), tokenId);
    }
}
