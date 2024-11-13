// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/deprecated/OperatorContract.sol";
import "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("OPERATOR_PRIVATE_KEY"))));
        OperatorContract operatorContract = new OperatorContract();
        console2.log("operatorContract:", address(operatorContract));
        vm.stopBroadcast();
        revert("Success");
    }
}
