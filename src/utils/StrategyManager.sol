// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IVeloDeployFactory, ILpWrapper} from "../interfaces/utils/IVeloDeployFactory.sol";
import {DefaultAccessControl} from "./DefaultAccessControl.sol";

contract StrategyManager is DefaultAccessControl {
    error InvalidLength();

    constructor(address admin) DefaultAccessControl(admin) {}

    mapping(uint256 => bytes) public parametersById;
    mapping(address => uint256) public poolToId;
    uint256 public nextId = 1;

    function addParameters(
        uint16 slippageD4,
        bytes memory callbackParams,
        bytes memory strategyParams,
        bytes memory securityParams
    ) external {
        _requireAtLeastOperator();
        parametersById[nextId++] = abi.encode(
            slippageD4,
            callbackParams,
            strategyParams,
            securityParams
        );
    }

    function setIds(address[] memory pools, uint256[] memory ids) external {
        _requireAtLeastOperator();
        if (pools.length != ids.length) revert InvalidLength();
        for (uint256 i = 0; i < pools.length; i++) {
            poolToId[pools[i]] = ids[i];
        }
    }

    function updateParameters(
        IVeloDeployFactory factory,
        address[] memory pools
    ) external {
        _requireAtLeastOperator();

        for (uint256 i = 0; i < pools.length; i++) {
            address pool = pools[i];
            IVeloDeployFactory.PoolAddresses memory addresses = factory
                .poolToAddresses(pool);
            if (address(addresses.synthetixFarm) == address(0)) continue;
            uint256 id = poolToId[pool];
            if (id == 0) continue;
            bytes memory params = parametersById[id];
            if (params.length == 0) continue;

            (
                uint16 slippageD4,
                bytes memory callbackParams,
                bytes memory strategyParams,
                bytes memory securityParams
            ) = abi.decode(params, (uint16, bytes, bytes, bytes));
            ILpWrapper(addresses.lpWrapper).setPositionParams(
                slippageD4,
                callbackParams,
                strategyParams,
                securityParams
            );
        }
    }
}
