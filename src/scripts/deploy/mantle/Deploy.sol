// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../../../test/mantle/Constants.sol";

contract Deploy is Script {
    using SafeERC20 for IERC20;

    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("DEPLOYER_PK"))));

        address pool = IAgniFactory(AGNI_FACTORY).getPool(
            Constants.USDC,
            Constants.WETH,
            2500
        );

        IAgniPool(pool).increaseObservationCardinalityNext(10);

        vm.stopBroadcast();
    }
}
