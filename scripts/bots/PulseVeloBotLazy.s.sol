// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../test/Imports.sol";

contract PulseVeloBot is Script {
    using SafeERC20 for IERC20;

    ICore public immutable core = ICore(0xd17613D91150a2345eCe9598D055C7197A1f5A71);

    address public pulseVeloBotAddress = 0xa809DA0D3fa492A75BA1c8b11601A382a43457cC;
    PulseVeloBotLazy public bot = PulseVeloBotLazy(pulseVeloBotAddress);

    uint256 immutable operatorPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address immutable operatorAddress = vm.addr(operatorPrivateKey);

    /// @dev script is able to rebalance bulk of positions, but it is recommended to rebalance one by one
    function run() public {
        vm.startBroadcast(operatorPrivateKey);

        IPulseVeloBotLazy.SwapParams memory swapParam = _readTransaction();
        address pool = swapParam.pool;

        bool needRebalance = bot.needRebalancePosition(pool);
        if (needRebalance) {
            console2.log(
                swapParam.router, swapParam.tokenIn, swapParam.tokenOut, swapParam.amountIn
            );

            uint256[] memory ids = new uint256[](1);
            (ids[0],) = bot.poolManagedPositionInfo(pool);
            IPulseVeloBotLazy.SwapParams[] memory swapParams = new IPulseVeloBotLazy.SwapParams[](0);
            if (
                swapParam.amountIn > 0 && swapParam.tokenIn != address(0)
                    && swapParam.tokenOut != address(0) && swapParam.router != address(0)
            ) {
                swapParams = new IPulseVeloBotLazy.SwapParams[](1);
                swapParams[0] = swapParam;
            }
            try core.rebalance(
                ICore.RebalanceParams({
                    ids: ids,
                    callback: pulseVeloBotAddress,
                    data: abi.encode(swapParams)
                })
            ) {
                console2.log("rebalance is successfull for ", pool);
            } catch {
                console2.log("rebalance is failed for ", pool);
            }
        }

        vm.stopBroadcast();
    }

    function _readTransaction()
        private
        view
        returns (IPulseVeloBotLazy.SwapParams memory swapParams)
    {
        string memory path = "src/scripts/bots/pulseVeloBotLazySwapData.json";
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        swapParams = abi.decode(data, (IPulseVeloBotLazy.SwapParams));
    }
}
