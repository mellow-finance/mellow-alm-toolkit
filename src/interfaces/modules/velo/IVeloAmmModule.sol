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
     * @dev Struct representing callback parameters for operations associated with the Velo protocol.
     *
     * Parameters:
     * @param farm Address of the Synthetix farm contract. It acts as a central hub for yield farming activities, interfacing directly
     * with users and other contracts to manage and allocate yield farming rewards based on defined criteria.
     * @param gauge Address of the Velo gauge contract.
     * @param counter Address of a counter contract. This contract is designed for tracking and aggregating
     * specific numerical data, such as the total amount of rewards added to the farm. It serves as a
     * specialized tool for monitoring and reporting on key metrics that inform decisions and actions within
     * the protocol, ensuring transparency and accuracy in reward distribution and other quantifiable activities.
     */
    struct CallbackParams {
        address farm; // Synthetix farm contract address for yield farming operations
        address gauge; // Velo gauge contract address
        address counter; // Counter contract address for aggregating and tracking numerical data, such as reward amounts
    }

    /**
     * @dev Struct representing the operational parameters specific to the Velo AMM module.
     * These parameters play a crucial role in defining how the module interacts financially
     * with the broader ecosystem, including aspects of fee collection and distribution.
     * @param treasury The address of the Mellow protocol's treasury. This address is used
     * to collect fees generated by the operations within the Velo AMM module.
     * @param feeD9 The fee percentage charged by the Velo AMM module.
     * This fee is denoted in a fixed-point format with 9 decimal places,
     * allowing for precise representation of fee percentages smaller than one percent. For example,
     * a `feeD9` value of 10,000,000 represents a fee of 1%, while a value of 1,000,000 represents
     * a 0.1% fee.
     */
    struct ProtocolParams {
        address treasury; // Mellow protocol treasury address for fee collection
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
