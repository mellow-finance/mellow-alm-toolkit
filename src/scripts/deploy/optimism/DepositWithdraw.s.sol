// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "src/utils/LpWrapper.sol";
import "src/utils/VeloDeployFactory.sol";
import "src/interfaces/external/velo/ICLPool.sol";

/// @dev =================== STAGE THREE =====================
/// @dev address of @param LP_WRAPPER_ADDRESS is known after deploy the second STAGE
/// @dev it should be used after deploy strategy for @param POOL_ADDRESS

address constant POOL_ADDRESS = 0x8Ac2f9daC7a2852D44F3C09634444d533E4C078e;

IVeloDeployFactory constant veloDeployFactory = IVeloDeployFactory(0x2B4005CEA7acfa1285034d4887E761fD1a4c7C7D);

// forge script DepositWithdraw.s.sol --rpc-url https://opt-mainnet.g.alchemy.com/v2/oPPlIjgGxGvQx3qKFOhzbhvZPUsm6amk --broadcast --slow
contract DepositWithdraw is Script {
    uint256 immutable userPrivateKey = vm.envUint("USER_PRIVATE_KEY");
    address immutable userAddress = vm.addr(userPrivateKey);
    ILpWrapper public lpWrapper;

    function run() public {

        vm.startBroadcast(userPrivateKey);
        IVeloDeployFactory.PoolAddresses memory addr = veloDeployFactory.poolToAddresses(POOL_ADDRESS);
        lpWrapper = ILpWrapper(addr.lpWrapper);

        deposit();
        withdraw();

        vm.stopBroadcast();
    }

    function deposit() private {

        ICLPool pool = ICLPool(POOL_ADDRESS);

        uint256 anount0Desired = IERC20(pool.token0()).balanceOf(userAddress); // desired amount0
        uint256 anount1Desired = IERC20(pool.token1()).balanceOf(userAddress); // desired amount1

        /// @dev give approves for actual amounts
        IERC20(pool.token0()).approve(
            address(lpWrapper),
            anount0Desired
        );
        IERC20(pool.token1()).approve(
            address(lpWrapper),
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
    }

    function withdraw() private {

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
