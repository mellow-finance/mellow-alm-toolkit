// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "src/modules/terminal/TerminalAmmModule.sol";
import "test/RandomLib.sol";

contract Swapper is Test {
    using RandomLib for RandomLib.Storage;

    address private immutable token0;
    address private immutable token1;
    address private immutable pool;
    address private immutable ammModule;
    RandomLib.Storage internal rnd;

    constructor(address pool_, address ammModule_) {
        pool = pool_;
        ammModule = ammModule_;
        token0 = ITerminalPool(pool_).token0();
        token1 = ITerminalPool(pool_).token1();
    }

    function randomSwap() external {
        bool zeroForOne = rnd.randBool();
        uint256 amountInt = rnd.randInt(
            1,
            ((zeroForOne ? IERC20(token0).balanceOf(pool) : IERC20(token1).balanceOf(pool)) / 10)
                + 1
        );
        address tokenIn = address(zeroForOne ? token0 : token1);

        deal(tokenIn, address(this), amountInt);
        Address.functionDelegateCall(
            address(ammModule),
            abi.encodeWithSelector(IAmmModule.swapOnPool.selector, pool, zeroForOne, amountInt)
        );
        deal(tokenIn, address(this), 0);
    }

    fallback() external {
        Address.functionDelegateCall(
            address(ammModule),
            abi.encodeWithSelector(
                IAmmModule.poolCallback.selector, msg.sender, msg.sig, msg.data[4:]
            )
        );
    }
}
