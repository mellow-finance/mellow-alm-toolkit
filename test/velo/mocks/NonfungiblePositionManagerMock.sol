// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Mock.sol";

contract NonfungiblePositionManagerMock is Mock {
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

    address positionManager;

    constructor(address _positionManager) {
        positionManager = _positionManager;
    }

    function setNonce(uint96 _nonce) external {
        nonce = _nonce;
    }

    function setOperator(address _operator) external {
        operator = _operator;
    }

    function setToken0(address _token0) external {
        token0 = _token0;
    }

    function setToken1(address _token1) external {
        token1 = _token1;
    }

    function setTickSpacing(int24 _tickSpacing) external {
        tickSpacing = _tickSpacing;
    }

    function setTickLower(int24 _tickLower) external {
        tickLower = _tickLower;
    }

    function setTickUpper(int24 _tickUpper) external {
        tickUpper = _tickUpper;
    }

    function setLiquidity(uint128 _liquidity) external {
        liquidity = _liquidity;
    }

    function setFeeGrowthInside0LastX128(uint256 _feeGrowthInside0LastX128) external {
        feeGrowthInside0LastX128 = _feeGrowthInside0LastX128;
    }

    function setFeeGrowthInside1LastX128(uint256 _feeGrowthInside1LastX128) external {
        feeGrowthInside1LastX128 = _feeGrowthInside1LastX128;
    }

    function setTokensOwed0(uint128 _tokensOwed0) external {
        tokensOwed0 = _tokensOwed0;
    }

    function setTokensOwed1(uint128 _tokensOwed1) external {
        tokensOwed1 = _tokensOwed1;
    }

    function factory() external view returns (address) {
        (bool success, bytes memory result) =
            positionManager.staticcall(abi.encodeWithSelector(0xc45a0155)); // factory()
        require(success, "factory call failed");
        return abi.decode(result, (address));
    }

    function positions(uint256 /* tokenId */ )
        external
        view
        returns (
            uint96,
            address,
            address,
            address,
            int24,
            int24,
            int24,
            uint128,
            uint256,
            uint256,
            uint128,
            uint128
        )
    {
        return (
            nonce,
            operator,
            token0,
            token1,
            tickSpacing,
            tickLower,
            tickUpper,
            liquidity,
            feeGrowthInside0LastX128,
            feeGrowthInside1LastX128,
            tokensOwed0,
            tokensOwed1
        );
    }
}
