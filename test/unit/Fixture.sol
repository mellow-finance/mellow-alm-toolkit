// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Imports.sol";
import "scripts/deploy/Constants.sol";

contract VeloFarmMock {
    function distribute(uint256 amount) external {}

    function test() internal pure {}
}

contract VoterMock {
    function isAlive(address) external pure returns (bool) {
        return false;
    }

    function test() internal pure {}
}

contract GaugeMock {
    address public immutable pool;
    VoterMock public immutable voter;

    constructor(address pool_) {
        pool = pool_;
        voter = new VoterMock();
    }

    function test() internal pure {}
}

contract CLPoolMock {
    address public immutable token0;
    address public immutable token1;
    int24 public immutable tickSpacing;

    constructor(address token0_, address token1_, int24 tickSpacing_) {
        token0 = token0_;
        token1 = token1_;
        tickSpacing = tickSpacing_;
    }

    function test() internal pure {}
}

contract VeloDepositWithdrawModuleMock {
    using SafeERC20 for IERC20;

    INonfungiblePositionManager public immutable positionManager;
    bool private state_;
    uint256 public immutable specificValueRevert = 1234e5;

    constructor(INonfungiblePositionManager positionManager_) {
        positionManager = positionManager_;
    }

    function deposit(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1,
        address from,
        address token0,
        address token1
    ) external returns (uint256 actualAmount0, uint256 actualAmount1) {
        address this_ = address(this);
        if (amount0 != 0) {
            IERC20(token0).safeTransferFrom(from, this_, amount0);
            IERC20(token0).safeIncreaseAllowance(address(positionManager), amount0);
        }
        if (amount1 != 0) {
            IERC20(token1).safeTransferFrom(from, this_, amount1);
            IERC20(token1).safeIncreaseAllowance(address(positionManager), amount1);
        }
        (, actualAmount0, actualAmount1) = positionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint256).max
            })
        );
        if (actualAmount0 != amount0) {
            IERC20(token0).safeTransfer(from, amount0 - actualAmount0);
        }
        if (actualAmount1 != amount1) {
            IERC20(token1).safeTransfer(from, amount1 - actualAmount1);
        }

        if (amount0 == specificValueRevert) {
            state_ = true;
        } else {
            state_ = false;
        }

        assembly {
            let data := 42 // Set a value in memory, here we're using 42 as an example
            let resultPtr := mload(0x40) // Load the free memory pointer
            mstore(resultPtr, data) // Store the data at resultPtr

            let flagValue := sload(0)
            switch flagValue
            case 0 {
                // If flag is true, return 64 bytes
                return(resultPtr, 0x40)
            }
            default {
                // If flag is false, return 32 bytes
                return(resultPtr, 0x20)
            }
        }
    }

    function withdraw(uint256 tokenId, uint256 liquidity, address to)
        external
        returns (uint256 actualAmount0, uint256 actualAmount1)
    {
        positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: uint128(liquidity),
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint256).max
            })
        );
        (actualAmount0, actualAmount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: to,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        if (liquidity == specificValueRevert) {
            state_ = true;
        } else {
            state_ = false;
        }

        assembly {
            let data := 42 // Set a value in memory, here we're using 42 as an example
            let resultPtr := mload(0x40) // Load the free memory pointer
            mstore(resultPtr, data) // Store the data at resultPtr

            let flagValue := sload(0)
            switch flagValue
            case 0 {
                // If flag is true, return 64 bytes
                return(resultPtr, 0x40)
            }
            default {
                // If flag is false, return 32 bytes
                return(resultPtr, 0x20)
            }
        }
    }
}

contract Fixture is DeployScript, Test {
    using SafeERC20 for IERC20;

    ILpWrapper private wstethWeth1Wrapper;

    int24 public constant TICK_SPACING = 200;
    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D9 = 1e9;
    DeployScript.CoreDeploymentParams public params = Constants.getDeploymentParams();
    INonfungiblePositionManager public positionManager =
        INonfungiblePositionManager(params.positionManager);
    ICLFactory public factory = ICLFactory(positionManager.factory());

    function deployContracts() public returns (DeployScript.CoreDeployment memory contracts) {
        vm.startPrank(params.deployer);
        contracts = deployCore(params);
        vm.stopPrank();
    }

    function deployLpWrapper(ICLPool pool, DeployScript.CoreDeployment memory contracts)
        public
        returns (ILpWrapper lpWrapper, IVeloDeployFactory.DeployParams memory deployParams)
    {
        deployParams.slippageD9 = 1e6;
        deployParams.strategyParams = IPulseStrategyModule.StrategyParams({
            strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
            tickNeighborhood: 0, // Neighborhood of ticks to consider for rebalancing
            tickSpacing: pool.tickSpacing(), // tickSpacing of the corresponding amm pool
            width: pool.tickSpacing() * 10, // Width of the interval
            maxLiquidityRatioDeviationX96: 0 // The maximum allowed deviation of the liquidity ratio for lower position.
        });

        deployParams.securityParams =
            IVeloOracle.SecurityParams({lookback: 100, maxAge: 5 days, maxAllowedDelta: 10});

        deployParams.pool = pool;
        deployParams.maxAmount0 = 1 ether;
        deployParams.maxAmount1 = 1 ether;
        deployParams.initialTotalSupply = 1 ether;
        deployParams.totalSupplyLimit = 1000 ether;

        vm.startPrank(params.factoryOperator);
        deal(pool.token0(), address(contracts.deployFactory), 1 ether);
        deal(pool.token1(), address(contracts.deployFactory), 1 ether);
        lpWrapper = deployStrategy(contracts, deployParams);
        vm.stopPrank();
    }

    function mint(
        address token0,
        address token1,
        int24 tickSpacing,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        ICLPool pool,
        address recipient
    ) public returns (uint256) {
        vm.startPrank(recipient);

        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        (uint160 sqrtRatioX96,,,,,) = pool.slot0();

        INonfungiblePositionManager.MintParams memory mintParams;
        mintParams.tickLower = tickLower;
        mintParams.tickUpper = tickUpper;
        mintParams.recipient = recipient;
        mintParams.deadline = type(uint256).max;
        mintParams.token0 = token0;
        mintParams.token1 = token1;
        mintParams.tickSpacing = tickSpacing;
        {
            uint160 sqrtLowerRatioX96 = TickMath.getSqrtRatioAtTick(mintParams.tickLower);
            uint160 sqrtUpperRatioX96 = TickMath.getSqrtRatioAtTick(mintParams.tickUpper);
            (mintParams.amount0Desired, mintParams.amount1Desired) = LiquidityAmounts
                .getAmountsForLiquidity(sqrtRatioX96, sqrtLowerRatioX96, sqrtUpperRatioX96, liquidity);
            mintParams.amount0Desired += 1;
            mintParams.amount1Desired += 1;
        }
        deal(token0, recipient, mintParams.amount0Desired);
        deal(token1, recipient, mintParams.amount1Desired);
        IERC20(token0).safeIncreaseAllowance(address(positionManager), mintParams.amount0Desired);
        IERC20(token1).safeIncreaseAllowance(address(positionManager), mintParams.amount1Desired);

        (uint256 tokenId, uint128 actualLiquidity,,) = positionManager.mint(mintParams);
        require(
            (liquidity * 99) / 100 <= actualLiquidity && tokenId > 0, "Invalid params of minted nft"
        );
        vm.stopPrank();
        return tokenId;
    }

    function mint(
        address token0,
        address token1,
        int24 tickSpacing,
        int24 width,
        uint128 liquidity,
        ICLPool pool,
        address recipient
    ) public returns (uint256) {
        vm.startPrank(recipient);

        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        (uint160 sqrtRatioX96, int24 spotTick,,,,) = pool.slot0();
        {
            int24 remainder = spotTick % tickSpacing;
            if (remainder < 0) {
                remainder += tickSpacing;
            }
            spotTick -= remainder;
        }
        INonfungiblePositionManager.MintParams memory mintParams;
        mintParams.tickLower = spotTick - width / 2;
        mintParams.tickUpper = mintParams.tickLower + width;
        mintParams.recipient = recipient;
        mintParams.deadline = type(uint256).max;
        mintParams.token0 = token0;
        mintParams.token1 = token1;
        mintParams.tickSpacing = tickSpacing;
        {
            uint160 sqrtLowerRatioX96 = TickMath.getSqrtRatioAtTick(mintParams.tickLower);
            uint160 sqrtUpperRatioX96 = TickMath.getSqrtRatioAtTick(mintParams.tickUpper);
            (mintParams.amount0Desired, mintParams.amount1Desired) = LiquidityAmounts
                .getAmountsForLiquidity(sqrtRatioX96, sqrtLowerRatioX96, sqrtUpperRatioX96, liquidity);
            mintParams.amount0Desired += 1;
            mintParams.amount1Desired += 1;
        }
        deal(token0, recipient, mintParams.amount0Desired);
        deal(token1, recipient, mintParams.amount1Desired);
        IERC20(token0).safeIncreaseAllowance(address(positionManager), mintParams.amount0Desired);
        IERC20(token1).safeIncreaseAllowance(address(positionManager), mintParams.amount1Desired);

        (uint256 tokenId, uint128 actualLiquidity,,) = positionManager.mint(mintParams);
        require(
            (liquidity * 99) / 100 <= actualLiquidity && tokenId > 0, "Invalid params of minted nft"
        );
        vm.stopPrank();
        return tokenId;
    }

    function movePrice(ICLPool pool, uint160 sqrtPriceX96Target) public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        (uint160 sqrtPriceX96,,,,,) = pool.slot0();

        deal(token0, address(this), 10000000000000000000 ether);
        deal(token1, address(this), 10000000000000000000 ether);

        vm.startPrank(address(this));

        IERC20(token0).approve(address(this), type(uint256).max);
        IERC20(token1).approve(address(this), type(uint256).max);

        pool.swap(
            address(this),
            sqrtPriceX96Target < sqrtPriceX96,
            type(int256).max,
            sqrtPriceX96Target,
            abi.encode(address(this))
        );
        vm.stopPrank();
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data)
        external
    {
        ICLPool pool = ICLPool(msg.sender);

        address recipient = abi.decode(data, (address));
        if (amount0Delta > 0) {
            IERC20(pool.token0()).safeTransferFrom(recipient, address(pool), uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            IERC20(pool.token1()).safeTransferFrom(recipient, address(pool), uint256(amount1Delta));
        }
    }

    function addLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidity, ICLPool pool)
        public
    {
        (uint160 sqrtRatioX96,,,,,) = pool.slot0();
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity
        );
        amount0 *= 2;
        amount1 *= 2;
        deal(Constants.OPTIMISM_WETH, params.deployer, amount0);
        deal(Constants.OPTIMISM_OP, params.deployer, amount1);
        IERC20(Constants.OPTIMISM_WETH).safeIncreaseAllowance(address(positionManager), amount0);
        IERC20(Constants.OPTIMISM_OP).safeIncreaseAllowance(address(positionManager), amount1);
        positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: Constants.OPTIMISM_WETH,
                token1: Constants.OPTIMISM_OP,
                tickSpacing: TICK_SPACING,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: type(uint256).max,
                sqrtPriceX96: 0
            })
        );
    }

    function test() internal pure {}
}
