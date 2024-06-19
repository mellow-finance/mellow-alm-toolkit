// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import "../../test/velo-prod/integration/IntegrationTest.t.sol";
import "./HistoryStrategyTest.t.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        HistoryTest historyTest = new HistoryTest();

        console.log("Contract deployed at:", address(historyTest));
        console.log("Contract bytecode length:", address(historyTest).code.length);

        vm.stopBroadcast();
    }
}
