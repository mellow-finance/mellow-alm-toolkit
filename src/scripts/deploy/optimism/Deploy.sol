// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "forge-std/Vm.sol";

import "@synthetix/contracts/StakingRewards.sol";

import "../../../interfaces/external/velo/ISwapRouter.sol";

import "../../../Core.sol";
import "../../../utils/VeloDeployFactory.sol";
import "../../../utils/VeloDeployFactoryHelper.sol";

import "../../../modules/velo/VeloAmmModule.sol";
import "../../../modules/velo/VeloDepositWithdrawModule.sol";

import "../../../modules/strategies/PulseStrategyModule.sol";

import "../../../oracles/VeloOracle.sol";

contract Deploy is Script {
    // constants:
    address public constant QUOTER_V2 =
        0xA2DEcF05c16537C702779083Fe067e308463CE45;
    address public constant SWAP_ROUTER =
        0x5F9a4bb5d3b0c5e233Ee3cB35701077504a6F0eb;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant OP = 0x4200000000000000000000000000000000000042;
    address public constant VELO = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;

    address public constant VELO_DEPLOY_FACTORY_ADMIN =
        address(bytes20(keccak256("VELO_DEPLOY_FACTORY_ADMIN")));
    address public constant VELO_DEPLOY_FACTORY_OPERATOR =
        address(bytes20(keccak256("VELO_DEPLOY_FACTORY_OPERATOR")));
    address public constant CORE_ADMIN =
        address(bytes20(keccak256("CORE_ADMIN")));
    address public constant CORE_OPERATOR =
        address(bytes20(keccak256("CORE_OPERATOR")));
    address public constant MELLOW_PROTOCOL_TREASURY =
        address(bytes20(keccak256("MELLOW_PROTOCOL_TREASURY")));
    address public constant WRAPPER_ADMIN =
        address(bytes20(keccak256("WRAPPER_ADMIN")));
    address public constant FARM_OWNER =
        address(bytes20(keccak256("FARM_OWNER")));
    address public constant FARM_OPERATOR =
        address(bytes20(keccak256("FARM_OPERATOR")));
    uint32 public constant MELLOW_PROTOCOL_FEE = 1e8;
    address public constant DEPOSITOR =
        address(bytes20(keccak256("DEPOSITOR")));
    address public constant USER = address(bytes20(keccak256("USER")));

    INonfungiblePositionManager public positionManager =
        INonfungiblePositionManager(0xbB5DFE1380333CEE4c2EeBd7202c80dE2256AdF4);
    ICLFactory public factory = ICLFactory(positionManager.factory());
    ISwapRouter public swapRouter = ISwapRouter(SWAP_ROUTER);

    VeloOracle public oracle;
    VeloAmmModule public ammModule;
    VeloDepositWithdrawModule public dwModule;
    PulseStrategyModule public strategyModule;
    Core public core;
    VeloDeployFactory public deployFactory;
    VeloDeployFactoryHelper public deployFactoryHelper;

    function _deployContract() private {
        ammModule = new VeloAmmModule(positionManager);
        dwModule = new VeloDepositWithdrawModule(positionManager);
        strategyModule = new PulseStrategyModule();
        oracle = new VeloOracle();
        core = new Core(ammModule, strategyModule, oracle, CORE_ADMIN);
        vm.startPrank(CORE_ADMIN);
        core.grantRole(core.ADMIN_DELEGATE_ROLE(), CORE_ADMIN);
        core.grantRole(core.OPERATOR(), CORE_OPERATOR);
        vm.stopPrank();

        deployFactoryHelper = new VeloDeployFactoryHelper();
        deployFactory = new VeloDeployFactory(
            VELO_DEPLOY_FACTORY_ADMIN,
            core,
            dwModule,
            deployFactoryHelper
        );

        vm.prank(CORE_ADMIN);
        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    feeD9: MELLOW_PROTOCOL_FEE,
                    treasury: MELLOW_PROTOCOL_TREASURY
                })
            )
        );

        vm.startPrank(VELO_DEPLOY_FACTORY_ADMIN);

        deployFactory.updateMutableParams(
            IVeloDeployFactory.MutableParams({
                lpWrapperAdmin: WRAPPER_ADMIN,
                farmOwner: FARM_OWNER,
                farmOperator: FARM_OPERATOR,
                rewardsToken: VELO
            })
        );

        ICore.DepositParams memory depositParams;
        depositParams.slippageD4 = 5;
        depositParams.securityParams = new bytes(0);

        deployFactory.updateStrategyParams(
            1,
            IVeloDeployFactory.StrategyParams({
                tickNeighborhood: 0,
                intervalWidth: 3,
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                initialLiquidity: 1000000,
                minInitialLiquidity: 800000
            })
        );

        deployFactory.updateDepositParams(1, depositParams);

        deployFactory.updateStrategyParams(
            50,
            IVeloDeployFactory.StrategyParams({
                tickNeighborhood: 0,
                intervalWidth: 200,
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                initialLiquidity: 100000,
                minInitialLiquidity: 80000
            })
        );
        deployFactory.updateDepositParams(50, depositParams);

        deployFactory.updateStrategyParams(
            100,
            IVeloDeployFactory.StrategyParams({
                tickNeighborhood: 0,
                intervalWidth: 500,
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                initialLiquidity: 100000,
                minInitialLiquidity: 80000
            })
        );
        deployFactory.updateDepositParams(100, depositParams);

        deployFactory.updateStrategyParams(
            200,
            IVeloDeployFactory.StrategyParams({
                tickNeighborhood: 0,
                intervalWidth: 1000,
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                initialLiquidity: 100000,
                minInitialLiquidity: 80000
            })
        );
        deployFactory.updateDepositParams(200, depositParams);

        deployFactory.updateStrategyParams(
            2000,
            IVeloDeployFactory.StrategyParams({
                tickNeighborhood: 1000,
                intervalWidth: 10000,
                strategyType: IPulseStrategyModule.StrategyType.Original,
                initialLiquidity: 10000,
                minInitialLiquidity: 8000
            })
        );
        deployFactory.updateDepositParams(2000, depositParams);

        deployFactory.grantRole(
            deployFactory.ADMIN_DELEGATE_ROLE(),
            VELO_DEPLOY_FACTORY_ADMIN
        );

        deployFactory.grantRole(
            deployFactory.OPERATOR(),
            VELO_DEPLOY_FACTORY_OPERATOR
        );

        vm.stopPrank();
    }

    function deal(address token, address user, uint256 amount) public view {
        uint256 userBalance = IERC20(token).balanceOf(user);
        if (userBalance < amount) {
            revert(
                string(
                    abi.encodePacked(
                        "Isufficient balance. Required: ",
                        vm.toString(amount),
                        "; Actual: ",
                        vm.toString(userBalance)
                    )
                )
            );
        }
    }

    function _swap(
        address user,
        ICLPool pool,
        bool dir,
        uint256 amount
    ) private returns (uint256) {
        vm.startPrank(user);
        address tokenIn = dir ? pool.token0() : pool.token1();
        address tokenOut = dir ? pool.token1() : pool.token0();
        deal(tokenIn, user, amount);
        IERC20(tokenIn).approve(address(swapRouter), amount);
        uint256 amountOut = swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                tickSpacing: pool.tickSpacing(),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        vm.stopPrank();
        return amountOut;
    }

    function mint(
        ICLPool pool,
        uint128 liquidity,
        int24 width,
        address owner
    ) public returns (uint256 tokenId) {
        vm.startPrank(owner);

        (uint160 sqrtPriceX96, int24 tick, , , , ) = pool.slot0();
        int24 tickLower = tick - width / 2;

        {
            int24 tickSpacing = pool.tickSpacing();
            int24 remainder = tickLower % tickSpacing;
            if (remainder < 0) remainder += tickSpacing;
            tickLower -= remainder;
        }
        int24 tickUpper = tickLower + width;

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity + 1
            );

        deal(pool.token0(), owner, amount0);
        deal(pool.token1(), owner, amount1);

        IERC20(pool.token0()).approve(address(positionManager), amount0);
        IERC20(pool.token1()).approve(address(positionManager), amount1);

        (tokenId, , , ) = positionManager.mint(
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
                recipient: owner,
                deadline: block.timestamp,
                sqrtPriceX96: 0
            })
        );

        vm.stopPrank();
    }

    function createStrategy(
        ICLPool pool
    ) public returns (IVeloDeployFactory.PoolAddresses memory addresses) {
        pool.increaseObservationCardinalityNext(2);
        mint(pool, 1e19, pool.tickSpacing() * 1000, address(this));
        _swap(address(123), pool, false, 1 gwei);
        vm.startPrank(VELO_DEPLOY_FACTORY_OPERATOR);
        deal(pool.token0(), VELO_DEPLOY_FACTORY_OPERATOR, 1e6);
        deal(pool.token1(), VELO_DEPLOY_FACTORY_OPERATOR, 1e6);

        IERC20(pool.token0()).approve(address(deployFactory), 1e6);
        IERC20(pool.token1()).approve(address(deployFactory), 1e6);

        addresses = deployFactory.createStrategy(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing()
        );
        vm.stopPrank();
    }

    function build(
        int24 tickSpacing
    ) public returns (ILpWrapper wrapper, StakingRewards farm, ICLPool pool) {
        pool = ICLPool(factory.getPool(WETH, OP, tickSpacing));
        vm.prank(VELO_DEPLOY_FACTORY_OPERATOR);
        IVeloDeployFactory.PoolAddresses memory addresses = createStrategy(
            pool
        );
        wrapper = ILpWrapper(addresses.lpWrapper);
        farm = StakingRewards(addresses.synthetixFarm);
    }

    function run() external {
        _deployContract();
        (ILpWrapper wrapper, StakingRewards farm, ICLPool pool) = build(200);
        console2.log("Wrapper:", address(wrapper));
        console2.log("StakingRewards:", address(farm));
        console2.log("ICLPool:", address(pool));
    }
}
