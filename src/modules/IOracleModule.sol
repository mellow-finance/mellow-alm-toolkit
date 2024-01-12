// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IOracleModule {
    function getOraclePrice(
        address pool,
        bytes memory params
    ) external view returns (uint160 sqrtPriceX96, int24 tick);

    function ensureNoMEV(address pool, bytes memory params) external view;

    function validateSecurityParams(bytes memory params) external view;
}
