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

            let success := staticcall(gas(), positionManager, memPtr, 0x24, memPtr, 0x180)
            if iszero(success) { revert(0, 0) }

            returndatacopy(position, 0x00, 0x180)
            mstore(add(position, 0x180), tokenId)
        }
    }
}
