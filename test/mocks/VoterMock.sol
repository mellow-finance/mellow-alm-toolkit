// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Mock.sol";

contract VoterMock is Mock {
    function isAlive(address) external pure returns (bool) {
        return false;
    }
}
