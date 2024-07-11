// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "src/interfaces/ICore.sol";
import "src/interfaces/external/velo/ICLPool.sol";
import "src/interfaces/external/velo/INonfungiblePositionManager.sol";
import "src/interfaces/modules/strategies/IPulseStrategyModule.sol";

import "src/bots/PulseVeloBotLazy.sol";

contract PulseVeloBot is Script {
    using SafeERC20 for IERC20;

    ICore public immutable core =
        ICore(0xB4AbEf6f42bA5F89Dc060f4372642A1C700b22bC);

    address public pulseVeloBotAddress =
        0xd5823002f1D34e68B47AAce5551d6A76E6379d5c;
    PulseVeloBotLazy public bot = PulseVeloBotLazy(pulseVeloBotAddress);

    uint256 immutable operatorPrivateKey = vm.envUint("OPERATOR_PRIVATE_KEY");
    address immutable operatorAddress = vm.addr(operatorPrivateKey);

    /// @dev script is able to rebalance bulk of positions, but it is recommended to rebalance one by one
    function run() public {
        /* bot = new PulseVeloBotLazy(
            0x416b433906b1B72FA758e166e239c43d68dC6F29, // NonfungiblePositionManager
            address(core) // Core
        );*/
        vm.startBroadcast(operatorPrivateKey);

        IPulseVeloBotLazy.SwapParams[] memory swapParams = _readTransactions();

        for (uint i = 0; i < swapParams.length; i++) {
            uint256 managedPositionId = swapParams[i].positionId;

            bool needRebalance = bot.needRebalancePosition(managedPositionId);
            if (needRebalance) {
                console2.log(
                    swapParams[i].router,
                    swapParams[i].tokenIn,
                    swapParams[i].tokenOut,
                    swapParams[i].amountIn
                );

                uint256[] memory ids = new uint256[](1);
                ids[0] = managedPositionId;
                IPulseVeloBotLazy.SwapParams[]
                    memory swapParam = new IPulseVeloBotLazy.SwapParams[](0);
                if (
                    swapParams[i].amountIn > 0 &&
                    swapParams[i].tokenIn != address(0) &&
                    swapParams[i].tokenOut != address(0) &&
                    swapParams[i].router != address(0)
                ) {
                    swapParam = new IPulseVeloBotLazy.SwapParams[](1);
                    swapParam[0] = swapParams[i];
                }
                try
                    core.rebalance(
                        ICore.RebalanceParams({
                            ids: ids,
                            callback: pulseVeloBotAddress,
                            data: abi.encode(swapParam)
                        })
                    )
                {
                    console2.log(
                        "rebalance is successfull for ",
                        managedPositionId
                    );
                } catch {
                    console2.log("rebalance is failed for ", managedPositionId);
                }
            }
        }

        vm.stopBroadcast();
    }

    function _readTransactions()
        private
        view
        returns (IPulseVeloBotLazy.SwapParams[] memory swapParams)
    {
        string
            memory path = "src/scripts/deploy/optimism/pulseVeloBotLazySwapData.json";
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        swapParams = abi.decode(data, (IPulseVeloBotLazy.SwapParams[]));
    }
}
