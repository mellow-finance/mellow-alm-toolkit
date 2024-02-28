// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./Constants.sol";

contract Deploy is Script {
    using SafeERC20 for IERC20;

    uint24 public constant FEE = 2500;

    INonfungiblePositionManager public positionManager =
        INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER);
    IAgniFactory public factory = IAgniFactory(Constants.AGNI_FACTORY);
    IAgniPool public pool =
        IAgniPool(factory.getPool(Constants.USDC, Constants.WETH, FEE));

    AgniAmmModule public ammModule;
    PulseStrategyModule public strategyModule;
    AgniOracle public oracle;
    AgniDepositWithdrawModule public dwModule;
    LpWrapper public lpWrapper;
    Core public core;
    address public farm;
    StakingRewards public stakingRewards;
    PulseAgniBot public bot;

    function mint(
        address token0,
        address token1,
        uint24 fee,
        int24 width,
        uint128 liquidity
    ) public returns (uint256) {
        if (token0 > token1) (token0, token1) = (token1, token0);
        (uint160 sqrtRatioX96, int24 spotTick, , , , , ) = pool.slot0();
        {
            int24 remainder = spotTick % pool.tickSpacing();
            if (remainder < 0) remainder += pool.tickSpacing();
            spotTick -= remainder;
        }
        INonfungiblePositionManager.MintParams memory mintParams;
        mintParams.tickLower = spotTick - width / 2;
        mintParams.tickUpper = mintParams.tickLower + width;
        mintParams.recipient = Constants.OWNER;
        mintParams.deadline = type(uint256).max;
        mintParams.token0 = token0;
        mintParams.token1 = token1;
        mintParams.fee = fee;
        {
            uint160 sqrtLowerRatioX96 = TickMath.getSqrtRatioAtTick(
                mintParams.tickLower
            );
            uint160 sqrtUpperRatioX96 = TickMath.getSqrtRatioAtTick(
                mintParams.tickUpper
            );
            (
                mintParams.amount0Desired,
                mintParams.amount1Desired
            ) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtRatioX96,
                sqrtLowerRatioX96,
                sqrtUpperRatioX96,
                liquidity
            );
        }
        IERC20(token0).safeIncreaseAllowance(
            address(positionManager),
            mintParams.amount0Desired
        );
        IERC20(token1).safeIncreaseAllowance(
            address(positionManager),
            mintParams.amount1Desired
        );
        (uint256 tokenId, uint128 actualLiquidity, , ) = positionManager.mint(
            mintParams
        );
        require((liquidity * 99) / 100 <= actualLiquidity && tokenId > 0);

        return tokenId;
    }

    struct DepositParams {
        int24 width;
        int24 tickNeighborhood;
        int24 tickSpacing;
        uint16 slippageD4;
    }

    function run() external {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("DEPLOYER_PK"))));

        ammModule = new AgniAmmModule(
            INonfungiblePositionManager(positionManager)
        );

        strategyModule = new PulseStrategyModule();
        oracle = new AgniOracle();
        core = new Core(ammModule, strategyModule, oracle, Constants.OWNER);

        dwModule = new AgniDepositWithdrawModule(
            INonfungiblePositionManager(positionManager),
            ammModule
        );
        lpWrapper = new LpWrapper(
            core,
            dwModule,
            "lp wrapper",
            "LPWR",
            Constants.OWNER
        );
        stakingRewards = new StakingRewards(
            Constants.OWNER,
            Constants.OWNER,
            address(Constants.USDT), // random reward address
            address(lpWrapper)
        );
        bot = new PulseAgniBot(
            IQuoterV2(Constants.AGNI_QUOTER_V2),
            ISwapRouter(Constants.AGNI_SWAP_ROUTER),
            positionManager
        );

        int24 tickSpacing = pool.tickSpacing();

        DepositParams memory params = DepositParams({
            tickSpacing: tickSpacing,
            width: tickSpacing * 4,
            tickNeighborhood: tickSpacing,
            slippageD4: 100
        });

        ICore.DepositParams memory depositParams;
        depositParams.tokenIds = new uint256[](1);
        depositParams.tokenIds[0] = mint(
            Constants.USDC,
            Constants.WETH,
            FEE,
            params.width,
            1e9
        );
        depositParams.owner = Constants.OWNER;
        depositParams.farm = address(0);
        depositParams.strategyParams = abi.encode(
            IPulseStrategyModule.StrategyParams({
                tickNeighborhood: params.tickNeighborhood,
                tickSpacing: params.tickSpacing,
                strategyType: IPulseStrategyModule.StrategyType.Original,
                width: 200
            })
        );
        depositParams.securityParams = abi.encode(
            AgniOracle.SecurityParams({lookback: 10, maxAllowedDelta: 10})
        );
        depositParams.slippageD4 = params.slippageD4;
        depositParams.owner = address(lpWrapper);
        depositParams.vault = address(stakingRewards);

        positionManager.approve(address(core), depositParams.tokenIds[0]);
        uint256 nftId = core.deposit(depositParams);
        lpWrapper.initialize(nftId, 5e5);

        vm.stopBroadcast();
    }
}
