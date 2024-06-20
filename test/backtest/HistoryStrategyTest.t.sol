// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import "../../test/velo-prod/integration/IntegrationTest.t.sol";
import "../../test/velo-prod/contracts/periphery/interfaces/external/IWETH9.sol";

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

struct CommonTransaction {
    uint256 typeTransaction; // 0 - swap, 1 - mint, 2 - burn
    int256 amount0;
    int256 amount1;
    uint256 block;
    uint128 liquidity;
    int24 tickLower;
    int24 tickUpper;
    bytes32 txHash;
}

struct PoolTranactions {
    Burn[] burn;
    Mint[] mint;
    Swap[] swap;
}

contract HistoryTest is Test {
    using SafeERC20 for ERC20;
    ICLFactory public factory = ICLFactory(Constants.VELO_FACTORY);
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
    event Balances(uint256 amount0, uint256 amount1);
    event poolToken(address pool, address token0, address token1);
    event Transaction(
        uint256 tp,
        int256 amount0,
        int256 amount1,
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    );

    constructor() {
        pool = ICLPool(factory.getPool(Constants.WETH, Constants.OP, 200));
        token0 = ERC20(pool.token0());
        token1 = ERC20(pool.token1());
        emit poolToken(address(pool), address(token0), address(token1));
    }

    function setUp() public {
        if (address(this).balance > 0) {
            IWETH9(Constants.WETH).deposit{value: address(this).balance}();
        }
        token0.approve(address(this), type(uint256).max);
        token1.approve(address(this), type(uint256).max);
        token0.approve(address(pool), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);

        emit Balances(
            IERC20(Constants.WETH).balanceOf(address(this)),
            IERC20(Constants.OP).balanceOf(address(this))
        );

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

    function _swap(
        int256 amount0,
        int256 amount1
    ) private returns (bool result) {
        bool zeroForOne = amount0 > 0 ? true : false;
        int256 amountSpecified = zeroForOne ? amount0 : amount1;
        uint160 sqrtPriceLimitX96 = zeroForOne
            ? TickMath.MIN_SQRT_RATIO + 1
            : TickMath.MAX_SQRT_RATIO - 1;
        result = true;
        try
            pool.swap(
                address(this),
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96,
                abi.encode(address(this))
            )
        {} catch {
            result = false;
        }
        return result;
    }

    function _mint(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    ) private returns (bool result) {
        result = true;
        try
            pool.mint(
                address(this),
                tickLower,
                tickUpper,
                liquidity,
                abi.encode(address(this))
            )
        {} catch {
            result = false;
        }
        return result;
    }

    function _burn(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    ) private returns (bool result) {
        result = true;
        try pool.burn(tickLower, tickUpper, liquidity) {} catch {
            result = false;
        }
        return result;
    }

    function poolTransaction(
        CommonTransaction[] memory transactions
    ) public returns (uint256 successfulTransactions) {
        CommonTransaction memory transaction;
        for (uint256 i = 0; i < transactions.length; i++) {
            transaction = transactions[i];
            if (transaction.typeTransaction == 1) {
                if (_swap(transaction.amount0, transaction.amount1)) {
                    successfulTransactions++;
                }
            } else if (transaction.typeTransaction == 2) {
                if (
                    _mint(
                        transaction.liquidity,
                        transaction.tickLower,
                        transaction.tickUpper
                    )
                ) {
                    successfulTransactions++;
                }
            } else if (transaction.typeTransaction == 3) {
                if (
                    _burn(
                        transaction.liquidity,
                        transaction.tickLower,
                        transaction.tickUpper
                    )
                ) {
                    successfulTransactions++;
                }
            }
        }
        return successfulTransactions;
    }
}
