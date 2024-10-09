// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./StakingRewards.sol";

import "../libraries/external/FullMath.sol";

import "./VeloDeployFactory.sol";

contract VeloSugarHelper {
    VeloDeployFactory public immutable factory;

    struct Lp {
        uint256 amount0;
        uint256 amount1;
        uint256 lpAmount;
        uint256 stakedLpAmount;
        address almFarm;
        address almVault;
        uint256 almFeeD9;
        address rewardToken;
        uint256 rewards;
        uint256 nft;
        address pool;
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        int24 tickSpacing;
        int24 tick;
        uint160 price;
        address gauge;
        bool initialized;
    }

    constructor(address _factory) {
        factory = VeloDeployFactory(_factory);
    }

    function getData(
        address user,
        uint256 id,
        ICore core
    ) public view returns (Lp memory lp) {
        ICore.ManagedPositionInfo memory position = core.managedPositionAt(id);
        IVeloDeployFactory.PoolAddresses memory addresses = factory
            .poolToAddresses(position.pool);
        if (
            addresses.lpWrapper == address(0) ||
            position.owner != addresses.lpWrapper
        ) return lp; // empty response
        if (position.ammPositionIds.length != 1) return lp; // empty response
        StakingRewards farm = StakingRewards(addresses.synthetixFarm);
        lp.lpAmount = IERC20(addresses.lpWrapper).balanceOf(user);
        lp.stakedLpAmount = farm.balanceOf(user);
        lp.rewards = farm.earned(user);
        if (lp.rewards == 0 && lp.stakedLpAmount == 0 && lp.lpAmount == 0)
            return lp; // empty response
        lp.almFarm = addresses.synthetixFarm;
        lp.almVault = addresses.lpWrapper;
        ICLGauge gauge = ICLGauge(ICLPool(position.pool).gauge());
        lp.rewardToken = gauge.rewardToken();
        lp.nft = position.ammPositionIds[0];
        lp.token0 = ICLPool(position.pool).token0();
        lp.token1 = ICLPool(position.pool).token1();
        lp.tickSpacing = ICLPool(position.pool).tickSpacing();
        IAmmModule ammModule = core.ammModule();
        bytes memory protocolParams = core.protocolParams();
        lp.almFeeD9 = abi
            .decode(protocolParams, (IVeloAmmModule.ProtocolParams))
            .feeD9;
        lp.pool = position.pool;
        lp.initialized = true;
        lp.gauge = ICLPool(position.pool).gauge();
        {
            (lp.price, lp.tick, , , , ) = ICLPool(position.pool).slot0();
            (lp.reserve0, lp.reserve1) = ammModule.tvl(
                lp.nft,
                lp.price,
                abi.encode(position.coreParams.callbackParams),
                protocolParams
            );
        }
        uint256 totalSupply = IERC20(addresses.lpWrapper).totalSupply();
        lp.amount0 = FullMath.mulDiv(
            lp.reserve0,
            lp.lpAmount + lp.stakedLpAmount,
            totalSupply
        );
        lp.amount1 = FullMath.mulDiv(
            lp.reserve1,
            lp.lpAmount + lp.stakedLpAmount,
            totalSupply
        );
    }

    function full(address user) public view returns (Lp[] memory data) {
        ICore core = factory.getImmutableParams().core;
        uint256 n = core.positionCount();
        data = new Lp[](n);
        uint256 iterator = 0;
        for (uint256 i = 0; i < n; i++) {
            data[iterator] = getData(user, i, core);
            if (data[iterator].initialized) iterator++;
        }
        if (iterator < n) {
            assembly {
                mstore(data, iterator)
            }
        }
    }

    function all(
        address user,
        uint256 limit,
        uint256 offset
    ) public view returns (Lp[] memory data) {
        Lp[] memory fullData = full(user);
        if (offset > data.length) return new Lp[](0);
        if (offset + limit > data.length) {
            limit = data.length - offset;
        }
        data = new Lp[](limit);
        for (uint256 i = 0; i < limit; i++) {
            data[i] = fullData[offset + i];
        }
    }

    function byIndex(
        uint256 index,
        address user
    ) public view returns (Lp memory lp) {
        Lp[] memory fullData = full(user);
        if (index >= fullData.length) return lp;
        return fullData[index];
    }
}
