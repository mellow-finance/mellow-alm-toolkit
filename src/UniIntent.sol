// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/external/univ3/IUniswapV3Factory.sol";

import "./interfaces/IUniIntent.sol";

import "./libraries/external/OracleLibrary.sol";
import "./libraries/external/PositionValue.sol";

import "./utils/DefaultAccessControl.sol";

contract UniIntent is DefaultAccessControl, IUniIntent {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public constant D4 = 1e4;
    uint256 public constant Q96 = 2 ** 96;
    uint32 public constant DEFAULT_TIMESPAN = 60;

    NftInfo[] private _nfts;
    mapping(address => bytes) public customSecurityParams;
    bool public operatorFlag;

    INonfungiblePositionManager public immutable positionManager;
    IUniswapV3Factory public immutable factory;

    mapping(address => EnumerableSet.UintSet) private _userIds;

    constructor(
        INonfungiblePositionManager positionManager_,
        IUniswapV3Factory factory_,
        address admin_
    ) DefaultAccessControl(admin_) {
        positionManager = positionManager_;
        factory = factory_;
    }

    function nfts(uint256 index) public view returns (NftInfo memory) {
        return _nfts[index];
    }

    function getUserIds(
        address user
    ) external view returns (uint256[] memory ids) {
        return _userIds[user].values();
    }

    function setOperatorFlag(bool operatorFlag_) external {
        _requireAdmin();
        operatorFlag = operatorFlag_;
    }

    function setCustomSecurityParams(
        address[] memory pools,
        uint32[][] memory timespans
    ) external {
        _requireAdmin();
        for (uint256 i = 0; i < pools.length; i++) {
            customSecurityParams[pools[i]] = abi.encode(timespans[i]);
        }
    }

    function setPositionParams(
        uint256 id,
        int24 tickNeighborhood,
        uint16 slippageD4,
        int24 maxDeviation,
        uint128 minLiquidityGross,
        uint32[] memory timespans
    ) external {
        NftInfo memory info = _nfts[id];
        if (info.owner != msg.sender) revert("Forbidden");
        if (info.tickUpper - info.tickLower < 2 * tickNeighborhood)
            revert("Invalid params");
        info.tickNeighborhood = tickNeighborhood;
        info.slippageD4 = slippageD4;
        info.maxDeviation = maxDeviation;
        info.minLiquidityGross = minLiquidityGross;
        info.timespans = timespans;
        _nfts[id] = info;
    }

    function deposit(
        DepositParams memory params
    ) external returns (uint256 id) {
        /// throws 'Invalid token ID' if no such tokenId
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,

        ) = positionManager.positions(params.tokenId);
        int24 width = tickUpper - tickLower;
        if (
            params.slippageD4 * 4 > D4 ||
            width < 2 * params.tickNeighborhood ||
            width < params.maxDeviation ||
            params.slippageD4 == 0
        ) revert("Invalid parameters");
        address pool = factory.getPool(token0, token1, fee);
        if (pool == address(0)) revert("Pool not found");
        if (params.tokenId == 0 || params.tokenId > type(uint80).max)
            revert("Invalid tokenId");
        if (liquidity == 0) revert("Zero liquidity");

        positionManager.transferFrom(
            params.owner,
            address(this),
            params.tokenId
        );
        id = _nfts.length;
        _userIds[params.owner].add(id);
        _nfts.push(
            NftInfo({
                owner: params.owner,
                tickNeighborhood: params.tickNeighborhood,
                tokenId: uint80(params.tokenId),
                pool: pool,
                tickSpacing: IUniswapV3Pool(pool).tickSpacing(),
                tickLower: tickLower,
                tickUpper: tickUpper,
                slippageD4: params.slippageD4,
                maxDeviation: params.maxDeviation,
                minLiquidityGross: params.minLiquidityGross,
                timespans: params.timespans
            })
        );
    }

    function withdraw(uint256 id, address to) external {
        NftInfo memory nftInfo = _nfts[id];
        require(nftInfo.owner == msg.sender && nftInfo.tokenId != 0);
        _userIds[nftInfo.owner].remove(id);
        delete _nfts[id];
        positionManager.safeTransferFrom(address(this), to, nftInfo.tokenId);
    }

    function getTarget(
        NftInfo memory info,
        int24 tick
    )
        public
        view
        returns (bool isRebalanceRequired, TargetNftInfo memory target)
    {
        if (
            tick >= info.tickLower + info.tickNeighborhood &&
            tick <= info.tickUpper - info.tickNeighborhood
        ) {
            return (false, target);
        }
        {
            (uint128 liquidityGross, , , , , , , ) = IUniswapV3Pool(info.pool)
                .ticks(tick);
            if (liquidityGross < info.minLiquidityGross) return (false, target);
        }
        int24 width = info.tickUpper - info.tickLower;
        target.tickLower = tick - width / 2;
        int24 remainder = target.tickLower % info.tickSpacing;
        if (remainder < 0) remainder += info.tickSpacing;
        target.tickLower -= remainder;
        target.tickUpper = target.tickLower + width;

        isRebalanceRequired = true;

        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);
        uint256 priceX96 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, Q96);

        (uint256 amount0, uint256 amount1) = PositionValue.total(
            positionManager,
            info.tokenId,
            sqrtRatioX96,
            IUniswapV3Pool(info.pool)
        );
        uint256 currentCapital = FullMath.mulDiv(amount0, priceX96, Q96) +
            amount1;

        (uint256 target0, uint256 target1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtRatioX96,
                TickMath.getSqrtRatioAtTick(target.tickLower),
                TickMath.getSqrtRatioAtTick(target.tickUpper),
                uint128(Q96)
            );
        uint256 targetCapitalQ96 = FullMath.mulDiv(target0, priceX96, Q96) +
            target1;

        target.minLiquidity = uint128(
            FullMath.mulDiv(Q96, currentCapital, targetCapitalQ96)
        );
        target.minLiquidity = uint128(
            FullMath.mulDiv(target.minLiquidity, D4 - info.slippageD4, D4)
        );
    }

    function checkTicks(
        int24 a,
        int24 b,
        int24 maxDeviation
    ) public pure returns (bool) {
        if (a - b > maxDeviation) return false;
        if (b - a > maxDeviation) return false;
        return true;
    }

    function ensureNoMEV(
        NftInfo memory nftInfo,
        int24 spotTick,
        int24 offchainTick
    ) public view {
        uint32[] memory timespans;
        if (nftInfo.timespans.length != 0) {
            timespans = nftInfo.timespans;
        } else {
            bytes memory data = customSecurityParams[nftInfo.pool];
            if (data.length != 0) {
                timespans = abi.decode(data, (uint32[]));
            } else {
                timespans = new uint32[](2);
                timespans[0] = DEFAULT_TIMESPAN;
            }
        }
        (int24[] memory averageTicks, bool withFail) = OracleLibrary
            .consultMultiple(nftInfo.pool, timespans);
        if (withFail) revert("Not enough observations");
        int24 maxDeviation = nftInfo.maxDeviation;
        bool isPoolStable = checkTicks(spotTick, offchainTick, maxDeviation);
        for (uint256 i = 0; i < averageTicks.length && isPoolStable; i++) {
            isPoolStable =
                isPoolStable &&
                checkTicks(averageTicks[i], spotTick, maxDeviation);
            isPoolStable =
                isPoolStable &&
                checkTicks(averageTicks[i], offchainTick, maxDeviation);
        }
        if (!isPoolStable) revert("Unstable pool");
    }

    function rebalance(RebalanceParams memory params) external {
        if (operatorFlag) {
            _requireAtLeastOperator();
        }

        TargetNftInfo[] memory targets = new TargetNftInfo[](params.ids.length);
        uint256 iterator = 0;
        for (uint256 i = 0; i < params.ids.length; i++) {
            uint256 id = params.ids[i];
            NftInfo memory nftInfo = _nfts[id];
            (, int24 tick, , , , , ) = IUniswapV3Pool(nftInfo.pool).slot0();
            ensureNoMEV(nftInfo, tick, params.offchainTicks[i]);
            (bool flag, TargetNftInfo memory target) = getTarget(nftInfo, tick);
            if (!flag) continue;
            target.id = id;
            target.nftInfo = nftInfo;
            targets[iterator++] = target;
            positionManager.approve(params.callback, nftInfo.tokenId);
        }

        assembly {
            mstore(targets, iterator)
        }

        uint256[] memory newTokenIds = IUniIntentCallback(params.callback).call(
            params.data,
            targets
        );
        require(newTokenIds.length == iterator);
        for (uint256 i = 0; i < iterator; i++) {
            TargetNftInfo memory target = targets[i];
            (
                ,
                ,
                address token0,
                address token1,
                uint24 fee,
                int24 tickLower,
                int24 tickUpper,
                uint128 liquidity,
                ,
                ,
                ,

            ) = positionManager.positions(newTokenIds[i]);
            require(
                liquidity >= target.minLiquidity &&
                    tickLower == target.tickLower &&
                    tickUpper == target.tickUpper &&
                    factory.getPool(token0, token1, fee) == target.nftInfo.pool
            );
            positionManager.transferFrom(
                params.callback,
                address(this),
                newTokenIds[i]
            );
            uint256 id = target.id;
            NftInfo memory nftInfo = _nfts[id];
            nftInfo.tickLower = tickLower;
            nftInfo.tickUpper = tickUpper;
            nftInfo.tokenId = uint80(newTokenIds[i]);
            _nfts[id] = nftInfo;
        }
    }
}
