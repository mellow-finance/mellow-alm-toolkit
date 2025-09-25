// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Mock.sol";
import "./VoterMock.sol";

contract GaugeMock is Mock {
    address public immutable pool;
    VoterMock public immutable voter;

    constructor(address pool_) {
        pool = pool_;
        voter = new VoterMock();
    }
}
