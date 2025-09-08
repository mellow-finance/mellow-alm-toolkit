// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Mock.sol";

import "forge-std/Test.sol";
import "src/interfaces/utils/ILpWrapper.sol";

contract SwapRouterMock is Test, Mock {
    using SafeERC20 for IERC20;
    using Math for uint256;

    mapping(bytes32 => uint256) public priceX96;
    uint256 public constant Q96 = 2 ** 96;

    event Swap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor() {}

    function setPriceX96(address tokenIn_, address tokenOut_, uint256 priceX96_) external {
        priceX96[keccak256(abi.encode(tokenIn_, tokenOut_))] = priceX96_;
    }

    function quote(address tokenIn, address tokenOut, uint256 amountIn)
        public
        view
        returns (uint256 amountOut)
    {
        bool zeroForOne = tokenIn < tokenOut;
        uint256 _priceX96 = zeroForOne
            ? priceX96[keccak256(abi.encode(tokenIn, tokenOut))]
            : priceX96[keccak256(abi.encode(tokenOut, tokenIn))];

        if (_priceX96 == 0) {
            revert("price not set");
        }

        if (zeroForOne) {
            amountOut = amountIn.mulDiv(_priceX96, Q96);
        } else {
            amountOut = amountIn.mulDiv(Q96, _priceX96);
        }
    }

    function swap(uint256 amountIn, address inputToken, address outputToken, address recipient)
        external
        returns (uint256 amountOut)
    {
        IERC20(inputToken).safeTransferFrom(msg.sender, address(this), amountIn);

        amountOut = quote(inputToken, outputToken, amountIn);

        deal(outputToken, address(this), amountOut);

        IERC20(outputToken).safeTransfer(recipient, amountOut);

        emit Swap(msg.sender, inputToken, outputToken, amountIn, amountOut);
    }
}
