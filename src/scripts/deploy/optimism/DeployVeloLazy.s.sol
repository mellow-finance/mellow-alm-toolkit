// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import "src/Core.sol";
import "src/bots/PulseVeloBot.sol";
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
}

address constant CORE_ADMIN = address(
    bytes20((keccak256("velo admin strategy")))
);
address constant CORE_OPERATOR = address(
    bytes20((keccak256("velo operator strategy")))
);
address constant PROTOCOL_TREASURY = address(
    bytes20(keccak256("protocol treasury"))
);
address constant WRAPPER_ADMIN = address(bytes20(keccak256("wrapper admin")));
address constant FARM_OWNER = address(bytes20(keccak256("farm owner")));
address constant FARM_OPERATOR = address(bytes20(keccak256("farm operator")));
address constant VELO_DEPLOY_FACTORY_ADMIN = address(
    bytes20(keccak256("velo deploy factory admin"))
);
address constant VELO_DEPLOY_FACTORY_OPERATOR = address(
    bytes20(keccak256("velo deploy factory operator"))
);

uint128 constant MIN_INITIAL_LIQUDITY = 1000000000;
uint32 constant PROTOCOL_FEE_D9 = 1e8; // 10%

INonfungiblePositionManager constant NONFUNGIBLE_POSITION_MANAGER = INonfungiblePositionManager(
    0xbB5DFE1380333CEE4c2EeBd7202c80dE2256AdF4
);
address constant FACTORY_V1 = 0x548118C7E0B865C2CfA94D15EC86B666468ac758;
address constant FACTORY_V2 = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F;
IQuoterV2 constant QUOTER_V2 = IQuoterV2(
    0xA2DEcF05c16537C702779083Fe067e308463CE45
);
ISwapRouter constant SWAP_ROUTER = ISwapRouter(
    0x5F9a4bb5d3b0c5e233Ee3cB35701077504a6F0eb
);
address constant USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
address constant WETH = 0x4200000000000000000000000000000000000006;
address constant OP = 0x4200000000000000000000000000000000000042;

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

    function run() public {
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

        Core core = new Core(ammModule, strategyModule, oracle, address(this));
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
            address(this),
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
                pool: ICLPool(0x3241738149B24C9164dA14Fa2040159FFC6Dd237),
                factory: ICLFactory(FACTORY_V1),
                token0: USDC,
                token1: WETH,
                tickSpacing: 100
            }),
            1
        );

        return;
        _migrateRoles(core, deployFactory);
    }

    function _mintInitialPosition(
        VeloDeployFactory deployFactory,
        PoolParameter memory poolParameter,
        int24 width
    ) private {
        require(
            poolParameter.factory.getPool(
                poolParameter.token0,
                poolParameter.token1,
                poolParameter.tickSpacing
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

        deal(address(this), 10**18);
        _init(poolParameter);

        (uint160 sqrtPriceX96, int24 tick, , , , ) = poolParameter.pool.slot0();

        int24 tickLower = tick - tick % poolParameter.tickSpacing;
        int24 tickUpper = tickLower + poolParameter.tickSpacing;
        if (width > 1) {
            tickLower -= poolParameter.tickSpacing * (width / 2);
            tickUpper += poolParameter.tickSpacing * (width / 2);
            tickLower -= poolParameter.tickSpacing * (width % 2);
        }
        
        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                MIN_INITIAL_LIQUDITY + 1
            );

        (tokenId, , , ) = NONFUNGIBLE_POSITION_MANAGER.mint(
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
                recipient: address(this),
                deadline: block.timestamp,
                sqrtPriceX96: 0
            })
        );
        NONFUNGIBLE_POSITION_MANAGER.approve(address(deployFactory), tokenId);

        deployFactory.createStrategy(
            IVeloDeployFactory.DeployParams({
                tickNeighborhood: 0,
                slippageD9: 5 * 1e5,
                tokenId: tokenId,
                securityParams: abi.encode(
                    IVeloOracle.SecurityParams({
                        lookback: 50,
                        maxAllowedDelta: 2000,
                        maxAge: 7 days
                    })
                ),
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing
            })
        );
    }


    function _init(PoolParameter memory poolParameter) private {
        if (address(this).balance > 0) {
            IWETH9(WETH).deposit{value: address(this).balance}();
        }
        IERC20 token0 = IERC20(poolParameter.token0);
        IERC20 token1 = IERC20(poolParameter.token1);
        token0.approve(address(this), type(uint256).max);
        token0.approve(address(poolParameter.pool), type(uint256).max);
        token0.approve(address(NONFUNGIBLE_POSITION_MANAGER), type(uint256).max);
        token1.approve(address(this), type(uint256).max);
        token1.approve(address(poolParameter.pool), type(uint256).max);
        token1.approve(address(NONFUNGIBLE_POSITION_MANAGER), type(uint256).max);
    }

    function _migrateRoles(Core core, VeloDeployFactory deployFactory) private {
        core.grantRole(core.OPERATOR(), CORE_OPERATOR);
        core.grantRole(core.ADMIN_ROLE(), CORE_ADMIN);

        deployFactory.grantRole(
            deployFactory.ADMIN_ROLE(),
            VELO_DEPLOY_FACTORY_ADMIN
        );

        deployFactory.grantRole(
            deployFactory.OPERATOR(),
            VELO_DEPLOY_FACTORY_OPERATOR
        );

        deployFactory.revokeRole(deployFactory.ADMIN_ROLE(), address(this));

        core.revokeRole(core.ADMIN_ROLE(), address(this));
    }
}
