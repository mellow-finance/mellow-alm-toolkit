// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Fixture.sol";

/// @title LpWrapper AERO reward flow (real on-chain gauge)
/// @notice End-to-end tests proving an LpWrapper accrues and pays out AERO emissions,
///         driven entirely by the REAL gauge state at the pinned Base fork block — no
///         simulated `notifyRewardAmount`. They also pin the two independent conditions
///         that left the Base WETH/USDC deployment (LpWrapper 0x64838D02..) earning
///         nothing for 44 days:
///           (1) the pool's gauge was not funded (pool had 0 votes), and
///           (2) the managed position was out of range.
///
///         Reward chain under test:
///           LpWrapper.getRewards -> VeloFarm._collectRewards -> Core.collectRewards
///           -> VeloAmmModule.collectRewards -> CLGauge.getReward(tokenId)
///           -> AERO to farm -> VeloFarm.distribute -> per-user accrual.
///
/// @dev Pinned to Base fork block 44984226 (Tue 21 Apr 2026 07:49 UTC) via
///      `npm run test:base:unit`. The WETH/ZRO tickSpacing-100 pool is a real Aerodrome
///      pool whose gauge is alive and ACTIVELY streaming AERO at that block
///      (rewardRate 5.2e16/s, ~40h left in the epoch) — a genuine "pool with rewards".
///      We deliberately use ZRO (not USDC) as the paired token: USDC's FiatToken proxy
///      defeats forge's `deal` storage probe, while WETH/ZRO funds cleanly.
contract LpWrapperRewardsTest is Fixture {
    using SafeERC20 for IERC20;

    address internal constant USER = address(0xA11CE);

    /// Real Base pool with an alive, actively funded AERO gauge at the fork block.
    ICLPool internal fundedPool;

    CoreDeployment internal contracts;

    function setUp() external override {
        TEST_ENV = true;
        contracts = deployContracts();
        fundedPool = ICLPool(factory.getPool(Constants.BASE_WETH, Constants.BASE_ZRO, TICK_SPACING));
    }

    /*//////////////////////////////////////////////////////////////
                                helpers
    //////////////////////////////////////////////////////////////*/

    function deployWrapper(ICLPool pool) internal returns (ILpWrapper lpWrapper) {
        (lpWrapper,) = deployLpWrapper(pool, contracts);
        require(address(lpWrapper) != address(0), "strategy deploy failed");
    }

    /// @dev Deposit liquidity into the wrapper on behalf of `user`, minting LP tokens.
    function depositFor(ILpWrapper lpWrapper, ICLPool pool, address user, uint256 lpAmount)
        internal
    {
        deal(pool.token0(), user, 1 ether);
        deal(pool.token1(), user, 1 ether);
        vm.startPrank(user);
        IERC20(pool.token0()).safeIncreaseAllowance(address(lpWrapper), 1 ether);
        IERC20(pool.token1()).safeIncreaseAllowance(address(lpWrapper), 1 ether);
        lpWrapper.mint(
            ILpWrapper.MintParams({
                lpAmount: lpAmount,
                amount0Max: 1 ether,
                amount1Max: 1 ether,
                recipient: user,
                deadline: block.timestamp
            })
        );
        vm.stopPrank();
    }

    function stakedTokenId(ILpWrapper lpWrapper) internal view returns (uint256) {
        return contracts.core.managedPositionAt(lpWrapper.positionId()).ammPositionIds[0];
    }

    /*//////////////////////////////////////////////////////////////
                             precondition
    //////////////////////////////////////////////////////////////*/

    /// Precondition (correct in production): the managed NFT is staked into the gauge,
    /// otherwise it can never receive emissions. `afterRebalance` stakes only when the
    /// gauge is alive.
    function testManagedPositionIsStakedInGauge() external {
        ILpWrapper lpWrapper = deployWrapper(fundedPool);
        uint256 tokenId = stakedTokenId(lpWrapper);
        assertEq(
            positionManager.ownerOf(tokenId),
            fundedPool.gauge(),
            "managed position must be staked in the gauge"
        );
        assertTrue(
            ICLGauge(fundedPool.gauge()).stakedContains(address(contracts.core), tokenId),
            "gauge must track the position as staked by Core"
        );
    }

    /*//////////////////////////////////////////////////////////////
              happy path: earns REAL AERO from a funded gauge
    //////////////////////////////////////////////////////////////*/

    /// A depositor on a funded, in-range pool accrues real AERO and can claim it. No
    /// emissions are simulated: the gauge's real on-chain rewardRate drives accrual
    /// across the skipped time. This is exactly the outcome missing in production.
    function testEarnsRealAeroOnFundedPool() external {
        ILpWrapper lpWrapper = deployWrapper(fundedPool);
        ICLGauge gauge = ICLGauge(fundedPool.gauge());
        address aero = gauge.rewardToken();
        assertEq(aero, Constants.BASE_REWARD_AERO, "reward token should be AERO");

        // Sanity: this is a genuinely funded gauge at the fork block.
        assertTrue(gauge.voter().isAlive(address(gauge)), "gauge must be alive");
        assertGt(gauge.periodFinish(), block.timestamp, "gauge must have an active epoch");

        depositFor(lpWrapper, fundedPool, USER, 0.99 ether);
        assertEq(positionManager.ownerOf(stakedTokenId(lpWrapper)), address(gauge), "staked");

        // Accrue within the active epoch (periodFinish ~40h out; minStakeTimes is 10s).
        skip(12 hours);

        uint256 balBefore = IERC20(aero).balanceOf(USER);
        vm.prank(USER);
        uint256 claimed = lpWrapper.getRewards(USER);

        assertGt(claimed, 0, "in-range staker on a funded gauge must earn real AERO");
        assertEq(
            IERC20(aero).balanceOf(USER) - balBefore, claimed, "claimed AERO must reach the user"
        );
    }

    /// `earned()` only reflects emissions after they are pulled from the gauge into the
    /// farm via `collectRewards`/`distribute`. Documents why querying `earned()` on an
    /// un-poked wrapper can read 0 while the gauge holds pending rewards.
    function testEarnedBecomesPositiveAfterCollect() external {
        ILpWrapper lpWrapper = deployWrapper(fundedPool);
        depositFor(lpWrapper, fundedPool, USER, 0.99 ether);
        skip(12 hours);

        lpWrapper.collectRewards();
        assertGt(lpWrapper.earned(USER), 0, "earned should reflect distributed rewards");
    }

    /*//////////////////////////////////////////////////////////////
                  regression: production failure modes
    //////////////////////////////////////////////////////////////*/

    /// Regression for production failure #1 (the incident root cause): once the gauge's
    /// epoch ends with no re-funding (the on-chain analogue of a pool that stopped
    /// receiving votes), it stays alive but unfunded — `left() == 0`, `periodFinish` in
    /// the past — and a correctly-staked, in-range position earns nothing no matter how
    /// long it stays staked.
    function testEarnsNothingAfterGaugeEpochEndsUnfunded() external {
        ICLGauge gauge = ICLGauge(fundedPool.gauge());

        // Advance past the funded epoch; no actor re-notifies the gauge on the fork.
        vm.warp(gauge.periodFinish() + 1);
        assertTrue(gauge.voter().isAlive(address(gauge)), "gauge still alive (so it stakes)");
        assertEq(gauge.left(), 0, "gauge has nothing left to distribute");
        assertLt(gauge.periodFinish(), block.timestamp, "gauge epoch already ended");

        ILpWrapper lpWrapper = deployWrapper(fundedPool);
        depositFor(lpWrapper, fundedPool, USER, 0.99 ether);

        // Wiring is fine: the position is correctly staked and in range.
        assertEq(positionManager.ownerOf(stakedTokenId(lpWrapper)), address(gauge), "staked");

        skip(7 days);

        vm.prank(USER);
        uint256 claimed = lpWrapper.getRewards(USER);
        assertEq(claimed, 0, "unfunded gauge: no AERO can be earned regardless of time staked");
    }

    /// Regression for production failure #2: a staked position that is OUT OF RANGE earns
    /// no emissions even while the gauge is actively funded.
    function testOutOfRangePositionEarnsNothing() external {
        ILpWrapper lpWrapper = deployWrapper(fundedPool);
        ICLGauge gauge = ICLGauge(fundedPool.gauge());
        address aero = gauge.rewardToken();

        depositFor(lpWrapper, fundedPool, USER, 0.99 ether);

        // Push spot just below the position's range so the staked liquidity is inactive
        // for the whole accrual window (no in-range time elapses first).
        IAmmModule.AmmPosition memory p =
            contracts.ammModule.getAmmPosition(stakedTokenId(lpWrapper));
        movePrice(fundedPool, TickMath.getSqrtRatioAtTick(p.tickLower - 10));

        skip(12 hours);

        vm.prank(USER);
        uint256 claimed = lpWrapper.getRewards(USER);

        assertEq(claimed, 0, "out-of-range position must not earn emissions");
        assertEq(IERC20(aero).balanceOf(USER), 0, "no AERO should reach the user");
    }
}
