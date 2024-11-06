// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/external/velo/INonfungiblePositionManager.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title PositionLibrary
 * @notice Provides utilities to interact with and manage positions in an AMM (Automated Market Maker) pool.
 * @dev This library allows for optimized, gas-efficient retrieval of position data from a Nonfungible Position Manager contract.
 *      The `Position` struct represents an individual position, encapsulating details such as liquidity, fee growth, tick range, and tokens owed.
 */
library PositionLibrary {
    /**
     * @notice Represents a position in an AMM pool with detailed attributes.
     * @dev This struct contains information about a specific position, including liquidity, fee growth, and token owed data.
     * @param nonce A unique identifier for each position to prevent replay attacks.
     * @param operator The address authorized to manage this position.
     * @param token0 The address of the first token in the position pair.
     * @param token1 The address of the second token in the position pair.
     * @param tickSpacing The spacing between ticks in the AMM pool.
     * @param tickLower The lower tick boundary for this position.
     * @param tickUpper The upper tick boundary for this position.
     * @param liquidity The amount of liquidity provided by this position.
     * @param feeGrowthInside0LastX128 The fee growth of token0 inside the position’s tick range since the last action.
     * @param feeGrowthInside1LastX128 The fee growth of token1 inside the position’s tick range since the last action.
     * @param tokensOwed0 The amount of token0 owed to the position.
     * @param tokensOwed1 The amount of token1 owed to the position.
     * @param tokenId The unique identifier of the position token.
     */
    struct Position {
        uint96 nonce;
        address operator;
        address token0;
        address token1;
        int24 tickSpacing;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
        uint256 tokenId;
    }

    /**
     * @notice Fetches position details for a specific tokenId from the position manager.
     * @dev Uses an optimized `staticcall` in assembly for reduced gas consumption.
     *      Consumes ~22,232 gas, which is more efficient than the ~23,141 gas required for a typical call to NonfungiblePositionManager::positions.
     *      Stores the function selector and tokenId in memory and performs a staticcall to retrieve data.
     * @param positionManager The address of the NonfungiblePositionManager contract managing the positions.
     * @param tokenId The unique identifier of the position token.
     * @return position The position struct with detailed information.
     */
    function getPosition(address positionManager, uint256 tokenId)
        internal
        view
        returns (Position memory position)
    {
        assembly {
            // Set up a memory pointer for the function selector and arguments
            let memPtr := mload(0x40)

            // Store the function selector of `positions(uint256)` in memory (0x99fbab88)
            mstore(memPtr, 0x99fbab8800000000000000000000000000000000000000000000000000000000)

            // Store the tokenId argument directly after the function selector
            mstore(add(memPtr, 0x04), tokenId)

            // Call the positionManager contract with staticcall to fetch the position data
            // gas() provides remaining gas, and 0x24 is the calldata size (4 bytes for selector + 32 bytes for tokenId)
            // The data is returned to the position memory location, with expected size 0x180
            let success := staticcall(gas(), positionManager, memPtr, 0x24, position, 0x180)

            // Revert if the call fails
            if iszero(success) { revert(0, 0) }

            // Store the tokenId at the end of the position memory (0x180 offset)
            mstore(add(position, 0x180), tokenId)
        }
    }
}
