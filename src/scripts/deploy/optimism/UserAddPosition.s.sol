// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "src/utils/LpWrapper.sol";
import "src/interfaces/external/velo/ICLPool.sol";

/// @dev =================== STAGE THREE =====================
/// @dev address of @param LP_WRAPPER_ADDRESS is known after deploy the second STAGE
/// @dev it should be used after deploy strategy for @param POOL_ADDRESS

/*
  Actual Liqudity:  262144000 TEST-TEST-TEST-TEST-TEST-TEST-TEST-TEST-TEST
   =======     POOL  0x9dA9D8dCdAC3Cab214d2bd241C3835B90aA8fFdE     ========
            tokenId: 19314
          lpWrapper: 0x79A3bCadf27A57AEe5cB1FBCe48a0CFb6857F6D0
      synthetixFarm: 0x2570A45425F338bB57176A7FD2BcCB2205ea70f3
*/

address constant POOL_ADDRESS = 0x9dA9D8dCdAC3Cab214d2bd241C3835B90aA8fFdE;
address payable constant LP_WRAPPER_ADDRESS = payable(
    0x79A3bCadf27A57AEe5cB1FBCe48a0CFb6857F6D0
);

contract Deploy is Script, Test {
    uint256 immutable userPrivateKey = vm.envUint("USER_PRIVATE_KEY");
    address immutable userAddress = vm.addr(userPrivateKey);

    function run() public {
        LpWrapper lpWrapper = LpWrapper(LP_WRAPPER_ADDRESS);
        ICLPool pool = ICLPool(POOL_ADDRESS);

        vm.startBroadcast(userPrivateKey);

        uint256 anount0Desired = IERC20(pool.token0()).balanceOf(userAddress)/10; // desired amount0
        uint256 anount1Desired = IERC20(pool.token1()).balanceOf(userAddress)/10; // desired amount1

        /// @dev give approves for actual amounts
        IERC20(pool.token0()).approve(
            address(LP_WRAPPER_ADDRESS),
            anount0Desired
        );
        IERC20(pool.token1()).approve(
            address(LP_WRAPPER_ADDRESS),
            anount1Desired
        );

        /// @dev deposit desired amounts
        (
            uint256 actualAmount0,
            uint256 actualAmount1,
            uint256 lpAmount
        ) = lpWrapper.deposit(
                anount0Desired,
                anount1Desired,
                0,
                userAddress, // recipient of lpTokens
                type(uint256).max
            );

        console2.log(" ================== deposit info ==================== ");
        console2.log(" depositor: ", userAddress);
        console2.log("   amount0: ", actualAmount0);
        console2.log("   amount1: ", actualAmount1);
        console2.log("  lpAmount: ", lpAmount);

        /// @dev withdraw whole assets
        (uint256 amount0, uint256 amount1, uint256 actualLpAmount) = lpWrapper
            .withdraw(
                type(uint256).max, // it will be truncated to the actual owned lpTokens
                0,
                0,
                userAddress,
                type(uint256).max
            );

        console2.log(" ================== withdraw info ==================== ");
        console2.log("withdrawer: ", userAddress);
        console2.log("   amount0: ", amount0);
        console2.log("   amount1: ", amount1);
        console2.log("  lpAmount: ", actualLpAmount);
    }
}
