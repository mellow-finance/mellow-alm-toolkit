// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.25;

import "./base/Constants.sol";

/// @dev id of pool (see src/scripts/deploy/[chain]/PoolParameters.sol)
uint256 constant POOL_ID = 3;

// forge script DepositWithdraw.s.sol --rpc-url --broadcast --slow
contract DepositWithdraw is Script, PoolParameters, Addresses {
    ICLPool immutable pool = ICLPool(parameters[POOL_ID].pool);
    INonfungiblePositionManager immutable nft =
        INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER);

    uint256 immutable userPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address immutable userAddress = vm.addr(userPrivateKey);
    LpWrapper public lpWrapper;

    function run() public {
        //vm.startBroadcast(userPrivateKey);
        vm.startPrank(userAddress);
        IVeloDeployFactory.PoolAddresses memory addr = deployFactory
            .poolToAddresses(address(pool));
        uint256 posId = core.getUserIds(addr.lpWrapper)[0];
        ICore.ManagedPositionInfo memory position = core.managedPositionAt(
            posId
        );
        (
            ,
            ,
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,

        ) = nft.positions(position.ammPositionIds[0]);
        (uint160 sqrtPriceX96, , , , , ) = pool.slot0();

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );

        console2.log(" LpWrapper: ", addr.lpWrapper);
        lpWrapper = LpWrapper(payable(addr.lpWrapper));

        console2.log("NFT id of LpWrapper: ", position.ammPositionIds[0]);
        console2.log("pool address of pos: ", position.pool);
        console2.log("      token0 symbol: ", ERC20(pool.token0()).name());
        console2.log("      token1 symbol: ", ERC20(pool.token1()).name());
        console2.log("  balance Lp before: ", lpWrapper.balanceOf(userAddress));
        console2.log("  total amount0 pos: ", amount0);
        console2.log("  total amount1 pos: ", amount1);
        console2.log(
            "  share % Lp before: ",
            (100 * lpWrapper.balanceOf(userAddress)) / lpWrapper.totalSupply()
        );

        deposit();
        withdraw();

        console2.log("   balance Lp after: ", lpWrapper.balanceOf(userAddress));
        console2.log(
            "   share % Lp after: ",
            (100 * lpWrapper.balanceOf(userAddress)) / lpWrapper.totalSupply()
        );

        //        vm.stopBroadcast();
    }

    function deposit() private {
        uint256 anount0Desired = IERC20(pool.token0()).balanceOf(userAddress) /
            2; // desired amount0
        uint256 anount1Desired = IERC20(pool.token1()).balanceOf(userAddress) /
            2; // desired amount1

        /// @dev give approves for actual amounts
        IERC20(pool.token0()).approve(address(lpWrapper), anount0Desired);
        IERC20(pool.token1()).approve(address(lpWrapper), anount1Desired);

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
