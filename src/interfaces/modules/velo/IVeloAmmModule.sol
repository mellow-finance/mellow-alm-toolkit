// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../IAmmModule.sol";

import "../../external/velo/ICLPool.sol";
import "../../external/velo/ICLGauge.sol";
import "../../external/velo/ICLFactory.sol";
import "../../external/velo/INonfungiblePositionManager.sol";

interface IVeloAmmModule is IAmmModule {
    error InvalidFee();
    error AddressZero();
    error InvalidParams();
    error InvalidLength();

    struct CallbackParams {
        address farm;
        address gauge;
    }

    struct ProtocolParams {
        address treasury;
        uint32 feeD9;
    }

    function D9() external view returns (uint256);

    function MAX_PROTOCOL_FEE() external view returns (uint32);

    function factory() external view returns (ICLFactory);
}
