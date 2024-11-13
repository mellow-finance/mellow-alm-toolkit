// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../src/Core.sol";
import "../../src/oracles/VeloOracle.sol";

interface IDeprecatedCore {
    struct RebalanceParams {
        uint256[] ids;
        address callback;
        bytes data;
    }

    struct ManagedPositionInfo {
        uint32 slippageD9;
        uint24 property;
        address owner;
        address pool;
        uint256[] ammPositionIds;
        bytes callbackParams;
        bytes strategyParams;
        bytes securityParams;
    }

    function managedPositionAt(uint256 id) external view returns (ManagedPositionInfo memory);

    function rebalance(RebalanceParams memory params) external;
}

contract OperatorContract {
    address public constant operator = 0x0A16Bc694EeA56cbFc808a271178556d3f8c23aD;
    VeloOracle public immutable oracle;

    constructor() {
        oracle = new VeloOracle();
    }

    function rebalance(
        IDeprecatedCore core,
        IDeprecatedCore.RebalanceParams calldata rebalanceParams
    ) external {
        require(msg.sender == operator, "OperatorContract: caller is not the operator");
        require(rebalanceParams.ids.length == 1, "OperatorContract: invalid rebalance params");
        uint256 positionId = rebalanceParams.ids[0];
        IDeprecatedCore.ManagedPositionInfo memory info = core.managedPositionAt(positionId);
        oracle.ensureNoMEV(info.pool, info.securityParams);
        core.rebalance(rebalanceParams);
    }
}
