// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./external/IWETH9.sol";

import "./modules/IAmmDepositWithdrawModule.sol";
import "./modules/IAmmModule.sol";

import "./modules/IStrategyModule.sol";
import "./oracles/IOracle.sol";
import "./utils/IRebalanceCallback.sol";
import "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface ICore is IERC721Receiver, IAccessControlEnumerable {
    /**
     * @notice Parameters used in the Rebalance event.
     * @dev This struct captures details about a rebalancing event within the AMM pool.
     * @param pool The address of the pool being rebalanced.
     * @param ammPositionInfo Information about the AMM position, such as tick range, liquidity, etc.
     * @param sqrtPriceX96 The square root of the price at the time of the rebalance, in Q96 format.
     * @param amount0 The amount of token0 involved in the rebalance.
     * @param amount1 The amount of token1 involved in the rebalance.
     * @param ammPositionIdBefore The AMM position ID before the rebalance.
     * @param ammPositionIdAfter The AMM position ID after the rebalance.
     */
    struct RebalanceEventParams {
        address pool;
        IAmmModule.AmmPosition ammPositionInfo;
        uint160 sqrtPriceX96;
        uint256 amount0;
        uint256 amount1;
        uint256 ammPositionIdBefore;
        uint256 ammPositionIdAfter;
    }

    /**
     * @notice Emitted when a rebalance operation occurs in the AMM pool.
     * @param rebalanceEventParams Parameters of the rebalance event.
     */
    event Rebalance(RebalanceEventParams rebalanceEventParams);

    /**
     * @notice Emitted when the protocol parameters are set.
     * @param protocolParams_ The new protocol parameters.
     * @param sender The address of the sender.
     */
    event ProtocolParamsSet(bytes protocolParams_, address sender);

    /**
     * @notice Emitted when the position parameters are set.
     * @param id The ID of the position.
     * @param slippageD9 The slippage of the position.
     * @param callbackParams The callback parameters of the position.
     * @param strategyParams The strategy parameters of the position.
     * @param securityParams The security parameters of the position.
     * @param sender The address of the sender.
     */
    event PositionParamsSet(
        uint256 id,
        uint32 slippageD9,
        bytes callbackParams,
        bytes strategyParams,
        bytes securityParams,
        address sender
    );

    /**
     * @title ManagedPositionInfo Structure
     * @dev This structure holds information about a managed position within a liquidity management system.
     * It captures various parameters crucial for the operation, management, and strategic decision-making
     * for a specific position in Automated Market Makers (AMM) environments.
     */
    struct ManagedPositionInfo {
        /**
         * @notice Determines the portion of the Total Value Locked (TVL) in the ManagedPosition that can be used to pay for rebalancer services.
         * @dev Value is multiplied by 1e9. For instance, slippageD9 = 10'000'000 corresponds to 1% of the position.
         * This allows for fine-grained control over the economic parameters governing rebalancing actions.
         */
        uint32 slippageD9;
        /**
         * @notice A pool parameter corresponding to the ManagedPosition, usually representing tickSpacing or fee.
         * @dev This parameter helps in identifying and utilizing specific characteristics of the pool that are relevant to the management of the position.
         */
        uint24 property;
        /**
         * @notice The owner of the position, capable of performing actions such as withdraw, emptyRebalance, and parameter updates.
         * @dev Ensures that only the designated owner can modify or interact with the position, safeguarding against unauthorized access or actions.
         */
        address owner;
        /**
         * @notice The pool corresponding to the ManagedPosition.
         * @dev Identifies the specific AMM pool that this position is associated with, facilitating targeted management and operations.
         */
        address pool;
        /**
         * @notice An array of NFTs from the AMM protocol corresponding to the ManagedPosition.
         * @dev Allows for the aggregation and management of multiple AMM positions under a single managed position, enhancing the flexibility and capabilities of the system.
         */
        uint256[] ammPositionIds;
        /**
         * @notice A byte array containing custom data for the corresponding AmmModule.
         * @dev Stores information necessary for operations like staking, reward collection, etc., enabling customizable and protocol-specific interactions.
         */
        bytes callbackParams;
        /**
         * @notice A byte array containing custom data for the corresponding StrategyModule.
         * @dev Holds information about the parameters of the associated strategy, allowing for the implementation and execution of tailored strategic decisions.
         */
        bytes strategyParams;
        /**
         * @notice A byte array containing custom data for the corresponding Oracle.
         * @dev Contains parameters for price fetching and protection against MEV (Miner Extractable Value) attacks, enhancing the security and integrity of the position.
         */
        bytes securityParams;
    }

    /**
     * @title TargetPositionInfo Structure
     * @dev This structure contains data that allows a rebalancer to obtain information about the required final parameters of AMM positions for a specific ManagedPosition.
     */
    struct TargetPositionInfo {
        /**
         * @notice Index of the ManagedPosition.
         * @dev Serves as a unique identifier for the ManagedPosition being targeted for rebalancing. This facilitates tracking and management within the broader system.
         */
        uint256 id;
        /**
         * @notice Array of lower ticks corresponding to the expected AMM Positions after rebalancing.
         * @dev These ticks define the lower bound of the price ranges for each targeted AMM position. They are integral in determining the optimal positioning and allocation of liquidity within the AMM environment post-rebalance.
         */
        int24[] lowerTicks;
        /**
         * @notice Array of upper ticks corresponding to the expected AMM Positions after rebalancing.
         * @dev Similar to `lowerTicks`, these define the upper bound of the price ranges for each targeted AMM position. Together, the lower and upper ticks delineate the price intervals where liquidity will be optimally positioned.
         */
        int24[] upperTicks;
        /**
         * @notice Distribution ratio of liquidity among positions, where the sum in the array equals Q96.
         * @dev This array represents the precise distribution of liquidity across the targeted positions, allowing for balanced and strategic allocation post-rebalance. The Q96 notation indicates fixed-point arithmetic for enhanced precision.
         */
        uint256[] liquidityRatiosX96;
        /**
         * @notice Minimum liquidity values for each of the expected AMM Positions after rebalancing.
         * @dev Sets the minimum acceptable liquidity for each position, ensuring that rebalancing actions do not result in suboptimal or excessively diluted positions.
         */
        uint256[] minLiquidities;
    }
    /**
     * @notice Information about the original corresponding ManagedPosition.
     * @dev Captures the initial state and parameters of the ManagedPosition prior to rebalancing. This includes detailed information necessary for the rebalancer to accurately target the desired end state.
     */
    // ManagedPositionInfo info;

    /**
     * @title DepositParams Structure
     * @dev This structure contains data for depositing AMM Positions and creating corresponding ManagedPositions with specified parameters. It is crucial for initializing and setting up ManagedPositions based on existing AMM positions.
     */
    struct DepositParams {
        /**
         * @notice Defines the portion of the Total Value Locked (TVL) in the ManagedPosition that can be used to pay for rebalancer services.
         * @dev The value is multiplied by 1e9, meaning a `slippageD9` value of 10'000'000 corresponds to 1% of the position. This parameter allows for precise economic management of the position with regard to rebalancing costs.
         */
        uint32 slippageD9;
        /**
         * @notice The owner of the position, who is authorized to perform actions such as withdraw, emptyRebalance, and parameter updates.
         * @dev Ensures that only the designated owner has the authority to manage and modify the position, safeguarding against unauthorized interventions.
         */
        address owner;
        /**
         * @notice Array of NFTs from the AMM protocol corresponding to the ManagedPosition.
         * @dev Enables the aggregation of multiple AMM positions under a single managed position, facilitating collective management and strategic oversight.
         */
        uint256[] ammPositionIds;
        /**
         * @notice A byte array containing custom data for the corresponding AmmModule.
         * @dev Stores operational data such as staking details, reward collection mechanisms, etc., providing a flexible interface for AMM-specific functionalities.
         */
        bytes callbackParams;
        /**
         * @notice A byte array containing custom data for the corresponding StrategyModule.
         * @dev Encapsulates strategic information, including parameters guiding the management and rebalancing of the position, allowing for tailored strategic execution.
         */
        bytes strategyParams;
        /**
         * @notice A byte array containing custom data for the corresponding Oracle.
         * @dev Contains parameters critical for accurate price fetching and MEV (Miner Extractable Value) protection mechanisms, enhancing the position's security and market responsiveness.
         */
        bytes securityParams;
    }

    /**
     * @title RebalanceParams Structure
     * @dev This structure contains parameters for rebalancing, filled out by the rebalancer. It is crucial for specifying which ManagedPositions are to be rebalanced and detailing how rebalancing actions should be conducted through interactions with a specified callback contract.
     */
    struct RebalanceParams {
        /**
         * @notice The ID for ManagedPosition that the rebalancer intends to rebalance.
         * @dev Identifies the specific positions within the liquidity management system that are targeted for rebalancing. This allows for focused and efficient rebalancing actions, addressing the needs of selected positions.
         */
        uint256 id;
        /**
         * @notice Address of the contract to which Core.sol will make calls during the rebalancing process to execute all operations with swaps, creation of new positions, etc.
         * @dev Specifies the external contract responsible for the operational aspects of the rebalancing process, such as executing swaps and managing position adjustments. This modular approach enables flexible and customizable rebalancing strategies.
         */
        address callback;
        /**
         * @notice Data for the above-mentioned callback contract.
         * @dev Contains the necessary information and instructions for the callback contract to execute the rebalancing actions. The format and content of this data are tailored to the specific requirements and functionalities of the callback contract.
         */
        bytes data;
    }

    /**
     * @dev Custom error for indicating invalid parameters have been supplied to a function.
     * This error is used when the arguments passed to a function do not meet the required criteria,
     * such as out-of-range values or parameters that do not adhere to expected formats or constraints.
     */
    error InvalidParams();

    /**
     * @dev Custom error for signaling that a rebalance operation is not needed.
     * This error is thrown when a rebalance operation is attempted but is deemed unnecessary,
     * typically due to the position already being in an optimal state or not requiring any adjustments.
     */
    error NoRebalanceNeeded();

    /**
     * @dev Custom error for signaling that an array or similar data structure has an invalid length.
     * This error is thrown when the length of an input array or similar data structure does not match
     * the expected or required length, potentially leading to incorrect or incomplete processing.
     */
    error InvalidLength();

    /**
     * @dev Custom error for indicating an invalid target has been specified.
     * This error is used in contexts where an operation targets a specific entity or address, such as a contract or token,
     * and the specified target does not meet the required conditions or is otherwise deemed inappropriate for the operation.
     */
    error InvalidTarget();

    /**
     * @dev Returns the address of the AMM module.
     * @return address of the AMM module.
     */
    function ammModule() external view returns (IAmmModule);

    /**
     * @dev Returns the address of the AMM deposit/withdraw module.
     * @return address of the AMM deposit/withdraw module.
     */
    function ammDepositWithdrawModule() external view returns (IAmmDepositWithdrawModule);

    /**
     * @dev Returns the address of the oracle contract.
     * @return address of the oracle contract.
     */
    function oracle() external view returns (IOracle);

    /**
     * @dev Returns the strategy module associated with the core contract.
     * @return address strategy module contract address.
     */
    function strategyModule() external view returns (IStrategyModule);

    /**
     * @dev Retrieves the ManagedPositionInfo struct at the specified index.
     * @param id The index of the ManagedPositionInfo struct to retrieve.
     * @return ManagedPositionInfo - struct at the specified index.
     */
    function managedPositionAt(uint256 id) external view returns (ManagedPositionInfo memory);

    /**
     * @dev Returns the count of managed positions within the contract.
     * @return uint256 - total count of managed positions.
     */
    function positionCount() external view returns (uint256);

    /**
     * @dev Retrieves the array of user IDs associated with the given user address.
     * @param user The address of the user.
     * @return ids array of user IDs.
     */
    function getUserIds(address user) external view returns (uint256[] memory ids);

    /**
     * @dev Returns the current protocol parameters.
     * This function provides access to protocol-wide settings and parameters
     * that govern the behavior and functionalities of the contract. These parameters
     * can include configurations related to fees and treasuries.
     *
     * @return bytes representation of the protocol parameters. The structure and
     * interpretation of these parameters depend on the AmmModule implementation and the
     * specific protocol logic it adheres to.
     */
    function protocolParams() external view returns (bytes memory);

    /**
     * @dev Sets the global protocol parameters for the contract.
     * This function is intended for administrative use, allowing for the adjustment of
     * critical operational parameters that govern the overall behavior of the protocol.
     * Changes made through this function can affect rebalancing logic, fee structures,
     * security mechanisms, and other foundational aspects of the protocol's operation.
     *
     * @param params A bytes memory data structure containing the new protocol parameters.
     * The structure and content of this data should adhere to the protocol's specification,
     * ensuring compatibility and correctness. This could include parameters such as global
     * slippage settings, fee rates, security thresholds, or other protocol-wide settings.
     *
     * Requirements:
     * - Only the admin of Core.sol can call this function.
     */
    function setProtocolParams(bytes memory params) external;

    /**
     * @dev Sets the parameters for a specific managed position identified by its ID.
     * This function allows updating the position's slippage, callback, strategy, and security parameters,
     * enabling dynamic adjustment of the position's operational and strategic settings. It is essential
     * for maintaining the relevance and efficiency of the position's strategy and security posture over time.
     *
     * @param id The unique identifier of the managed position to update.
     * @param slippageD9 The maximum allowable proportion of the position's capital that can be allocated
     * as compensation to rebalancers for their services. This value is scaled by a factor of 1,000,000,000 (1e9),
     * such that a value of 1,000,000,000 represents 100%, allowing for fine-grained control over rebalancing compensation.
     * @param callbackParams Custom data for the callback operation, facilitating specific interactions
     * and operational adjustments during the rebalancing or other contract-driven processes.
     * @param strategyParams Custom data defining the strategic parameters of the position, enabling
     * strategic adjustments and alignments with market conditions or portfolio objectives.
     * @param securityParams Custom data outlining the security parameters, crucial for adjusting the position's
     * security settings and mechanisms in response to evolving market threats or operational requirements.
     *
     * Requirements:
     * - The caller must be the owner of the position, ensuring that only authorized entities can
     *   make adjustments to the position's parameters.
     * - The strategy and security parameters must be valid, adhering to the contract's and underlying protocols'
     *   requirements and constraints, ensuring the integrity and effectiveness of the position's strategy and security.
     */
    function setPositionParams(
        uint256 id,
        uint32 slippageD9,
        bytes memory callbackParams,
        bytes memory strategyParams,
        bytes memory securityParams
    ) external;

    /**
     * @notice Deposits specified amounts of tokens into a position directly.
     * @param id The identifier of the position.
     * @param tokenId The token ID associated with the position.
     * @param amount0 The amount of token0 to deposit.
     * @param amount1 The amount of token1 to deposit.
     * @return The actual amounts of token0 and token1 deposited.
     */
    function directDeposit(uint256 id, uint256 tokenId, uint256 amount0, uint256 amount1)
        external
        returns (uint256, uint256);

    /**
     * @notice Withdraws a specified amount of liquidity from a position directly.
     * @param id The identifier of the position.
     * @param tokenId The token ID associated with the position.
     * @param liquidity The amount of liquidity to withdraw from the position.
     * @param to The address to which the withdrawn tokens should be sent.
     * @return The actual amounts of token0 and token1 withdrawn.
     */
    function directWithdraw(uint256 id, uint256 tokenId, uint256 liquidity, address to)
        external
        returns (uint256, uint256);

    /**
     * @dev Deposits multiple tokens into the contract and creates new ManagedPosition.
     * @param params The deposit parameters including strategy parameters, security parameters, slippage, and token IDs.
     * @return id The ID of the position for deposited tokens.
     */
    function deposit(DepositParams memory params) external returns (uint256 id);

    /**
     * @dev Withdraws AMM NFTs from the contract and transfers them to the specified address.
     * Only the owner of the position can call this function.
     * Deletes corresponding ManagedPosition.
     *
     * @param id The ID of the position with AMM NFTs to withdraw.
     * @param to The address to transfer AMM NFTs to.
     */
    function withdraw(uint256 id, address to) external;

    /**
     * @dev Rebalances the portfolio based on the given parameters.
     * @param params The parameters for rebalancing.
     *   - ids: An array of ids of positions to rebalance.
     *   - callback: The address of the callback contract.
     *   - data: Additional data to be passed to the callback contract.
     */
    function rebalance(RebalanceParams memory params) external;

    /**
     * @dev This function is used to perform an empty rebalance for a specific position.
     * @param id The ID of the position to perform the empty rebalance on.
     * @notice This function calls the `beforeRebalance` and `afterRebalance` functions of the `IAmmModule` contract for each tokenId of the position.
     * @notice If any of the delegate calls fail, the function will revert.
     * @notice This function is used to perform a rebalance without changing the position's liquidity.
     * @notice This function is only callable by the owner of the position.
     */
    function emptyRebalance(uint256 id) external;

    /**
     * @notice Collects rewards associated with a specific identifier.
     * @dev This function allows external accounts to claim rewards for a given ID.
     * @param id The identifier of position for which rewards are to be collected.
     */
    function collectRewards(uint256 id) external;
}
