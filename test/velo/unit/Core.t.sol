// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

import "../../../src/bots/EmptyBot.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    Core public core;
    VeloOracle public oracle = new VeloOracle();
    VeloAmmModule public ammModule = new VeloAmmModule(positionManager);
    VeloDepositWithdrawModule public depositWithdrawModule =
        new VeloDepositWithdrawModule(positionManager);
    PulseStrategyModule public strategyModule = new PulseStrategyModule();
    ICLPool public pool = ICLPool(0xC358c95b146E9597339b376063A2cB657AFf84eb);

    function testContructor() external {
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        core = new Core(ammModule, strategyModule, oracle, address(0));
        core = new Core(ammModule, strategyModule, oracle, Constants.OWNER);
        assertTrue(address(core) != address(0));
    }

    function testDeposit() external {
        core = new Core(ammModule, strategyModule, oracle, Constants.OWNER);
        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool
        );
        vm.startPrank(Constants.OWNER);

        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    treasury: Constants.PROTOCOL_TREASURY,
                    feeD9: Constants.PROTOCOL_FEE_D9
                })
            )
        );

        positionManager.approve(address(core), tokenId);
        ICore.DepositParams memory depositParams;
        depositParams.tokenIds = new uint256[](1);
        depositParams.tokenIds[0] = tokenId;
        depositParams.owner = Constants.OWNER;
        depositParams.callbackParams = new bytes(123);
        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.deposit(depositParams);

        depositParams.callbackParams = abi.encode(
            IVeloAmmModule.CallbackParams({
                gauge: address(pool.gauge()),
                farm: address(1)
            })
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.deposit(depositParams);

        depositParams.strategyParams = abi.encode(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.Original,
                width: 1000,
                tickSpacing: 200,
                tickNeighborhood: 100
            })
        );

        vm.expectRevert(abi.encodeWithSignature("InvalidParams()"));
        core.deposit(depositParams);

        depositParams.slippageD4 = 1;
        depositParams.securityParams = new bytes(123);

        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.deposit(depositParams);

        depositParams.securityParams = abi.encode(
            IVeloOracle.SecurityParams({lookback: 100, maxAllowedDelta: 100})
        );

        assertEq(positionManager.ownerOf(tokenId), Constants.OWNER);

        core.deposit(depositParams);

        assertEq(positionManager.ownerOf(tokenId), address(pool.gauge()));

        vm.stopPrank();
    }

    function _depositToken(uint256 tokenId) private returns (uint256 id) {
        vm.startPrank(Constants.OWNER);
        core = new Core(ammModule, strategyModule, oracle, Constants.OWNER);
        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    treasury: Constants.PROTOCOL_TREASURY,
                    feeD9: Constants.PROTOCOL_FEE_D9
                })
            )
        );

        positionManager.approve(address(core), tokenId);

        ICore.DepositParams memory depositParams;
        depositParams.tokenIds = new uint256[](1);
        depositParams.tokenIds[0] = tokenId;
        depositParams.owner = Constants.OWNER;
        depositParams.callbackParams = abi.encode(
            IVeloAmmModule.CallbackParams({
                gauge: address(pool.gauge()),
                farm: address(1)
            })
        );
        depositParams.strategyParams = abi.encode(
            IPulseStrategyModule.StrategyParams({
                strategyType: IPulseStrategyModule.StrategyType.Original,
                width: 1000,
                tickSpacing: 200,
                tickNeighborhood: 100
            })
        );
        depositParams.slippageD4 = 1;
        depositParams.securityParams = abi.encode(
            IVeloOracle.SecurityParams({lookback: 1, maxAllowedDelta: 100000})
        );

        id = core.deposit(depositParams);

        vm.stopPrank();
    }

    function testWithdraw() external {
        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool
        );

        uint256 positionId = _depositToken(tokenId);

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        core.withdraw(positionId, Constants.OWNER);

        vm.startPrank(Constants.OWNER);

        assertEq(positionManager.ownerOf(tokenId), address(pool.gauge()));
        core.withdraw(positionId, Constants.OWNER);
        assertEq(positionManager.ownerOf(tokenId), Constants.OWNER);

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        core.withdraw(positionId, Constants.OWNER);

        vm.stopPrank();
    }

    function testSetProtocolParams() external {
        core = new Core(ammModule, strategyModule, oracle, Constants.OWNER);
        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        core.setProtocolParams(new bytes(123));
        vm.startPrank(Constants.OWNER);
        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.setProtocolParams(new bytes(123));
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    treasury: address(0),
                    feeD9: Constants.PROTOCOL_FEE_D9
                })
            )
        );
        vm.expectRevert(abi.encodeWithSignature("InvalidFee()"));
        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    treasury: address(1),
                    feeD9: 3e8 + 1
                })
            )
        );
        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    treasury: Constants.PROTOCOL_TREASURY,
                    feeD9: Constants.PROTOCOL_FEE_D9
                })
            )
        );
        vm.stopPrank();
    }

    function _checkState(
        uint256 positionId,
        ICore.RebalanceParams memory rebalanceParams
    ) private {
        ICore.PositionInfo memory infoBefore = core.position(positionId);
        uint256 capitalBefore = 0;
        uint256 capitalAfter = 0;
        (uint160 sqrtPriceX96, int24 tick, , , , ) = pool.slot0();
        uint256 priceX96 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, Q96);

        {
            (uint256 amount0, uint256 amount1) = ammModule.tvl(
                infoBefore.tokenIds[0],
                sqrtPriceX96,
                infoBefore.callbackParams,
                core.protocolParams()
            );
            capitalBefore = FullMath.mulDiv(amount0, priceX96, Q96) + amount1;
        }

        core.rebalance(rebalanceParams);

        ICore.PositionInfo memory infoAfter = core.position(positionId);
        IAmmModule.Position memory positionAfter = ammModule.getPositionInfo(
            infoAfter.tokenIds[0]
        );

        {
            (uint256 amount0, uint256 amount1) = ammModule.tvl(
                infoAfter.tokenIds[0],
                sqrtPriceX96,
                infoAfter.callbackParams,
                core.protocolParams()
            );
            capitalAfter = FullMath.mulDiv(amount0, priceX96, Q96) + amount1;
        }

        IPulseStrategyModule.StrategyParams memory strategyParams = abi.decode(
            infoBefore.strategyParams,
            (IPulseStrategyModule.StrategyParams)
        );

        assertTrue(
            FullMath.mulDiv(capitalBefore, D4 - infoBefore.slippageD4, D4) <=
                capitalAfter
        );

        assertEq(
            positionAfter.tickUpper - positionAfter.tickLower,
            strategyParams.width
        );
        assertEq(positionAfter.tickUpper % strategyParams.tickSpacing, 0);
        assertEq(positionAfter.tickLower % strategyParams.tickSpacing, 0);
        assertTrue(
            positionAfter.tickLower <= tick && tick <= positionAfter.tickUpper
        );
    }

    function testRebalance() external {
        pool.increaseObservationCardinalityNext(2);
        mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 100,
            1000000,
            pool
        );

        uint256 tokenId = mint(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing(),
            pool.tickSpacing() * 2,
            10000,
            pool
        );

        ICore.RebalanceParams memory rebalanceParams;

        uint256 positionId = _depositToken(tokenId);
        vm.startPrank(Constants.DEPLOYER);
        movePrice(-10, pool);
        vm.stopPrank();

        vm.startPrank(Constants.OWNER);
        core.setOperatorFlag(true);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSignature("Forbidden()"));
        core.rebalance(rebalanceParams);

        vm.startPrank(Constants.OWNER);
        core.setOperatorFlag(false);
        vm.stopPrank();

        rebalanceParams.callback = address(new EmptyBot());

        // nothig happens
        core.rebalance(rebalanceParams);

        rebalanceParams.ids = new uint256[](1);
        rebalanceParams.ids[0] = positionId;

        vm.expectRevert(abi.encodeWithSignature("InvalidLength()"));
        core.rebalance(rebalanceParams);

        rebalanceParams.callback = address(
            new PulseVeloBot(quoterV2, swapRouter, positionManager)
        );

        vm.expectRevert();
        core.rebalance(rebalanceParams);

        rebalanceParams.data = abi.encode(
            new ISwapRouter.ExactInputSingleParams[](0)
        );

        vm.expectRevert();
        core.rebalance(rebalanceParams);

        deal(pool.token0(), address(rebalanceParams.callback), 10 wei);
        deal(pool.token1(), address(rebalanceParams.callback), 30 wei);
        _checkState(positionId, rebalanceParams);

        vm.startPrank(Constants.DEPLOYER);
        movePrice(-800, pool);
        vm.stopPrank();

        skip(1);

        {
            ISwapRouter.ExactInputSingleParams[]
                memory params = new ISwapRouter.ExactInputSingleParams[](1);
            params[0] = ISwapRouter.ExactInputSingleParams({
                tokenIn: pool.token0(),
                tokenOut: pool.token1(),
                tickSpacing: pool.tickSpacing(),
                recipient: rebalanceParams.callback,
                amountIn: 150 wei,
                sqrtPriceLimitX96: 0,
                amountOutMinimum: 0,
                deadline: type(uint256).max
            });

            rebalanceParams.data = abi.encode(params);
        }
        _checkState(positionId, rebalanceParams);
    }
}
