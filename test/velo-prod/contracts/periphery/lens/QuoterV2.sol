// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import "test/velo/contracts/core/libraries/SafeCast.sol";
import "test/velo/contracts/core/libraries/TickMath.sol";
// import "test/velo/contracts/core/libraries/TickBitmap.sol";
import "test/velo/contracts/core/interfaces/ICLPool.sol";
import "test/velo/contracts/core/interfaces/callback/ICLSwapCallback.sol";

import "../interfaces/IQuoterV2.sol";
import "../base/PeripheryImmutableState.sol";
import "../libraries/Path.sol";
import "../libraries/PoolAddress.sol";
import "../libraries/CallbackValidation.sol";
// import "../libraries/PoolTicksCounter.sol";

/// @title Provides quotes for swaps
/// @notice Allows getting the expected amount out or amount in for a given swap without executing the swap
/// @dev These functions are not gas efficient and should _not_ be called on chain. Instead, optimistically execute
/// the swap and check the amounts in the callback.
contract QuoterV2 is ICLSwapCallback, PeripheryImmutableState {
    using Path for bytes;
    using SafeCast for uint256;
    // using PoolTicksCounter for ICLPool;

    /// @dev Transient storage variable used to check a safety condition in exact output swaps.
    uint256 private amountOutCached;

    constructor(
        address _factory,
        address _WETH9
    ) PeripheryImmutableState(_factory, _WETH9) {}

    function getPool(
        address tokenA,
        address tokenB,
        int24 tickSpacing
    ) private view returns (ICLPool) {
        return
            ICLPool(
                PoolAddress.computeAddress(
                    factory,
                    PoolAddress.getPoolKey(tokenA, tokenB, tickSpacing)
                )
            );
    }

    /// @inheritdoc ICLSwapCallback
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory path
    ) external view override {
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported
        (address tokenIn, address tokenOut, int24 tickSpacing) = path
            .decodeFirstPool();
        CallbackValidation.verifyCallback(
            factory,
            tokenIn,
            tokenOut,
            tickSpacing
        );

        (
            bool isExactInput,
            uint256 amountToPay,
            uint256 amountReceived
        ) = amount0Delta > 0
                ? (
                    tokenIn < tokenOut,
                    uint256(amount0Delta),
                    uint256(-amount1Delta)
                )
                : (
                    tokenOut < tokenIn,
                    uint256(amount1Delta),
                    uint256(-amount0Delta)
                );

        ICLPool pool = getPool(tokenIn, tokenOut, tickSpacing);
        (uint160 sqrtPriceX96After, int24 tickAfter, , , , ) = pool.slot0();

        if (isExactInput) {
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountReceived)
                mstore(add(ptr, 0x20), sqrtPriceX96After)
                mstore(add(ptr, 0x40), tickAfter)
                revert(ptr, 96)
            }
        } else {
            // if the cache has been populated, ensure that the full output amount has been received
            if (amountOutCached != 0)
                require(amountReceived == amountOutCached);
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountToPay)
                mstore(add(ptr, 0x20), sqrtPriceX96After)
                mstore(add(ptr, 0x40), tickAfter)
                revert(ptr, 96)
            }
        }
    }

    /// @dev Parses a revert reason that should contain the numeric quote
    function parseRevertReason(
        bytes memory reason
    )
        private
        pure
        returns (uint256 amount, uint160 sqrtPriceX96After, int24 tickAfter)
    {
        if (reason.length != 96) {
            if (reason.length < 68) revert("Unexpected error");
            assembly {
                reason := add(reason, 0x04)
            }
            revert(abi.decode(reason, (string)));
        }
        return abi.decode(reason, (uint256, uint160, int24));
    }

    function handleRevert(
        bytes memory reason,
        ICLPool pool,
        uint256 gasEstimate
    )
        private
        view
        returns (
            uint256 amount,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256
        )
    {
        int24 tickBefore;
        int24 tickAfter;
        (, tickBefore, , , , ) = pool.slot0();
        (amount, sqrtPriceX96After, tickAfter) = parseRevertReason(reason);

        initializedTicksCrossed = 0;

        return (
            amount,
            sqrtPriceX96After,
            initializedTicksCrossed,
            gasEstimate
        );
    }

    function quoteExactInputSingle(
        IQuoterV2.QuoteExactInputSingleParams memory params
    )
        public
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        )
    {
        bool zeroForOne = params.tokenIn < params.tokenOut;
        ICLPool pool = getPool(
            params.tokenIn,
            params.tokenOut,
            params.tickSpacing
        );

        uint256 gasBefore = gasleft();
        try
            pool.swap(
                address(this), // address(0) might cause issues with some tokens
                zeroForOne,
                params.amountIn.toInt256(),
                params.sqrtPriceLimitX96 == 0
                    ? (
                        zeroForOne
                            ? TickMath.MIN_SQRT_RATIO + 1
                            : TickMath.MAX_SQRT_RATIO - 1
                    )
                    : params.sqrtPriceLimitX96,
                abi.encodePacked(
                    params.tokenIn,
                    params.tickSpacing,
                    params.tokenOut
                )
            )
        {} catch (bytes memory reason) {
            gasEstimate = gasBefore - gasleft();
            return handleRevert(reason, pool, gasEstimate);
        }
    }
}
