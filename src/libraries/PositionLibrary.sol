// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../interfaces/external/velo/INonfungiblePositionManager.sol";
import "@openzeppelin/contracts/utils/Address.sol";

library PositionLibrary {
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

    // This function consumes ~22,232 gas, which is more efficient than the 23,141 gas required for a regular call to NonfungiblePositionManager::positions
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
