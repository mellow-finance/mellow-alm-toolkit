// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";

import {IVeloDeployFactory, ILpWrapper, ICore} from "../interfaces/utils/IVeloDeployFactory.sol";
import {DefaultAccessControl} from "./DefaultAccessControl.sol";

import {IVeloOracle} from "../interfaces/oracles/IVeloOracle.sol";
import {IVeloAmmModule} from "../interfaces/modules/velo/IVeloAmmModule.sol";
import {IPulseStrategyModule} from "../interfaces/modules/strategies/IPulseStrategyModule.sol";

contract StrategyManager is DefaultAccessControl {
    error InvalidLength();

    constructor(address admin) DefaultAccessControl(admin) {}

    mapping(uint256 => bytes) private _parametersById;
    mapping(address => uint256) public poolToId;
    uint256 public nextId = 1;

    function parametersById(
        uint256 id
    ) external view returns (string memory response) {
        bytes memory params = _parametersById[id];
        if (params.length == 0) return "No parameters found";
        (
            uint16 slippageD4,
            bytes memory strategyParams_,
            bytes memory securityParams_
        ) = abi.decode(params, (uint16, bytes, bytes));
        string memory securityParamsStr;
        {
            IVeloOracle.SecurityParams memory securityParams = abi.decode(
                securityParams_,
                (IVeloOracle.SecurityParams)
            );
            securityParamsStr = string(
                abi.encodePacked(
                    "\nSecurity Params: ",
                    "\nlookback: ",
                    Strings.toString(securityParams.lookback),
                    "\nmaxAllowedDelta: ",
                    Strings.toString(securityParams.maxAllowedDelta)
                )
            );
        }
        string memory strategyParamsStr;
        {
            IPulseStrategyModule.StrategyParams memory strategyParams = abi
                .decode(strategyParams_, (IPulseStrategyModule.StrategyParams));
            strategyParamsStr = string(
                abi.encodePacked(
                    "\nStrategy Params: ",
                    "\nstrategyType: ",
                    Strings.toString(uint256(strategyParams.strategyType)),
                    "\ntickNeighborhood: ",
                    Strings.toString(strategyParams.tickNeighborhood),
                    "\ntickSpacing: ",
                    Strings.toString(strategyParams.tickSpacing),
                    "\nwidth: ",
                    Strings.toString(strategyParams.width)
                )
            );
        }

        response = string(
            abi.encodePacked(
                "Slippage: ",
                Strings.toString(slippageD4),
                strategyParamsStr,
                securityParamsStr
            )
        );
    }

    function addParameters(
        uint16 slippageD4,
        bytes memory strategyParams,
        bytes memory securityParams
    ) external {
        _requireAtLeastOperator();
        _parametersById[nextId++] = abi.encode(
            slippageD4,
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
            bytes memory params = _parametersById[id];
            if (params.length == 0) continue;

            (
                uint16 slippageD4,
                bytes memory strategyParams,
                bytes memory securityParams
            ) = abi.decode(params, (uint16, bytes, bytes));
            ILpWrapper wrapper = ILpWrapper(addresses.lpWrapper);
            bytes memory callbackParams = ICore(wrapper.core())
                .managedPositionAt(wrapper.positionId())
                .callbackParams;
            ILpWrapper(addresses.lpWrapper).setPositionParams(
                slippageD4,
                callbackParams,
                strategyParams,
                securityParams
            );
        }
    }
}
