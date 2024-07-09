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
    ----test----test----test----test----test----test----test----test----test----test--
    Actual Liqudity: 1024000
               POOL: 0xBafB44286c5EcaFb1F26A6649E15C49Fc1c49882
            tokenId: 24648
          lpWrapper: 0x1C33aC297a7DBa18440E78bF7C161cE6687CD0FF
      synthetixFarm: 0xD01314A62a9C204613A7834fBE3f9CF55cFE0e59
*/

address constant POOL_ADDRESS = 0xBafB44286c5EcaFb1F26A6649E15C49Fc1c49882;
address payable constant LP_WRAPPER_ADDRESS = payable(
    0x1C33aC297a7DBa18440E78bF7C161cE6687CD0FF
);

contract Deploy is Script, Test {
    uint256 immutable userPrivateKey = vm.envUint("USER_PRIVATE_KEY");
    address immutable userAddress = vm.addr(userPrivateKey);

    function run() public {
        LpWrapper lpWrapper = LpWrapper(LP_WRAPPER_ADDRESS);
        ICLPool pool = ICLPool(POOL_ADDRESS);

        vm.startBroadcast(userPrivateKey);

        uint256 anount0Desired = IERC20(pool.token0()).balanceOf(userAddress) /
            1; // desired amount0
        uint256 anount1Desired = IERC20(pool.token1()).balanceOf(userAddress) /
            1; // desired amount1

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
