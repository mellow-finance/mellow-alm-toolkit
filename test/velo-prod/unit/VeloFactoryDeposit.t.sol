// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    int24 constant MAX_ALLOWED_DELTA = 100;
    uint32 constant MAX_AGE = 1 hours;
    uint128 INITIAL_LIQUIDITY = 1 ether;

    ICLPool public pool = ICLPool(factory.getPool(Constants.OP, Constants.WETH, 200));

    IERC20 token0 = IERC20(pool.token0());
    IERC20 token1 = IERC20(pool.token1());
    int24 tickSpacing = pool.tickSpacing();

    IVeloFactoryDeposit.PoolStrategyParameter params0 = IVeloFactoryDeposit.PoolStrategyParameter({
        tokenId: new uint256[](0),
        pool: pool,
        strategyType: IPulseStrategyModule.StrategyType.Original,
        width: tickSpacing * 10,
        maxAmount0: 1 ether,
        maxAmount1: 1 ether,
        tickNeighborhood: 0,
        maxLiquidityRatioDeviationX96: 0,
        securityParams: abi.encode(
            IVeloOracle.SecurityParams({
                lookback: 1,
                maxAllowedDelta: MAX_ALLOWED_DELTA,
                maxAge: MAX_AGE
            })
        )
    });

    function testConstructor() external {
        VeloFactoryDeposit veloFactoryDeposit;

        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        veloFactoryDeposit = new VeloFactoryDeposit(ICore(address(0)), strategyModule);

        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        veloFactoryDeposit = new VeloFactoryDeposit(core, IPulseStrategyModule(address(0)));

        veloFactoryDeposit = new VeloFactoryDeposit(core, strategyModule);

        assertEq(address(veloFactoryDeposit.core()), address(core));
    }

    function testMint() external {
        (, int24 tick,,,,) = pool.slot0();
        int24 tick0 = tick - (tick % tickSpacing);

        deal(address(token0), Constants.DEPOSITOR, 1000 ether);
        deal(address(token1), Constants.DEPOSITOR, 1000 ether);

        vm.startPrank(Constants.DEPOSITOR);
        IERC20(token0).safeIncreaseAllowance(address(factoryDeposit), UINT256_MAX);
        IERC20(token1).safeIncreaseAllowance(address(factoryDeposit), UINT256_MAX);

        uint256 tokenId = factoryDeposit.mint(
            Constants.DEPOSITOR, Constants.DEPOSITOR, pool, tick0 - 1000, tick0 + 1000, 1 ether
        );
        vm.stopPrank();

        assertFalse(tokenId == 0);
        assertEq(token0.balanceOf(address(factoryDeposit)), 0);
        assertEq(token1.balanceOf(address(factoryDeposit)), 0);

        vm.expectRevert();
        positionManager.tokenOfOwnerByIndex(address(factoryDeposit), 0);
        assertEq(IERC721(positionManager).ownerOf(tokenId), Constants.DEPOSITOR);
    }

    function testMintTo() external {
        (, int24 tick,,,,) = pool.slot0();
        int24 tick0 = tick - (tick % tickSpacing);

        deal(address(token0), Constants.DEPOSITOR, 1000 ether);
        deal(address(token1), Constants.DEPOSITOR, 1000 ether);

        vm.startPrank(Constants.DEPOSITOR);
        IERC20(token0).safeIncreaseAllowance(address(factoryDeposit), UINT256_MAX);
        IERC20(token1).safeIncreaseAllowance(address(factoryDeposit), UINT256_MAX);

        uint256 tokenId = factoryDeposit.mint(
            Constants.DEPOSITOR, Constants.USER, pool, tick0 - 1000, tick0 + 1000, 1 ether
        );
        vm.stopPrank();

        assertFalse(tokenId == 0);
        assertEq(token0.balanceOf(address(factoryDeposit)), 0);
        assertEq(token1.balanceOf(address(factoryDeposit)), 0);
        assertEq(token0.balanceOf(Constants.USER), 0);
        assertEq(token1.balanceOf(Constants.USER), 0);

        vm.expectRevert();
        positionManager.tokenOfOwnerByIndex(address(factoryDeposit), 0);
        vm.expectRevert();
        positionManager.tokenOfOwnerByIndex(Constants.DEPOSITOR, 0);
        assertEq(IERC721(positionManager).ownerOf(tokenId), Constants.USER);
    }

    function testCreateRevert() external {
        deal(address(token0), Constants.DEPOSITOR, 1000 ether);
        deal(address(token1), Constants.DEPOSITOR, 1000 ether);

        vm.startPrank(Constants.DEPOSITOR);
        IERC20(token0).safeIncreaseAllowance(address(factoryDeposit), UINT256_MAX);
        IERC20(token1).safeIncreaseAllowance(address(factoryDeposit), UINT256_MAX);

        IVeloFactoryDeposit.PoolStrategyParameter memory params = params0;

        params.pool = ICLPool(address(123));
        vm.expectRevert(abi.encodeWithSignature("ForbiddenPool()"));
        factoryDeposit.create(Constants.DEPOSITOR, Constants.DEPOSITOR, params);

        params = params0;
        params.width = tickSpacing * 10 + tickSpacing / 2;
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        factoryDeposit.create(Constants.DEPOSITOR, Constants.DEPOSITOR, params);

        params = params0;
        params.tickNeighborhood = -1;
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        factoryDeposit.create(Constants.DEPOSITOR, Constants.DEPOSITOR, params);

        params = params0;
        params.maxAmount0 = 0;
        params.maxAmount1 = 0;
        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        factoryDeposit.create(Constants.DEPOSITOR, Constants.DEPOSITOR, params);

        params = params0;
        params.securityParams = new bytes(2);
        vm.expectRevert();
        factoryDeposit.create(Constants.DEPOSITOR, Constants.DEPOSITOR, params);

        params = params0;
        params.strategyType = IPulseStrategyModule.StrategyType.Tamper;
        vm.expectRevert(abi.encodeWithSignature("InvalidPosition()"));
        factoryDeposit.create(Constants.DEPOSITOR, Constants.DEPOSITOR, params);
    }

    function testCreateTo() external {
        deal(address(token0), Constants.DEPOSITOR, 1000 ether);
        deal(address(token1), Constants.DEPOSITOR, 1000 ether);

        vm.startPrank(Constants.DEPOSITOR);
        IERC20(token0).safeIncreaseAllowance(address(factoryDeposit), UINT256_MAX);
        IERC20(token1).safeIncreaseAllowance(address(factoryDeposit), UINT256_MAX);

        IVeloFactoryDeposit.PoolStrategyParameter memory params = params0;
        uint256[] memory tokenIds =
            factoryDeposit.create(Constants.DEPOSITOR, Constants.USER, params);

        assertEq(token0.balanceOf(address(factoryDeposit)), 0);
        assertEq(token1.balanceOf(address(factoryDeposit)), 0);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(IERC721(positionManager).ownerOf(tokenIds[i]), Constants.USER);
        }
    }

    function testCreate() external {
        deal(address(token0), Constants.DEPOSITOR, 1000 ether);
        deal(address(token1), Constants.DEPOSITOR, 1000 ether);

        vm.startPrank(Constants.DEPOSITOR);
        IERC20(token0).safeIncreaseAllowance(address(factoryDeposit), UINT256_MAX);
        IERC20(token1).safeIncreaseAllowance(address(factoryDeposit), UINT256_MAX);

        IVeloFactoryDeposit.PoolStrategyParameter memory params = params0;
        {
            params.tokenId = new uint256[](0);
            params.strategyType = IPulseStrategyModule.StrategyType.Original;
            uint256[] memory tokenIds =
                factoryDeposit.create(Constants.DEPOSITOR, Constants.DEPOSITOR, params);

            assertEq(token0.balanceOf(address(factoryDeposit)), 0);
            assertEq(token1.balanceOf(address(factoryDeposit)), 0);

            vm.expectRevert();
            positionManager.tokenOfOwnerByIndex(address(factoryDeposit), 0);

            assertEq(tokenIds.length, 1);
            for (uint256 i = 0; i < tokenIds.length; i++) {
                assertEq(IERC721(positionManager).ownerOf(tokenIds[i]), Constants.DEPOSITOR);
            }

            params.tokenId = tokenIds;
            uint256[] memory tokenIdsNew =
                factoryDeposit.create(Constants.DEPOSITOR, Constants.DEPOSITOR, params);
            for (uint256 i = 0; i < tokenIds.length; i++) {
                assertEq(tokenIdsNew[i], tokenIds[i]);
            }
        }

        {
            params.tokenId = new uint256[](0);
            params.strategyType = IPulseStrategyModule.StrategyType.LazySyncing;
            uint256[] memory tokenIds =
                factoryDeposit.create(Constants.DEPOSITOR, Constants.DEPOSITOR, params);

            assertEq(token0.balanceOf(address(factoryDeposit)), 0);
            assertEq(token1.balanceOf(address(factoryDeposit)), 0);

            vm.expectRevert();
            positionManager.tokenOfOwnerByIndex(address(factoryDeposit), 0);

            assertEq(tokenIds.length, 1);
            for (uint256 i = 0; i < tokenIds.length; i++) {
                assertEq(IERC721(positionManager).ownerOf(tokenIds[i]), Constants.DEPOSITOR);
            }

            params.tokenId = tokenIds;
            uint256[] memory tokenIdsNew =
                factoryDeposit.create(Constants.DEPOSITOR, Constants.DEPOSITOR, params);
            for (uint256 i = 0; i < tokenIds.length; i++) {
                assertEq(tokenIdsNew[i], tokenIds[i]);
            }
        }

        {
            params.tokenId = new uint256[](0);
            params.strategyType = IPulseStrategyModule.StrategyType.LazyAscending;
            uint256[] memory tokenIds =
                factoryDeposit.create(Constants.DEPOSITOR, Constants.DEPOSITOR, params);

            assertEq(token0.balanceOf(address(factoryDeposit)), 0);
            assertEq(token1.balanceOf(address(factoryDeposit)), 0);

            vm.expectRevert();
            positionManager.tokenOfOwnerByIndex(address(factoryDeposit), 0);

            assertEq(tokenIds.length, 1);
            for (uint256 i = 0; i < tokenIds.length; i++) {
                assertEq(IERC721(positionManager).ownerOf(tokenIds[i]), Constants.DEPOSITOR);
            }

            params.tokenId = tokenIds;
            uint256[] memory tokenIdsNew =
                factoryDeposit.create(Constants.DEPOSITOR, Constants.DEPOSITOR, params);
            for (uint256 i = 0; i < tokenIds.length; i++) {
                assertEq(tokenIdsNew[i], tokenIds[i]);
            }
        }

        {
            params.tokenId = new uint256[](0);
            params.strategyType = IPulseStrategyModule.StrategyType.LazyDescending;
            uint256[] memory tokenIds =
                factoryDeposit.create(Constants.DEPOSITOR, Constants.DEPOSITOR, params);

            assertEq(token0.balanceOf(address(factoryDeposit)), 0);
            assertEq(token1.balanceOf(address(factoryDeposit)), 0);

            vm.expectRevert();
            positionManager.tokenOfOwnerByIndex(address(factoryDeposit), 0);

            assertEq(tokenIds.length, 1);
            for (uint256 i = 0; i < tokenIds.length; i++) {
                assertEq(IERC721(positionManager).ownerOf(tokenIds[i]), Constants.DEPOSITOR);
            }

            params.tokenId = tokenIds;
            uint256[] memory tokenIdsNew =
                factoryDeposit.create(Constants.DEPOSITOR, Constants.DEPOSITOR, params);
            for (uint256 i = 0; i < tokenIds.length; i++) {
                assertEq(tokenIdsNew[i], tokenIds[i]);
            }
        }

        {
            params.tokenId = new uint256[](0);
            params.strategyType = IPulseStrategyModule.StrategyType.Tamper;
            params.maxLiquidityRatioDeviationX96 = Q96 / 10;
            uint256[] memory tokenIds =
                factoryDeposit.create(Constants.DEPOSITOR, Constants.DEPOSITOR, params);

            assertEq(token0.balanceOf(address(factoryDeposit)), 0);
            assertEq(token1.balanceOf(address(factoryDeposit)), 0);

            vm.expectRevert();
            positionManager.tokenOfOwnerByIndex(address(factoryDeposit), 0);

            assertEq(tokenIds.length, 2);
            for (uint256 i = 0; i < tokenIds.length; i++) {
                assertEq(IERC721(positionManager).ownerOf(tokenIds[i]), Constants.DEPOSITOR);
            }

            params.tokenId = tokenIds;
            uint256[] memory tokenIdsNew =
                factoryDeposit.create(Constants.DEPOSITOR, Constants.DEPOSITOR, params);
            for (uint256 i = 0; i < tokenIds.length; i++) {
                assertEq(tokenIdsNew[i], tokenIds[i]);
            }
        }
    }
}
