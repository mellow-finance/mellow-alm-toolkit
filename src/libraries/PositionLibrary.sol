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

    function getPosition(address positionManager, uint256 tokenId)
        internal
        view
        returns (Position memory position)
    {
        assembly {
            let memPtr := mload(0x40)
            mstore(memPtr, 0x99fbab8800000000000000000000000000000000000000000000000000000000)
            mstore(add(memPtr, 0x04), tokenId)

            let success := staticcall(
                gas(),
                positionManager,
                memPtr,
                0x24,
                memPtr,
                0x180
            )

            if iszero(success) {
                revert(0, 0)
            }
            
            mstore(add(position, 0x00), mload(memPtr))               // nonce
            mstore(add(position, 0x20), mload(add(memPtr, 0x20)))    // operator
            mstore(add(position, 0x40), mload(add(memPtr, 0x40)))    // token0
            mstore(add(position, 0x60), mload(add(memPtr, 0x60)))    // token1
            mstore(add(position, 0x80), mload(add(memPtr, 0x80)))    // tickSpacing
            mstore(add(position, 0xa0), mload(add(memPtr, 0xa0)))    // tickLower
            mstore(add(position, 0xc0), mload(add(memPtr, 0xc0)))    // tickUpper
            mstore(add(position, 0xe0), mload(add(memPtr, 0xe0)))    // liquidity
            mstore(add(position, 0x100), mload(add(memPtr, 0x100)))  // feeGrowthInside0LastX128
            mstore(add(position, 0x120), mload(add(memPtr, 0x120)))  // feeGrowthInside1LastX128
            mstore(add(position, 0x140), mload(add(memPtr, 0x140)))  // tokensOwed0
            mstore(add(position, 0x160), mload(add(memPtr, 0x160)))  // tokensOwed1
            mstore(add(position, 0x180), tokenId)                    // tokenId
        }
    }
}
