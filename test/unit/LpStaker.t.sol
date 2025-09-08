// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;

    int24 constant MAX_ALLOWED_DELTA = 100;
    uint32 constant MAX_AGE = 1 hours;
    uint128 INITIAL_LIQUIDITY = 1 ether;

    address public constant VELO = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;

    address immutable admin = vm.addr(uint256(keccak256("admin")));
    address immutable manager = vm.addr(uint256(keccak256("manager")));

    address lpStakerImplementation;

    DeployScript.CoreDeployment contracts;

    function setUp() external {
        contracts = deployContracts();

        lpStakerImplementation = address(new LpStaker(address(contracts.core)));

        deal(Constants.OPTIMISM_WETH, address(this), 1e10 ether);
        deal(Constants.OPTIMISM_OP, address(this), 1e10 ether);
    }

    function testCreate() external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
        ILpStaker lpStaker = _initLpStaker(pool);
    }

    function _initLpStaker(ICLPool pool) internal returns (ILpStaker lpStaker) {
        (ILpWrapper lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.LazySyncing, contracts);

        address token0 = pool.token0();
        address token1 = pool.token1();

        ICLPool rewardPool0 = ICLPool(factory.createPool(token0, VELO, 100, uint160(Q96)));
        mint(token0, VELO, 100, -1000, 1000, 1e6 ether, rewardPool0, address(this));
        rewardPool0.increaseObservationCardinalityNext(100);
        for (int24 index = 0; index < 100; index++) {
            movePrice(rewardPool0, TickMath.getSqrtRatioAtTick(index));
        }

        ICLPool rewardPool1 = ICLPool(factory.createPool(token1, VELO, 100, uint160(Q96)));
        mint(token1, VELO, 100, -1000, 1000, 1e6 ether, rewardPool1, address(this));

        lpStaker = ILpStaker(Clones.clone(lpStakerImplementation));
        lpStaker.initialize(lpWrapper, address(rewardPool0), address(rewardPool1), admin, manager);
    }
}
