// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../Imports.sol";
import "scripts/deploy/Constants.sol";

contract Fixture is DeployScript, Test {
    using SafeERC20 for IERC20;

    address WETH = 0x4200000000000000000000000000000000000006;

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

    function getValidDeployParams(ICLPool pool, IPulseStrategyModule.StrategyType strategyType)
        internal
        view
        returns (IVeloDeployFactory.DeployParams memory deployParams)
    {
        deployParams.slippageD9 = 1e6;
        deployParams.strategyParams = IPulseStrategyModule.StrategyParams({
            strategyType: strategyType,
            tickNeighborhood: 0, // Neighborhood of ticks to consider for rebalancing
            tickSpacing: pool.tickSpacing(), // tickSpacing of the corresponding amm pool
            width: pool.tickSpacing() * 2, // Width of the interval
            maxLiquidityRatioDeviationX96: strategyType == IPulseStrategyModule.StrategyType.Tamper
                ? Q96 / 20
                : 0
        });

        int24 maxAllowedDelta = deployParams.strategyParams.tickSpacing == 1
            ? int24(1)
            : deployParams.strategyParams.width / 10;
        deployParams.securityParams = IVeloOracle.SecurityParams({
            lookback: 10,
            maxAge: 1 hours,
            maxAllowedDelta: maxAllowedDelta,
            extraData: ""
        });

        deployParams.pool = address(pool);
        deployParams.maxAmount0 = 10 ** (ERC20(pool.token0()).decimals() / 2 + 1);
        deployParams.maxAmount1 = 10 ** (ERC20(pool.token1()).decimals() / 2 + 1);
        deployParams.initialTotalSupply =
            10 ** ((ERC20(pool.token0()).decimals() + ERC20(pool.token1()).decimals()) / 4 + 1);
        deployParams.totalSupplyLimit = 1000 ether;
    }

    function compareDeployParams(
        IVeloDeployFactory.DeployParams memory l,
        IVeloDeployFactory.DeployParams memory r
    ) internal pure returns (bool) {
        return keccak256(abi.encode(l)) == keccak256(abi.encode(r));
    }

    function deployLpWrapper(
        ICLPool pool,
        IPulseStrategyModule.StrategyType strategyType,
        DeployScript.CoreDeployment memory contracts
    ) public returns (ILpWrapper lpWrapper, IVeloDeployFactory.DeployParams memory deployParams) {
        deployParams.slippageD9 = 1e6;
        deployParams.strategyParams = IPulseStrategyModule.StrategyParams({
            strategyType: strategyType,
            tickNeighborhood: 0, // Neighborhood of ticks to consider for rebalancing
            tickSpacing: pool.tickSpacing(), // tickSpacing of the corresponding amm pool
            width: pool.tickSpacing() * 2, // Width of the interval
            maxLiquidityRatioDeviationX96: strategyType == IPulseStrategyModule.StrategyType.Tamper
                ? Q96 / 20
                : 0
        });

        int24 maxAllowedDelta = deployParams.strategyParams.tickSpacing == 1
            ? int24(1)
            : deployParams.strategyParams.width / 10;
        deployParams.securityParams = IVeloOracle.SecurityParams({
            lookback: 10,
            maxAge: 1 hours,
            maxAllowedDelta: maxAllowedDelta,
            extraData: ""
        });

        deployParams.pool = address(pool);
        deployParams.maxAmount0 = 10 ** (ERC20(pool.token0()).decimals() / 2 + 1);
        deployParams.maxAmount1 = 10 ** (ERC20(pool.token1()).decimals() / 2 + 1);
        deployParams.initialTotalSupply =
            10 ** ((ERC20(pool.token0()).decimals() + ERC20(pool.token1()).decimals()) / 4 + 1);
        deployParams.totalSupplyLimit = 1000 ether;

        if (
            IERC20(pool.token0()).balanceOf(address(contracts.deployFactory))
                < deployParams.maxAmount0
        ) {
            deal(pool.token0(), address(contracts.deployFactory), deployParams.maxAmount0);
        }
        if (
            IERC20(pool.token1()).balanceOf(address(contracts.deployFactory))
                < deployParams.maxAmount1
        ) {
            deal(pool.token1(), address(contracts.deployFactory), deployParams.maxAmount1);
        }

        uint160 status = contracts.deployFactory.getDeployParamsStatus(deployParams);
        bytes32 proposalId;
        if (status == uint160(IVeloDeployFactory.DeployParamsStatus.None)) {
            vm.prank(params.factoryProposer);
            proposalId = contracts.deployFactory.proposeDeployParams(deployParams);

            vm.prank(params.factoryManager);
            contracts.deployFactory.acceptDeployParams(proposalId);

            lpWrapper = deployStrategy(contracts, proposalId);
            vm.stopPrank();
        } else if (status == uint160(IVeloDeployFactory.DeployParamsStatus.Proposed)) {
            proposalId = contracts.deployFactory.deployParamsHash(deployParams);

            vm.prank(params.factoryManager);
            contracts.deployFactory.acceptDeployParams(proposalId);
            lpWrapper = deployStrategy(contracts, proposalId);
            vm.stopPrank();
        } else if (status == uint160(IVeloDeployFactory.DeployParamsStatus.Accepted)) {
            proposalId = contracts.deployFactory.deployParamsHash(deployParams);
            lpWrapper = deployStrategy(contracts, proposalId);
        } else {
            lpWrapper = ILpWrapper(address(status));
        }
    }

    function deployLpWrapper(
        DeployScript.CoreDeployment memory contracts,
        IVeloDeployFactory.DeployParams memory deployParams
    ) internal returns (ILpWrapper lpWrapper) {
        vm.prank(params.factoryProposer);
        bytes32 proposalId = contracts.deployFactory.proposeDeployParams(deployParams);

        ICLPool pool = ICLPool(deployParams.pool);

        vm.prank(params.factoryManager);
        contracts.deployFactory.acceptDeployParams(proposalId);

        IERC20(pool.token0()).approve(address(contracts.deployFactory), deployParams.maxAmount0);
        IERC20(pool.token1()).approve(address(contracts.deployFactory), deployParams.maxAmount1);
        lpWrapper = deployStrategy(contracts, proposalId);
        //vm.stopPrank();
    }

    function dealTokenAmount(address token, address recipient, uint256 amount) public {
        if (token == WETH) {
            deal(recipient, amount);
            vm.startPrank(recipient);
            IWETH9(WETH).deposit{value: amount}();
            vm.stopPrank();
        } else {
            console2.log(token);
            if (token == 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85) {
                deal(0xbd17DEee53a58B48548117a11a2E7bbF2D0d6Fa7, recipient, amount);
            } else {
                deal(token, recipient, amount);
            }
        }
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
            deal(pool.token0(), recipient, uint256(amount0Delta));
            IERC20(pool.token0()).safeTransferFrom(recipient, address(pool), uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            deal(pool.token1(), recipient, uint256(amount1Delta));
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
