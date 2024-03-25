// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../IAmmModule.sol";

import "../../external/velo/ICLPool.sol";
import "../../external/velo/ICLGauge.sol";
import "../../external/velo/ICLFactory.sol";
import "../../external/velo/INonfungiblePositionManager.sol";

import "../../utils/ICounter.sol";

/**
 * @title IVeloAmmModule Interface
 * @dev Extension of the IAmmModule interface for interaction with the Velo protocol,
 * including functions for handling callback and protocol parameters, as well as accessing
 * Velo-specific contracts and settings.
 */
interface IVeloAmmModule is IAmmModule {
    error InvalidFee(); // Thrown when the fee is invalid
    error AddressZero(); // Thrown when an address is zero
    error InvalidParams(); // Thrown when input parameters are invalid
    error InvalidLength(); // Thrown when array lengths are mismatched or invalid

    /**
     * @dev Struct representing callback parameters for operations within the Velo protocol.
     * Includes addresses for the farm, gauge, and counter associated with a particular operation.
     */
    struct CallbackParams {
        address farm; // Address of the farm contract
        address gauge; // Address of the Velo gauge
        address counter; // Address of a counter contract for counting operations or events
    }

    /**
     * @dev Struct representing protocol parameters for the Velo AMM module.
     * Includes the treasury address and a fee percentage.
     */
    struct ProtocolParams {
        address treasury; // Treasury address for fee collection
        uint32 feeD9; // Fee percentage, represented as a fixed-point number with 9 decimal places
    }

    /**
     * @dev Returns 10 ** 9, the base for fixed-point calculations.
     * @return uint256 representing 10^9 for fixed-point arithmetic.
     */
    function D9() external view returns (uint256);

    /**
     * @dev Returns the maximum protocol fee allowed within the Velo AMM module.
     * @return uint32 maximum protocol fee as a uint32 value.
     */
    function MAX_PROTOCOL_FEE() external view returns (uint32);

    /**
     * @dev Returns the address of the ICLFactory contract used by the Velo protocol.
     * @return ICLFactory contract address.
     */
    function factory() external view returns (ICLFactory);
}
