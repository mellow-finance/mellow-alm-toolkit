// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import "../../test/velo-prod/integration/IntegrationTest.t.sol";
import "../../test/velo-prod/contracts/periphery/interfaces/external/IWETH9.sol";
import "../../src/modules/strategies/PulseStrategyModule.sol";
import "../../src/bots/PulseVeloBot.sol";

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

contract HistoryTest is Test {
    using SafeERC20 for ERC20;
    uint32 public immutable MELLOW_PROTOCOL_FEE = 1e8;
    address public immutable MELLOW_PROTOCOL_TREASURY =
        address(bytes20((keccak256("treasury"))));

    ICLFactory public immutable factory = ICLFactory(Constants.VELO_FACTORY);
    INonfungiblePositionManager public immutable manager =
        INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER);
    IVeloOracle private oracle;
    IPulseStrategyModule private strategyModule;
    IVeloDeployFactoryHelper private velotrDeployFactoryHelper;
    IVeloAmmModule private ammModule;
    IVeloDepositWithdrawModule private veloDepositWithdrawModule;
    ICore private core;
    VeloDeployFactory private veloDeployFactory;
    IPulseVeloBot private pulseVeloBot;

    IPulseStrategyModule.StrategyParams public strategyParams;
    ICLPool private pool;
    ERC20 private token0;
    ERC20 private token1;
    uint256 public tokenId;

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

    constructor(
        address oracle_,
        address strategyModule_,
        address velotrDeployFactoryHelper_,
        address ammModule_,
        address veloDepositWithdrawModule_,
        address core_,
        address pulseVeloBot_
    ) {
        oracle = IVeloOracle(oracle_);
        strategyModule = IPulseStrategyModule(strategyModule_);
        velotrDeployFactoryHelper = IVeloDeployFactoryHelper(
            velotrDeployFactoryHelper_
        );
        ammModule = IVeloAmmModule(ammModule_);
        veloDepositWithdrawModule = IVeloDepositWithdrawModule(
            veloDepositWithdrawModule_
        );
        core = new Core(ammModule, strategyModule, oracle, address(this));//ICore(core_); // 
        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    feeD9: 1e8,
                    treasury: Constants.PROTOCOL_TREASURY
                })
            )
        );
        core.setOperatorFlag(false);
        veloDeployFactory = new VeloDeployFactory(address(this), core, veloDepositWithdrawModule, velotrDeployFactoryHelper);
        pulseVeloBot = IPulseVeloBot(pulseVeloBot_);
        pool = ICLPool(factory.getPool(Constants.WETH, Constants.OP, 200));
        pool.increaseObservationCardinalityNext(100);
        token0 = ERC20(pool.token0());
        token1 = ERC20(pool.token1());
        emit poolToken(address(pool), address(token0), address(token1));
    }

    function setUpStrategy() public {
        if (tokenId != 0) {
            revert("strategy is alredy set up");
        }
        init();
        int24 tickSpacing = pool.tickSpacing();
        strategyParams.strategyType = IPulseStrategyModule
            .StrategyType
            .LazySyncing;
        strategyParams.tickNeighborhood = 0;
        strategyParams.tickSpacing = tickSpacing;
        strategyParams.width = tickSpacing;
        strategyModule.validateStrategyParams(abi.encode(strategyParams));

        (uint160 sqrtPriceX96, int24 tick, , , , ) = pool.slot0();
        int24 tickLower = tickSpacing * (tick / tickSpacing);
        int24 tickUpper = tickLower + tickSpacing;
        uint128 liquidity = 4188 * 10 ** 18;
        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity + 1
            );

        (tokenId, , , ) = manager.mint(
            INonfungiblePositionManager.MintParams({
                token0: pool.token0(),
                token1: pool.token1(),
                tickLower: tickLower,
                tickUpper: tickUpper,
                tickSpacing: pool.tickSpacing(),
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp,
                sqrtPriceX96: 0
            })
        );
        manager.approve(address(veloDeployFactory), tokenId);

        veloDeployFactory.updateMutableParams(
            IVeloDeployFactory.MutableParams({
                lpWrapperAdmin: address(this),
                lpWrapperManager: address(0),
                farmOwner: address(this),
                farmOperator: address(this),
                minInitialLiquidity: 10 ** 18
            })
        );
        
        veloDeployFactory.createStrategy(
            IVeloDeployFactory.DeployParams({
                tickNeighborhood: 0,
                slippageD9: 1e8,
                tokenId: tokenId,
                securityParams: abi.encode(
                    IVeloOracle.SecurityParams({
                        lookback: 1,
                        maxAge: 1 days,
                        maxAllowedDelta: 1000
                    })
                ),
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing
            })
        );
    }

    function init() public {
        if (address(this).balance > 0) {
            IWETH9(Constants.WETH).deposit{value: address(this).balance}();
        }
        token0.approve(address(this), type(uint256).max);
        token0.approve(address(pool), type(uint256).max);
        token0.approve(address(manager), type(uint256).max);
        token1.approve(address(this), type(uint256).max);
        token1.approve(address(pool), type(uint256).max);
        token1.approve(address(manager), type(uint256).max);
        emit Balances(
            IERC20(Constants.WETH).balanceOf(address(this)),
            IERC20(Constants.OP).balanceOf(address(this))
        );
    }

    function testInitPosition() public {
        deal(address(token0), address(this), 10 ** 24);
        deal(address(token1), address(this), 10 ** 24);
        setUpStrategy();
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

    function checkPosition() public {
        ICore.ManagedPositionInfo memory info;
        info.slippageD9 = 10 ** 8;
        info.owner = address(this);
        info.pool = address(pool);

        (
            bool isRebalanceRequired,
            ICore.TargetPositionInfo memory target
        ) = strategyModule.getTargets(info, ammModule, oracle);
        //pulseVeloBot.call
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
                    _rebalance();
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

    function _rebalance() private {
        core.rebalance(
            ICore.RebalanceParams({
                ids: new uint256[](1),
                callback: address(pulseVeloBot),
                data: abi.encode(new ISwapRouter.ExactInputSingleParams[](0))
            })
        );
        ICore.ManagedPositionInfo memory position = core.managedPositionAt(0);
        tokenId = position.ammPositionIds[0];
        //tokenId = position.ammPositionIds[0];
        //require(tokenId != 0, "no position rebalanced");
        //return position.ammPositionIds[0];
    }
}
