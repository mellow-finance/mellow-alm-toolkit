// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

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
                tickSpacing: 100,
                tickNeighborhood: 10
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
                tickSpacing: 100,
                tickNeighborhood: 10
            })
        );
        depositParams.slippageD4 = 1;
        depositParams.securityParams = abi.encode(
            IVeloOracle.SecurityParams({lookback: 100, maxAllowedDelta: 100})
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
}
