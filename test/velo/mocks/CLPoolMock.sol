// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Mock.sol";

contract CLPoolMock is Mock {
    address public immutable token0;
    address public immutable token1;
    int24 public immutable tickSpacing;

    constructor(address token0_, address token1_, int24 tickSpacing_) {
        token0 = token0_;
        token1 = token1_;
        tickSpacing = tickSpacing_;
    }
}
