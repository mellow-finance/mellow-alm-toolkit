// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

import "src/interfaces/external/velo/IMinter.sol";
import "src/utils/LpFarm.sol";

contract Unit is Fixture {
    using SafeERC20 for IERC20;
    using Math for uint256;

    address public constant VELO = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;
    address public immutable MINTER = 0x6dc9E1C04eE59ed3531d73a72256C0da46D10982;

    address immutable admin = vm.addr(uint256(keccak256("admin")));
    address immutable operator = vm.addr(uint256(keccak256("operator")));
    address immutable user = vm.addr(uint256(keccak256("user")));

    address lpFarmImplementation;

    DeployScript.CoreDeployment contracts;

    function setUp() external {
        contracts = deployContracts();

        lpFarmImplementation = address(new LpFarm(address(contracts.core)));

        deal(Constants.OPTIMISM_WETH, address(this), 1e10 ether);
        deal(Constants.OPTIMISM_OP, address(this), 1e10 ether);
    }

    function testInitialize() external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
        (LpFarm lpFarm,) = _initLpFarm(pool);
    }

    function testRebase() external {
        ICLPool pool = ICLPool(factory.getPool(Constants.OPTIMISM_WETH, Constants.OPTIMISM_OP, 200));
        (LpFarm lpFarm,) = _initLpFarm(pool);
        (, int24 tick,,,,) = pool.slot0();
        for (uint256 i = 0; i < 7; i++) {
            movePrice(pool, TickMath.getSqrtRatioAtTick(tick + 3));
            movePrice(pool, TickMath.getSqrtRatioAtTick(tick - 3));
            movePrice(pool, TickMath.getSqrtRatioAtTick(tick));

            skip(7 days + 1);

            IMinter(MINTER).updatePeriod();
            uint256 lpPriceBefore = lpFarm.lpPrice();
            lpFarm.rebase();
            uint256 lpPriceAfter = lpFarm.lpPrice();
            assertGt(lpPriceAfter, lpPriceBefore);
        }
    }

    function _initLpFarm(ICLPool pool) internal returns (LpFarm lpFarm, ILpWrapper lpWrapper) {
        (lpWrapper,) =
            deployLpWrapper(pool, IPulseStrategyModule.StrategyType.LazySyncing, contracts);

        lpFarm = LpFarm(Clones.clone(lpFarmImplementation));
        deal(VELO, address(this), 1 ether);
        IERC20(VELO).approve(address(lpFarm), 1 ether);
        lpFarm.initialize(lpWrapper, admin, operator, 1 ether);

        // vm.prank(Constants.OPTIMISM_LP_WRAPPER_MANAGER);
        // lpWrapper.setLpStaker(address(lpStaker));
    }
}
