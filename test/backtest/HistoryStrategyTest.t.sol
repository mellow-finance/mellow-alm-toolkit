// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import "../../test/velo-prod/integration/IntegrationTest.t.sol";

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

contract HistoryTest is Integration {
    using SafeERC20 for ERC20;
    address public constant USER = address(bytes20(keccak256("USER")));
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

    function setUp() external override {
        pool = ICLPool(factory.getPool(Constants.WETH, Constants.OP, 200));
        token0 = ERC20(pool.token0());
        token1 = ERC20(pool.token1());
    }

    function _setUp() private {
        deal(address(token0), address(this), type(uint256).max, false);
        deal(address(token1), address(this), type(uint256).max, false);

        token0.approve(address(this), type(uint256).max);
        token1.approve(address(this), type(uint256).max);
        token0.approve(address(pool), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);
    }

    function _readTransactions()
        private
        returns (PoolTranactions memory transactions)
    {
        string
            memory path = "test/backtest/data/10/0x1e60272caDcFb575247a666c11DBEA146299A2c4_transactions.json";
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        transactions = abi.decode(data, (PoolTranactions));

        swapTransaction = transactions.swap[0];
        mintTransaction = transactions.mint[0];
        burnTransaction = transactions.burn[0];
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
        pool.mint(
            address(this),
            tickLower,
            tickUpper,
            liquidity,
            abi.encode(address(this))
        );
    }

    function _burn(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        address owner
    ) private {
        vm.startPrank(owner);
        pool.burn(tickLower, tickUpper, liquidity);
        vm.stopPrank();
    }

    function _getNextTransactionBlock() private view returns (uint256 nextBlock){
        nextBlock = swapTransaction.block < mintTransaction.block ? swapTransaction.block : mintTransaction.block;
        nextBlock = burnTransaction.block < nextBlock ? burnTransaction.block : nextBlock;
    }

    function _simulateNextTransaction(PoolTranactions memory transactions) private returns (bool isEnd)  {
        actualBlock = _getNextTransactionBlock();
        if (actualBlock == swapTransaction.block && swapIndex < transactions.swap.length) {
            _swap(swapTransaction.amount0, swapTransaction.amount1);
            swapTransaction = transactions.swap[swapIndex++];
        } else if (actualBlock == mintTransaction.block && mintIndex < transactions.mint.length) {
            //_mint(mintTransaction.liquidity, mintTransaction.tickLower, mintTransaction.tickUpper);
            mintTransaction = transactions.mint[mintIndex++];
        } else if (actualBlock == burnTransaction.block && burnIndex < transactions.burn.length) {
            //_burn(burnTransaction.liquidity, burnTransaction.tickLower, burnTransaction.tickUpper, burnTransaction.owner);
            burnTransaction = transactions.burn[burnIndex++];
        } else {
            return true;
        }
        return false;
    }

    function testSimulateTransactions() public {
        PoolTranactions memory transactions = _readTransactions();
        
        string memory forkUrl = vm.envString("OPTIMISM_RPC");
        actualBlock = _getNextTransactionBlock();
        uint256 forkId = vm.createFork(forkUrl, actualBlock-1);
        vm.selectFork(forkId);
        _setUp();
        //_burn(burnTransaction.liquidity, burnTransaction.tickLower, burnTransaction.tickUpper, burnTransaction.owner);
        //return;
        while (!_simulateNextTransaction(transactions)) {
            (,int24 tick,,,,) = pool.slot0();
            console2.log(tick);
        }
    }
}
