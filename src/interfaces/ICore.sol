// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./modules/IAmmModule.sol";
import "./modules/IStrategyModule.sol";
import "./oracles/IOracle.sol";

import "./utils/IRebalanceCallback.sol";

import "./modules/IAmmModule.sol";
import "./modules/IStrategyModule.sol";

import "./oracles/IOracle.sol";

interface ICore is IERC721Receiver {
    struct PositionInfo {
        uint16 slippageD4;
        uint24 property;
        address owner;
        address pool;
        address farm;
        address vault;
        uint256[] tokenIds;
        bytes securityParams;
        bytes strategyParams;
    }

    struct TargetPositionInfo {
        int24[] lowerTicks;
        int24[] upperTicks;
        uint256[] liquidityRatiosX96;
        uint256[] minLiquidities;
        uint256 id;
        PositionInfo info;
    }

    struct DepositParams {
        uint256[] tokenIds;
        address owner;
        address farm;
        address vault;
        uint16 slippageD4;
        bytes strategyParams;
        bytes securityParams;
    }

    struct RebalanceParams {
        uint256[] ids;
        address callback;
        bytes data;
    }

    error DelegateCallFailed();
    error InvalidParameters();
    error InvalidLength();
    error InvalidTarget();

    function D4() external view returns (uint256);
    function Q96() external view returns (uint256);
    function ammModule() external view returns (IAmmModule);
    function oracle() external view returns (IOracle);
    function strategyModule() external view returns (IStrategyModule);
    function positionManager() external view returns (address);
    function operatorFlag() external view returns (bool);

    /**
     * @dev Retrieves the PositionInfo struct at the specified index.
     * @param id The index of the PositionInfo struct to retrieve.
     * @return The PositionInfo struct at the specified index.
     */
    function position(uint256 id) external view returns (PositionInfo memory);

    /**
     * @dev Returns the count of positions in the contract.
     * @return uint256 count of positions.
     */
    function positionCount() external view returns (uint256);

    /**
     * @dev Retrieves the array of user IDs associated with the given user address.
     * @param user The address of the user.
     * @return ids array of user IDs.
     */
    function getUserIds(
        address user
    ) external view returns (uint256[] memory ids);

    /**
     * @dev Sets the operator flag to enable or disable operator functionality.
     * Only the admin can call this function.
     * @param operatorFlag_ The new value for the operator flag.
     */
    function setOperatorFlag(bool operatorFlag_) external;

    /**
     * @dev Sets the position parameters for a given ID.
     * @param id The ID of the position.
     * @param slippageD4 The maximum permissible proportion of the capital allocated to positions
     * that can be used to compensate rebalancers for their services. A value of 10,000 (1e4) represents 100%.
     * @param strategyParams The strategy parameters.
     * @param securityParams The security parameters.
     * Requirements:
     * - The caller must be the owner of the position.
     * - The strategy parameters must be valid.
     * - The security parameters must be valid.
     */
    function setPositionParams(
        uint256 id,
        uint16 slippageD4,
        bytes memory strategyParams,
        bytes memory securityParams
    ) external;

    /**
     * @dev Deposits multiple tokens into the contract.
     * @param params The deposit parameters including strategy parameters, security parameters, slippage, and token IDs.
     * @return id The ID of the position for deposited tokens.
     */
    function deposit(DepositParams memory params) external returns (uint256 id);

    /**
     * @dev Withdraws AMM NFTs from the contract and transfers them to the specified address.
     * Only the owner of the position can call this function.
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
     */
    function emptyRebalance(uint256 id) external;
}
