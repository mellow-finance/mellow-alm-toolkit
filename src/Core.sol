// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./interfaces/ICore.sol";

import "./interfaces/modules/IAmmModule.sol";
import "./interfaces/modules/IStrategyModule.sol";

import "./interfaces/oracles/IOracle.sol";

import "./libraries/external/FullMath.sol";

import "./utils/DefaultAccessControl.sol";

contract Core is DefaultAccessControl, ICore {
    using EnumerableSet for EnumerableSet.UintSet;

    error DelegateCallFailed();
    error InvalidParameters();
    error InvalidLength();

    uint256 public constant D4 = 1e4;
    uint256 public constant Q96 = 2 ** 96;

    IAmmModule public immutable ammModule;
    IOracle public immutable oracle;
    IStrategyModule public immutable strategyModule;
    address public immutable positionManager;

    bool public operatorFlag;

    NftsInfo[] private _nfts;
    mapping(address => EnumerableSet.UintSet) private _userIds;

    constructor(
        IAmmModule ammModule_,
        IStrategyModule strategyModule_,
        IOracle oracle_,
        address positionManager_,
        address admin_
    ) DefaultAccessControl(admin_) {
        ammModule = ammModule_;
        strategyModule = strategyModule_;
        oracle = oracle_;
        positionManager = positionManager_;
    }

    function nfts(
        uint256 index
    ) public view override returns (NftsInfo memory) {
        return _nfts[index];
    }

    function getUserIds(
        address user
    ) external view override returns (uint256[] memory ids) {
        return _userIds[user].values();
    }

    function setOperatorFlag(bool operatorFlag_) external override {
        _requireAdmin();
        operatorFlag = operatorFlag_;
    }

    function setPositionParams(
        uint256 id,
        uint16 slippageD4,
        bytes memory strategyParams,
        bytes memory securityParams
    ) external override {
        NftsInfo memory info = _nfts[id];
        if (info.owner != msg.sender) revert Forbidden();
        strategyModule.validateStrategyParams(strategyParams);
        oracle.validateSecurityParams(securityParams);
        info.strategyParams = strategyParams;
        info.securityParams = securityParams;
        info.slippageD4 = slippageD4;
        _nfts[id] = info;
    }

    function deposit(
        DepositParams memory params
    ) external override returns (uint256 id) {
        strategyModule.validateStrategyParams(params.strategyParams);
        oracle.validateSecurityParams(params.securityParams);
        if (params.slippageD4 * 4 > D4 || params.slippageD4 == 0)
            revert InvalidParameters();

        address pool;
        for (uint256 i = 0; i < params.tokenIds.length; i++) {
            uint256 tokenId = params.tokenIds[i];
            if (tokenId == 0 || tokenId > type(uint80).max) {
                revert InvalidParameters();
            }

            IAmmModule.Position memory position = ammModule.getPositionInfo(
                tokenId
            );

            if (position.liquidity == 0) revert InvalidParameters();
            address positionPool = ammModule.getPool(
                position.token0,
                position.token1,
                position.property
            );

            if (positionPool == address(0)) {
                revert InvalidParameters();
            }

            if (pool == address(0)) {
                pool = positionPool;
            } else if (pool != positionPool) {
                revert InvalidParameters();
            }

            IERC721(positionManager).transferFrom(
                params.owner,
                address(this),
                tokenId
            );

            {
                (bool success, ) = address(ammModule).delegatecall(
                    abi.encodeWithSelector(
                        IAmmModule.afterRebalance.selector,
                        params.farm,
                        params.vault,
                        tokenId
                    )
                );
                if (!success) revert DelegateCallFailed();
            }
        }
        id = _nfts.length;
        _userIds[params.owner].add(id);
        _nfts.push(
            NftsInfo({
                owner: params.owner,
                tokenIds: params.tokenIds,
                pool: pool,
                farm: params.farm,
                vault: params.vault,
                property: ammModule.getProperty(pool),
                slippageD4: params.slippageD4,
                strategyParams: params.strategyParams,
                securityParams: params.securityParams
            })
        );
    }

    function withdraw(uint256 id, address to) external override {
        NftsInfo memory info = _nfts[id];
        if (info.tokenIds.length == 0) revert();
        require(info.owner == msg.sender);
        _userIds[info.owner].remove(id);
        delete _nfts[id];
        for (uint256 i = 0; i < info.tokenIds.length; i++) {
            uint256 tokenId = info.tokenIds[i];
            (bool success, ) = address(ammModule).delegatecall(
                abi.encodeWithSelector(
                    IAmmModule.beforeRebalance.selector,
                    info.farm,
                    info.vault,
                    tokenId
                )
            );
            if (!success) revert DelegateCallFailed();
            IERC721(positionManager).transferFrom(address(this), to, tokenId);
        }
    }

    function _calculateTargetCapitalX96(
        TargetNftsInfo memory target,
        uint160 sqrtPriceX96,
        uint256 priceX96
    ) private view returns (uint256 targetCapitalInToken1X96) {
        for (uint256 j = 0; j < target.lowerTicks.length; j++) {
            {
                (uint256 amount0, uint256 amount1) = ammModule
                    .getAmountsForLiquidity(
                        uint128(target.liquidityRatiosX96[j]),
                        sqrtPriceX96,
                        target.lowerTicks[j],
                        target.upperTicks[j]
                    );
                targetCapitalInToken1X96 +=
                    FullMath.mulDiv(amount0, priceX96, Q96) +
                    amount1;
            }
        }
    }

    function rebalance(RebalanceParams memory params) external override {
        if (operatorFlag) {
            _requireAtLeastOperator();
        }
        TargetNftsInfo[] memory targets = new TargetNftsInfo[](
            params.ids.length
        );
        uint256 iterator = 0;
        for (uint256 i = 0; i < params.ids.length; i++) {
            uint256 id = params.ids[i];
            NftsInfo memory info = _nfts[id];
            oracle.ensureNoMEV(info.pool, info.securityParams);
            bool flag;
            (flag, targets[iterator]) = strategyModule.getTargets(
                info,
                ammModule,
                oracle
            );
            if (!flag) continue;
            (uint160 sqrtPriceX96, ) = oracle.getOraclePrice(
                info.pool,
                info.securityParams
            );
            uint256 priceX96 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, Q96);
            uint256 capitalInToken1 = 0;
            for (uint256 j = 0; j < info.tokenIds.length; j++) {
                uint256 tokenId = info.tokenIds[j];
                {
                    (uint256 amount0, uint256 amount1) = ammModule.tvl(
                        tokenId,
                        sqrtPriceX96,
                        info.pool,
                        info.farm
                    );
                    capitalInToken1 +=
                        FullMath.mulDiv(amount0, priceX96, Q96) +
                        amount1;
                }
                (bool success, ) = address(ammModule).delegatecall(
                    abi.encodeWithSelector(
                        IAmmModule.beforeRebalance.selector,
                        targets[iterator].info.farm,
                        targets[iterator].info.vault,
                        tokenId
                    )
                );
                if (!success) revert DelegateCallFailed();
                IERC721(positionManager).transferFrom(
                    address(this),
                    params.callback,
                    tokenId
                );
            }

            uint256 targetCapitalInToken1X96 = _calculateTargetCapitalX96(
                targets[iterator],
                sqrtPriceX96,
                priceX96
            );
            targets[iterator].minLiquidities = new uint256[](
                targets[iterator].liquidityRatiosX96.length
            );
            for (
                uint256 j = 0;
                j < targets[iterator].minLiquidities.length;
                j++
            ) {
                targets[iterator].minLiquidities[j] = FullMath.mulDiv(
                    targets[iterator].liquidityRatiosX96[j],
                    capitalInToken1,
                    targetCapitalInToken1X96
                );
                targets[iterator].minLiquidities[j] = FullMath.mulDiv(
                    targets[iterator].minLiquidities[j],
                    D4 - info.slippageD4,
                    D4
                );
            }

            targets[iterator].id = id;
            targets[iterator].info = info;
            iterator++;
        }

        assembly {
            mstore(targets, iterator)
        }

        uint256[][] memory newTokenIds = IRebalanceCallback(params.callback)
            .call(params.data, targets);
        if (newTokenIds.length != iterator) revert InvalidParameters();
        for (uint256 i = 0; i < iterator; i++) {
            TargetNftsInfo memory target = targets[i];
            uint256[] memory tokenIds = newTokenIds[i];

            if (tokenIds.length != target.liquidityRatiosX96.length) {
                revert InvalidLength();
            }
            for (uint256 j = 0; j < tokenIds.length; j++) {
                uint256 tokenId = tokenIds[j];
                IAmmModule.Position memory position = ammModule.getPositionInfo(
                    tokenId
                );
                if (
                    position.liquidity < target.minLiquidities[j] ||
                    position.tickLower != target.lowerTicks[j] ||
                    position.tickUpper != target.upperTicks[j] ||
                    ammModule.getPool(
                        position.token0,
                        position.token1,
                        position.property
                    ) !=
                    target.info.pool
                ) revert InvalidParameters();
                IERC721(positionManager).transferFrom(
                    params.callback,
                    address(this),
                    tokenId
                );
                {
                    (bool success, ) = address(ammModule).delegatecall(
                        abi.encodeWithSelector(
                            IAmmModule.afterRebalance.selector,
                            target.info.farm,
                            target.info.vault,
                            tokenId
                        )
                    );
                    if (!success) revert DelegateCallFailed();
                }
            }
            target.info.tokenIds = tokenIds;
            _nfts[target.id] = target.info;
        }
    }
}
