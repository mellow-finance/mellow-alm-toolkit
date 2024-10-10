// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";

import {IVeloDeployFactory, ILpWrapper, ICore} from "../interfaces/utils/IVeloDeployFactory.sol";
import {DefaultAccessControl} from "./DefaultAccessControl.sol";

import "../interfaces/oracles/IVeloOracle.sol";
import {IVeloAmmModule} from "../interfaces/modules/velo/IVeloAmmModule.sol";
import "../interfaces/modules/strategies/IPulseStrategyModule.sol";

contract StrategyManager is DefaultAccessControl {
    error InvalidLength();

    constructor(address admin) DefaultAccessControl(admin) {}

    mapping(uint256 => bytes) private _parametersById;
    uint256 public nextId = 1;

    function parametersById(
        uint256 id
    ) external view returns (string memory response) {
        bytes memory params = _parametersById[id];
        if (params.length == 0) return "No parameters found";
        (
            uint32 slippageD9,
            IStrategyModule.StrategyParams memory strategyParams,
            IOracle.SecurityParams memory securityParams
        ) = abi.decode(params, (uint32, IStrategyModule.StrategyParams, IOracle.SecurityParams));
        string memory securityParamsStr;
        {
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
                Strings.toString(slippageD9),
                strategyParamsStr,
                securityParamsStr
            )
        );
    }

    function addParameters(
        uint32 slippageD9,
        IPulseStrategyModule.StrategyParams memory strategyParams,
        IOracle.SecurityParams memory securityParams
    ) external {
        _requireAtLeastOperator();
        _parametersById[nextId++] = abi.encode(
            slippageD9,
            strategyParams,
            securityParams
        );
    }

    function updateParameters(
        IVeloDeployFactory factory,
        address[] memory pools,
        uint256[] memory ids
    ) external {
        _requireAtLeastOperator();
        if (pools.length != ids.length) revert InvalidLength();

        for (uint256 i = 0; i < pools.length; i++) {
            address pool = pools[i];
            IVeloDeployFactory.PoolAddresses memory addresses = factory
                .poolToAddresses(pool);
            if (address(addresses.synthetixFarm) == address(0)) continue;
            uint256 id = ids[i];
            if (id == 0) continue;
            bytes memory params = _parametersById[id];
            if (params.length == 0) continue;

            (
                uint32 slippageD9,
                IStrategyModule.StrategyParams memory strategyParams,
                IOracle.SecurityParams memory securityParams
            ) = abi.decode(
                    params,
                    (
                        uint32,
                        IStrategyModule.StrategyParams,
                        IOracle.SecurityParams
                    )
                );
            ILpWrapper wrapper = ILpWrapper(addresses.lpWrapper);
            IVeloAmmModule.CallbackParams memory callbackParams = ICore(
                wrapper.core()
            ).managedPositionAt(wrapper.positionId()).coreParams.callbackParams;
            ILpWrapper(addresses.lpWrapper).setPositionParams(
                slippageD9,
                ICore.CoreParams({
                    callbackParams: callbackParams,
                    strategyParams: strategyParams,
                    securityParams: securityParams
                })
            );
        }
    }
}
