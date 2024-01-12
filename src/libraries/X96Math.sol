// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../libraries/external/FullMath.sol";

type X96 is uint256;

library X96Math {
    uint256 public constant Q96 = 2 ** 96;

    function add(X96 a, X96 b) internal pure returns (X96) {
        return X96.wrap(X96.unwrap(a) + X96.unwrap(b));
    }

    function add(X96 a, uint256 b) internal pure returns (X96) {
        return X96.wrap(X96.unwrap(a) + b);
    }

    function sub(X96 a, X96 b) internal pure returns (X96) {
        return X96.wrap(X96.unwrap(a) - X96.unwrap(b));
    }

    function sub(X96 a, uint256 b) internal pure returns (X96) {
        return X96.wrap(X96.unwrap(a) - b);
    }

    function mul(X96 a, uint256 b) internal pure returns (X96) {
        return X96.wrap(X96.unwrap(a) * b);
    }

    function mul(X96 a, X96 b) internal pure returns (X96) {
        return X96.wrap(FullMath.mulDiv(X96.unwrap(a), X96.unwrap(b), Q96));
    }

    function div(X96 a, uint256 b) internal pure returns (X96) {
        return X96.wrap(X96.unwrap(a) / b);
    }

    function div(X96 a, X96 b) internal pure returns (X96) {
        return X96.wrap(FullMath.mulDiv(X96.unwrap(a), Q96, X96.unwrap(b)));
    }

    function div(uint256 a, X96 b) internal pure returns (X96) {
        return X96.wrap(FullMath.mulDiv(a, Q96, X96.unwrap(b)));
    }

    function mulDiv(X96 a, X96 b, X96 c) internal pure returns (X96) {
        return
            X96.wrap(
                FullMath.mulDiv(X96.unwrap(a), X96.unwrap(b), X96.unwrap(c))
            );
    }

    function mulDiv(X96 a, uint256 b, uint256 c) internal pure returns (X96) {
        return X96.wrap(FullMath.mulDiv(X96.unwrap(a), b, c));
    }

    function toUint(X96 a) internal pure returns (uint256) {
        return X96.unwrap(a) / Q96;
    }

    function toX96(uint256 a) internal pure returns (X96) {
        return X96.wrap(a * Q96);
    }
}
