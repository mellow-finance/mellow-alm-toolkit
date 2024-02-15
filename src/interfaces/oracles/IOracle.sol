// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

interface IOracle {
    function getOraclePrice(
        address pool
    ) external view returns (uint160 sqrtPriceX96, int24 tick);

    function ensureNoMEV(address pool, bytes memory params) external view;

    function validateSecurityParams(bytes memory params) external view;
}
