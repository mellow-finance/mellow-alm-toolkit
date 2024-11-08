// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.25;

import "../../scripts/deploy/Constants.sol";

contract SolvencyRunner is Test, DeployScript {
    using SafeERC20 for IERC20;
    using RandomLib for RandomLib.Storage;

    uint256 private constant Q96 = 2 ** 96;

    ICore private _core;
    ILpWrapper private _wrapper;
    RandomLib.Storage internal rnd;

    enum Transition {
        DEPOSIT,
        WITHDRAW,
        SWAP,
        SKIP,
        REBALANCE,
        SET_PARAMS,
        SET_LIMIT
    }

    address[] private depositors;
    uint256[] private depositedAmounts0;
    uint256[] private depositedAmounts1;
    uint256[] private depositedShares;
    uint256[] private claimedAmounts;
    uint256[] private withdrawnAmounts0;
    uint256[] private withdrawnAmounts1;
    uint256[] private withdrawnShares;

    IERC20 token0;
    IERC20 token1;

    function __SolvencyRunner_init(ICore core_, ILpWrapper wrapper_) internal {
        delete depositors;
        delete depositedAmounts0;
        delete depositedAmounts1;
        delete depositedShares;
        delete claimedAmounts;
        delete withdrawnAmounts0;
        delete withdrawnAmounts1;
        delete withdrawnShares;

        _core = core_;
        _wrapper = wrapper_;

        token0 = _wrapper.token0();
        token1 = _wrapper.token1();
    }

    function calculateTvl()
        internal
        view
        returns (uint256 amount0, uint256 amount1, uint256 totalSupply)
    {
        ICore.ManagedPositionInfo memory info = _core.managedPositionAt(_wrapper.positionId());
        uint256[] memory tokenIds = info.ammPositionIds;
        uint256 length = tokenIds.length;
        totalSupply = _wrapper.totalSupply();
        IAmmModule ammModule = _core.ammModule();
        (uint160 sqrtPriceX96,,,,,) = ICLPool(info.pool).slot0();
        for (uint256 i = 0; i < length; i++) {
            (uint256 position0, uint256 position1) =
                ammModule.tvl(tokenIds[i], sqrtPriceX96, info.callbackParams, new bytes(0));
            amount0 += position0;
            amount1 += position1;
        }
    }

    function transitiomRandomDeposit() internal {
        uint256 userIndex;
        if (depositors.length == 0 || rnd.randBool()) {
            userIndex = depositors.length;
            depositors.push(rnd.randAddress());
            depositedAmounts0.push(0);
            depositedAmounts1.push(0);
            depositedShares.push(0);
            claimedAmounts.push(0);
            withdrawnAmounts0.push(0);
            withdrawnAmounts1.push(0);
            withdrawnShares.push(0);
        } else {
            userIndex = rnd.randInt(depositors.length - 1);
        }
        address user = depositors[userIndex];

        uint256 lpAmount = rnd.randAmountD18();
        (uint256 totalAmount0, uint256 totalAmount1, uint256 totalSupply) = calculateTvl();
        uint256 amount0 = totalAmount0 * lpAmount / totalSupply * 20005 / 10000 + 100; // + 0.05% + dust due to roundings
        uint256 amount1 = totalAmount1 * lpAmount / totalSupply * 20005 / 10000 + 100;

        vm.startPrank(user);
        deal(address(token0), user, amount0);
        deal(address(token1), user, amount1);

        token0.safeIncreaseAllowance(address(_wrapper), amount0);
        token1.safeIncreaseAllowance(address(_wrapper), amount1);

        (uint256 actualAmount0, uint256 actualAmount1, uint256 actualLpAmount) =
            _wrapper.deposit(amount0, amount1, lpAmount, user, type(uint256).max);

        depositedAmounts0[userIndex] += actualAmount0;
        depositedAmounts1[userIndex] += actualAmount1;
        depositedShares[userIndex] += actualLpAmount;

        if (actualAmount0 != amount0) {
            token0.forceApprove(address(_wrapper), 0);
        }

        if (actualAmount1 != amount1) {
            token1.forceApprove(address(_wrapper), 0);
        }

        vm.stopPrank();
    }

    function transition_random_withdrawal() internal {
        uint256 holders = 0;
        for (uint256 i = 0; i < depositors.length; i++) {
            if (_wrapper.balanceOf(depositors[i]) != 0) {
                holders++;
            }
        }
        if (holders == 0) {
            return;
        }
        uint256 holderIndex = rnd.randInt(holders - 1);
        holders = 0;
        uint256 userIndex = 0;
        for (uint256 i = 0; i < depositors.length; i++) {
            if (_wrapper.balanceOf(depositors[i]) == 0) {
                continue;
            }
            if (holderIndex + 1 == holders) {
                userIndex = i;
                break;
            }
            holders++;
        }
        address user = depositors[userIndex];
        uint256 lpAmount = rnd.randInt(_wrapper.balanceOf(user));

        (uint256 totalAmount0, uint256 totalAmount1, uint256 totalSupply) = calculateTvl();
        uint256 minAmount0 = (totalAmount0 * lpAmount / totalSupply) * 9995 / 10000; // 0.05% slippage due to roundings
        uint256 minAmount1 = (totalAmount1 * lpAmount / totalSupply) * 9995 / 10000;

        (uint256 amount0, uint256 amount1, uint256 actualLpAmount) =
            _wrapper.withdraw(lpAmount, minAmount0, minAmount1, user, type(uint256).max);
        withdrawnAmounts0[userIndex] += amount0;
        withdrawnAmounts1[userIndex] += amount1;
        withdrawnShares[userIndex] += actualLpAmount;
    }

    function _runSolvency(Transition[] memory transitions) internal {
        for (uint256 i = 0; i < transitions.length; i++) {
            Transition transition = transitions[i];
            if (transition == Transition.DEPOSIT) {
                transitiomRandomDeposit();
            }
        }
    }

    function testSolvencyRunner() internal pure {}
}
