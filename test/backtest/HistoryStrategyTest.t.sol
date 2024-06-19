// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import "../../test/velo-prod/integration/IntegrationTest.t.sol";
import  {Vm} from  "forge-std/Vm.sol";

struct Swap {
    int256 amount0;
    int256 amount1;
    uint256 block;
    uint128 liquidity;
    uint256 sqrtPriceX96;
    int24 tick;
    bytes32 txHash;
}

struct Mint {
    int256 amount0;
    int256 amount1;
    uint256 block;
    uint128 liquidity;
    int24 tickLower;
    int24 tickUpper;
    bytes32 txHash;
}

struct Burn {
    int256 amount0;
    int256 amount1;
    uint256 block;
    uint128 liquidity;
    address owner;
    int24 tickLower;
    int24 tickUpper;
    bytes32 txHash;
}

struct PoolTranactions {
    Burn[] burn;
    Mint[] mint;
    Swap[] swap;
}

contract HistoryTest is StdCheats {
    using SafeERC20 for ERC20;
    ICLFactory public factory = ICLFactory(Constants.VELO_FACTORY);
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bool isInit;
    ICLPool private pool;
    ERC20 private token0;
    ERC20 private token1;
    Swap swapTransaction;
    Mint mintTransaction;
    Burn burnTransaction;
    uint256 swapIndex;
    uint256 mintIndex;
    uint256 burnIndex;
    uint256 actualBlock;

    event call(address from);

    constructor() {
        pool = ICLPool(factory.getPool(Constants.WETH, Constants.OP, 200));
        token0 = ERC20(pool.token0());
        token1 = ERC20(pool.token1());
    }

    function _setUp() private {
        deal(address(token0), address(this), type(uint256).max / 2, false);
        deal(address(token1), address(this), type(uint256).max / 2, false);

        token0.approve(address(this), type(uint256).max);
        token1.approve(address(this), type(uint256).max);
        token0.approve(address(pool), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);
        
        isInit = true;
    }

    function _readTransactions(
        string memory path
    ) private view returns (PoolTranactions memory transactions) {
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        transactions = abi.decode(data, (PoolTranactions));
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        require(msg.sender == address(pool), "Unauthorized callback");
        address recipient = abi.decode(data, (address));
        if (amount0Delta > 0) {
            token0.safeTransferFrom(
                recipient,
                address(pool),
                uint256(amount0Delta)
            );
        }
        if (amount1Delta > 0) {
            token1.safeTransferFrom(
                recipient,
                address(pool),
                uint256(amount1Delta)
            );
        }
    }

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external {
        require(msg.sender == address(pool), "Unauthorized callback");
        address sender = abi.decode(data, (address));
        if (amount0Owed > 0) {
            token0.safeTransferFrom(sender, address(pool), amount0Owed);
        }
        if (amount1Owed > 0) {
            token1.safeTransferFrom(sender, address(pool), amount1Owed);
        }
    }

    function _swap(int256 amount0, int256 amount1) private {
        bool zeroForOne = amount0 > 0 ? true : false;
        int256 amountSpecified = zeroForOne ? amount0 : amount1;
        uint160 sqrtPriceLimitX96 = zeroForOne
            ? TickMath.MIN_SQRT_RATIO + 1
            : TickMath.MAX_SQRT_RATIO - 1;
        pool.swap(
            address(this),
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96,
            abi.encode(address(this))
        );
    }

    function _mint(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    ) private {
        // uint128 liquidityBefore = pool.liquidity();
        pool.mint(
            address(this),
            tickLower,
            tickUpper,
            liquidity,
            abi.encode(address(this))
        );
        //   console2.log(int256((int128(pool.liquidity()) - int128(liquidityBefore))));//, liquidity);
    }

    function _burn(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    ) private {
        try pool.burn(tickLower, tickUpper, liquidity) {} catch Error(
            string memory reason
        ) {
            console2.log(reason);
        }
    }

    function _getNextTransactionBlock()
        private
        view
        returns (uint256 nextBlock)
    {
        nextBlock = swapTransaction.block < mintTransaction.block
            ? swapTransaction.block
            : mintTransaction.block;
        nextBlock = burnTransaction.block < nextBlock
            ? burnTransaction.block
            : nextBlock;
    }

    function _simulateNextTransaction(
        PoolTranactions memory transactions
    ) private returns (bool isEnd) {
        actualBlock = _getNextTransactionBlock();
        if (actualBlock == type(uint256).max) {
            return true;
        }
        if (actualBlock == swapTransaction.block) {
            _swap(swapTransaction.amount0, swapTransaction.amount1);
            swapIndex++;
            if (swapIndex < transactions.swap.length) {
                swapTransaction = transactions.swap[swapIndex];
            } else {
                swapTransaction.block = type(uint256).max;
            }
        } else if (actualBlock == mintTransaction.block) {
            _mint(
                mintTransaction.liquidity,
                mintTransaction.tickLower,
                mintTransaction.tickUpper
            );
            mintIndex++;
            if (mintIndex < transactions.mint.length) {
                mintTransaction = transactions.mint[mintIndex];
            } else {
                mintTransaction.block = type(uint256).max;
            }
        } else if (actualBlock == burnTransaction.block) {
            _burn(
                burnTransaction.liquidity,
                burnTransaction.tickLower,
                burnTransaction.tickUpper
            );
            burnIndex++;
            if (burnIndex < transactions.burn.length) {
                burnTransaction = transactions.burn[burnIndex];
            } else {
                burnTransaction.block = type(uint256).max;
            }
        } else {
            return true;
        }
        return false;
    }

    /* function _init() private {
        string memory forkUrl = vm.envString("OPTIMISM_RPC");
        actualBlock = _getNextTransactionBlock();
        uint256 forkId = vm.createFork(forkUrl, actualBlock / 1000 - 1);
        vm.selectFork(forkId);
        _setUp();
        isInit = true;
    } */

    function testSimulateTransactions(string memory path) public {
        emit call(msg.sender);
        return;
        if (!isInit) {
            _setUp();
        }
        PoolTranactions memory transactions = _readTransactions(path);

        (, int24 tick, , , , ) = pool.slot0();
        console2.log(tick);
        console2.log(pool.liquidity());
        while (!_simulateNextTransaction(transactions)) {}
        (, tick, , , , ) = pool.slot0();
        console2.log(tick);
        console2.log(pool.liquidity());
    }
}
