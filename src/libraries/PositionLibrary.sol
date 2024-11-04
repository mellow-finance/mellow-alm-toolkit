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
        // to prevent stack too deep error
        bytes memory data_ = Address.functionStaticCall(
            positionManager,
            abi.encodeWithSelector(INonfungiblePositionManager.positions.selector, tokenId)
        );
        bytes32[12] memory values_;
        unchecked {
            for (uint256 offset = 0; offset < 0x180; offset += 0x20) {
                bytes32 value_;
                assembly {
                    value_ := mload(add(add(data_, 0x20), offset))
                }
                values_[offset >> 5] = value_;
            }
        }
        position.nonce = uint96(uint256(values_[0]));
        position.operator = address(uint160(uint256(values_[1])));
        position.token0 = address(uint160(uint256(values_[2])));
        position.token1 = address(uint160(uint256(values_[3])));
        position.tickSpacing = int24(int256(uint256(values_[4])));
        position.tickLower = int24(int256(uint256(values_[5])));
        position.tickUpper = int24(int256(uint256(values_[6])));
        position.liquidity = uint128(uint256(values_[7]));
        position.feeGrowthInside0LastX128 = uint256(values_[8]);
        position.feeGrowthInside1LastX128 = uint256(values_[9]);
        position.tokensOwed0 = uint128(uint256(values_[10]));
        position.tokensOwed1 = uint128(uint256(values_[11]));
        position.tokenId = tokenId;
    }
}
