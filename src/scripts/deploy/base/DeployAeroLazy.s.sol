// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import "src/Core.sol";
import "src/bots/PulseVeloBot.sol";
import "src/helpers/CreateStrategyHelper.sol";
import "src/modules/velo/VeloAmmModule.sol";
import "src/modules/velo/VeloDepositWithdrawModule.sol";
import "src/modules/strategies/PulseStrategyModule.sol";
import "src/oracles/VeloOracle.sol";
import "src/utils/VeloDeployFactoryHelper.sol";
import "src/utils/VeloDeployFactory.sol";
import "src/interfaces/external/velo/external/IWETH9.sol";

struct PoolParameter {
    ICLPool pool;
    ICLFactory factory;
    address token0;
    address token1;
    int24 tickSpacing;
    int24 width;
    int24 maxAllowedDelta;
}

address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
address constant WETH = 0x4200000000000000000000000000000000000006;
address constant USDp = 0xB79DD08EA68A908A97220C76d19A6aA9cBDE4376;
address constant BRETT = 0x532f27101965dd16442E59d40670FaF5eBB142E4;
address constant WSTETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
address constant USDbC = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
address constant DEGEN = 0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed;
address constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
address constant CBETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
address constant BSDETH = 0xCb327b99fF831bF8223cCEd12B1338FF3aA322Ff;

/*
                    AERO_FACTORY = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A

                                               address       t0       t1   TS  wdth  maxAllowedDelta
            0xb2cc224c1c9feE385f8ad6a55b4d94E92359DC59     WETH     USDC  100    40       
            0x4D69971CCd4A636c403a3C1B00c85e99bB9B5606     WETH    USDC+  100    40
            0x4e829F8A5213c42535AB84AA40BD4aDCCE9cBa02     WETH    BRETT  200    30
            0x0c1A09d5D0445047DA3Ab4994262b22404288A3B     USDC    USDC+    1     1
            0x861A2922bE165a5Bd41b1E482B49216b465e1B5F     WETH   wstETH    1     1
            0x20086910E220D5f4c9695B784d304A72a0de403B     USD+    USDbC    1     1
            0xaFB62448929664Bfccb0aAe22f232520e765bA88     WETH    DEGEN  200    30
            0x47cA96Ea59C13F72745928887f84C9F52C3D7348    cbETH     WETH    1     1 
            0x82321f3BEB69f503380D6B233857d5C43562e2D0     WETH     AERO  200    30
            0x2ae9DF02539887d4EbcE0230168a302d34784c82     WETH   bsdETH    1     1
        */

uint128 constant MIN_INITIAL_LIQUDITY = 1000;
uint32 constant PROTOCOL_FEE_D9 = 1e8; // 10%

INonfungiblePositionManager constant NONFUNGIBLE_POSITION_MANAGER = INonfungiblePositionManager(
    0x827922686190790b37229fd06084350E74485b72
);

address constant AERO_FACTORY = 0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A;
IQuoterV2 constant QUOTER_V2 = IQuoterV2(
    0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a
);
ISwapRouter constant SWAP_ROUTER = ISwapRouter(
    0x2626664c2603336E57B271c5C0b26F421741e481
);
contract Deploy is Script, Test {
    address coreAddress;
    address deployFactoryAddress;
    address oracleAddress;
    address strategyModuleAddress;
    address velotrDeployFactoryHelperAddress;
    address ammModuleAddress;
    address veloDepositWithdrawModuleAddress;
    address pulseVeloBotAddress;
    address coreAddess;
    uint256 tokenId;

    uint256 immutable deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address immutable deployerAddress = vm.addr(deployerPrivateKey);
    address immutable CORE_ADMIN = 0x379Ea012582A33AB78Feb34474Df7aD6Dc39F178; // msig
    address immutable PROTOCOL_TREASURY =
        0x0da6d939Cb0555A0D2eB99E310eBAE68432F31F2; // msig
    address immutable CORE_OPERATOR =
        0x9DFb1fC83EB81F99ACb008c49384c4446F2313Ed; // bot eoa

    address immutable AERO_DEPLOY_FACTORY_ADMIN = CORE_ADMIN;
    address immutable WRAPPER_ADMIN = CORE_ADMIN;
    address immutable FARM_OWNER = CORE_ADMIN;
    address immutable FARM_OPERATOR = CORE_OPERATOR;
    address immutable AERO_DEPLOY_FACTORY_OPERATOR = deployerAddress;

    function run() public {
        console.log("Deployer address:", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

        VeloOracle oracle = new VeloOracle();
        oracleAddress = address(oracle);
        console2.log("oracleAddress", oracleAddress);

        PulseStrategyModule strategyModule = new PulseStrategyModule();
        strategyModuleAddress = address(strategyModule);
        console2.log("strategyModuleAddress", strategyModuleAddress);

        VeloDeployFactoryHelper velotrDeployFactoryHelper = new VeloDeployFactoryHelper();
        velotrDeployFactoryHelperAddress = address(velotrDeployFactoryHelper);
        console2.log(
            "velotrDeployFactoryHelperAddress",
            velotrDeployFactoryHelperAddress
        );

        VeloAmmModule ammModule = new VeloAmmModule(
            NONFUNGIBLE_POSITION_MANAGER
        );
        ammModuleAddress = address(ammModule);
        console2.log("ammModuleAddress", ammModuleAddress);

        VeloDepositWithdrawModule veloDepositWithdrawModule = new VeloDepositWithdrawModule(
                NONFUNGIBLE_POSITION_MANAGER
            );
        veloDepositWithdrawModuleAddress = address(veloDepositWithdrawModule);
        console2.log(
            "veloDepositWithdrawModuleAddress",
            veloDepositWithdrawModuleAddress
        );

        PulseVeloBot pulseVeloBot = new PulseVeloBot(
            QUOTER_V2,
            SWAP_ROUTER,
            NONFUNGIBLE_POSITION_MANAGER
        );
        pulseVeloBotAddress = address(pulseVeloBot);
        console2.log("pulseVeloBotAddress", pulseVeloBotAddress);

        Core core = new Core(
            ammModule,
            strategyModule,
            oracle,
            deployerAddress
        );
        coreAddess = address(core);
        console2.log("coreAddess", coreAddess);

        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    feeD9: PROTOCOL_FEE_D9,
                    treasury: PROTOCOL_TREASURY
                })
            )
        );

        core.setOperatorFlag(true);

        VeloDeployFactory deployFactory = new VeloDeployFactory(
            deployerAddress,
            core,
            veloDepositWithdrawModule,
            velotrDeployFactoryHelper
        );
        deployFactoryAddress = address(deployFactory);
        console2.log("deployFactoryAddress", deployFactoryAddress);

        deployFactory.updateMutableParams(
            IVeloDeployFactory.MutableParams({
                lpWrapperAdmin: WRAPPER_ADMIN,
                lpWrapperManager: address(0),
                farmOwner: FARM_OWNER,
                farmOperator: FARM_OPERATOR,
                minInitialLiquidity: MIN_INITIAL_LIQUDITY
            })
        );

        _mintInitialPosition(
            deployFactory,
            PoolParameter({
                factory: ICLFactory(AERO_FACTORY),
                pool: ICLPool(address(0)),
                width: 0,
                tickSpacing: 0,
                token0: address(0),
                token1: address(0),
                maxAllowedDelta: 0
            })
        );

        _migrateRoles(core, deployFactory);

        vm.stopBroadcast();
    }

    function _mintInitialPosition(
        VeloDeployFactory deployFactory,
        PoolParameter memory poolParameter
    ) private {
        require(
            poolParameter.factory.getPool(
                poolParameter.token0,
                poolParameter.token1,
                poolParameter.pool.tickSpacing()
            ) == address(poolParameter.pool),
            "pool does not belong to the factory"
        );
        require(
            poolParameter.pool.token0() == poolParameter.token0,
            "wrong token0"
        );
        require(
            poolParameter.pool.token1() == poolParameter.token1,
            "wrong token1"
        );
        require(
            poolParameter.pool.tickSpacing() == poolParameter.tickSpacing,
            "wrong pool tickSpacing"
        );

        (, , , uint16 observationCardinality, , ) = poolParameter.pool.slot0();
        if (observationCardinality < 100) {
            poolParameter.pool.increaseObservationCardinalityNext(100);
        }

        _init(poolParameter);

        (uint160 sqrtPriceX96, int24 tick, , , , ) = poolParameter.pool.slot0();

        int24 tickLower = tick - (tick % poolParameter.tickSpacing);
        int24 tickUpper = tickLower + poolParameter.tickSpacing;
        if (poolParameter.width > 1) {
            tickLower -= poolParameter.tickSpacing * (poolParameter.width / 2);
            tickUpper += poolParameter.tickSpacing * (poolParameter.width / 2);
            tickLower -= poolParameter.tickSpacing * (poolParameter.width % 2);
        }

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                MIN_INITIAL_LIQUDITY * 2
            );

        amount0 = amount0 > 0 ? amount0 : 1;
        amount1 = amount1 > 0 ? amount1 : 1;
        (
            uint256 tokenId_,
            uint128 liquidity_,
            ,

        ) = NONFUNGIBLE_POSITION_MANAGER.mint(
                INonfungiblePositionManager.MintParams({
                    token0: poolParameter.token0,
                    token1: poolParameter.token1,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    tickSpacing: poolParameter.tickSpacing,
                    amount0Desired: amount0,
                    amount1Desired: amount1,
                    amount0Min: 0,
                    amount1Min: 0,
                    recipient: deployerAddress,
                    deadline: block.timestamp + 300,
                    sqrtPriceX96: 0
                })
            );

        require(tokenId_ != 0, "null tokenId");
        require(liquidity_ != 0, "zero liquidity");

        NONFUNGIBLE_POSITION_MANAGER.approve(address(deployFactory), tokenId_);

        deployFactory.createStrategy(
            IVeloDeployFactory.DeployParams({
                tickNeighborhood: 0,
                slippageD9: 5 * 1e5,
                tokenId: tokenId_,
                securityParams: abi.encode(
                    IVeloOracle.SecurityParams({
                        lookback: 10,
                        maxAllowedDelta: poolParameter.maxAllowedDelta,
                        maxAge: 7 days
                    })
                ),
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing
            })
        );
    }

    function _init(PoolParameter memory poolParameter) private {
        IERC20 token0 = IERC20(poolParameter.token0);
        IERC20 token1 = IERC20(poolParameter.token1);
        token0.approve(address(poolParameter.pool), type(uint256).max);
        token0.approve(
            address(NONFUNGIBLE_POSITION_MANAGER),
            type(uint256).max
        );
        token1.approve(address(poolParameter.pool), type(uint256).max);
        token1.approve(
            address(NONFUNGIBLE_POSITION_MANAGER),
            type(uint256).max
        );
    }

    function _migrateRoles(Core core, VeloDeployFactory deployFactory) private {
        core.grantRole(core.ADMIN_DELEGATE_ROLE(), deployerAddress);
        core.grantRole(core.OPERATOR(), CORE_OPERATOR);
        core.grantRole(core.ADMIN_ROLE(), CORE_ADMIN);

        deployFactory.grantRole(
            deployFactory.ADMIN_DELEGATE_ROLE(),
            deployerAddress
        );

        deployFactory.grantRole(
            deployFactory.OPERATOR(),
            AERO_DEPLOY_FACTORY_OPERATOR
        );

        deployFactory.grantRole(
            deployFactory.ADMIN_ROLE(),
            AERO_DEPLOY_FACTORY_ADMIN
        );

        deployFactory.revokeRole(
            deployFactory.ADMIN_DELEGATE_ROLE(),
            deployerAddress
        );
        deployFactory.revokeRole(deployFactory.ADMIN_ROLE(), deployerAddress);
        require(!deployFactory.isAdmin(deployerAddress));
        require(deployFactory.isAdmin(CORE_ADMIN));

        core.revokeRole(core.ADMIN_DELEGATE_ROLE(), deployerAddress);
        core.revokeRole(core.ADMIN_ROLE(), deployerAddress);
        require(!core.isAdmin(deployerAddress));
        require(core.isAdmin(CORE_ADMIN));
    }
}
