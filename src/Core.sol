// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./interfaces/ICore.sol";

import "./libraries/external/FullMath.sol";

import "./utils/DefaultAccessControl.sol";

contract Core is ICore, DefaultAccessControl, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public constant D9 = 1e9;
    uint256 public constant Q96 = 2 ** 96;

    /// @inheritdoc ICore
    IAmmModule public immutable ammModule;
    /// @inheritdoc ICore
    IOracle public immutable oracle;
    /// @inheritdoc ICore
    IStrategyModule public immutable strategyModule;
    /// @inheritdoc ICore
    bool public operatorFlag;

    bytes private _protocolParams;
    ManagedPositionInfo[] private _positions;
    mapping(address => EnumerableSet.UintSet) private _userIds;

    /**
     * @dev Constructor function for the Core contract.
     * @param ammModule_ The address of the AMM module contract.
     * @param strategyModule_ The address of the strategy module contract.
     * @param oracle_ The address of the oracle contract.
     * @param admin_ The address of the admin for the Core contract.
     */
    constructor(
        IAmmModule ammModule_,
        IStrategyModule strategyModule_,
        IOracle oracle_,
        address admin_
    ) DefaultAccessControl(admin_) {
        ammModule = ammModule_;
        strategyModule = strategyModule_;
        oracle = oracle_;
    }

    /// @inheritdoc ICore
    function managedPositionAt(
        uint256 id
    ) public view override returns (ManagedPositionInfo memory) {
        return _positions[id];
    }

    /// @inheritdoc ICore
    function positionCount() public view override returns (uint256) {
        return _positions.length;
    }

    /// @inheritdoc ICore
    function getUserIds(
        address user
    ) external view override returns (uint256[] memory ids) {
        return _userIds[user].values();
    }

    /// @inheritdoc ICore
    function protocolParams() external view override returns (bytes memory) {
        return _protocolParams;
    }

    /// @inheritdoc ICore
    function setOperatorFlag(
        bool operatorFlag_
    ) external override nonReentrant {
        _requireAdmin();
        operatorFlag = operatorFlag_;
    }

    /// @inheritdoc ICore
    function setProtocolParams(
        bytes memory params
    ) external override nonReentrant {
        _requireAdmin();
        ammModule.validateProtocolParams(params);
        _protocolParams = params;
    }

    /// @inheritdoc ICore
    function setPositionParams(
        uint256 id,
        uint32 slippageD9,
        bytes memory callbackParams,
        bytes memory strategyParams,
        bytes memory securityParams
    ) external override nonReentrant {
        ManagedPositionInfo memory info = _positions[id];
        if (info.owner != msg.sender) revert Forbidden();
        ammModule.validateCallbackParams(callbackParams);
        strategyModule.validateStrategyParams(strategyParams);
        oracle.validateSecurityParams(securityParams);
        if (slippageD9 > D9 / 4 || slippageD9 == 0) revert InvalidParams();
        info.callbackParams = callbackParams;
        info.strategyParams = strategyParams;
        info.securityParams = securityParams;
        info.slippageD9 = slippageD9;
        _positions[id] = info;
    }

    /// @inheritdoc ICore
    function deposit(
        DepositParams memory params
    ) external override nonReentrant returns (uint256 id) {
        ammModule.validateCallbackParams(params.callbackParams);
        strategyModule.validateStrategyParams(params.strategyParams);
        oracle.validateSecurityParams(params.securityParams);
        if (params.slippageD9 > D9 / 4 || params.slippageD9 == 0)
            revert InvalidParams();

        address pool;
        bytes memory protocolParams_ = _protocolParams;
        bool hasLiquidity = false;
        for (uint256 i = 0; i < params.ammPositionIds.length; i++) {
            uint256 tokenId = params.ammPositionIds[i];
            if (tokenId == 0) revert InvalidParams();
            IAmmModule.AmmPosition memory position_ = ammModule.getAmmPosition(
                tokenId
            );
            if (position_.liquidity != 0) hasLiquidity = true;
            address pool_ = ammModule.getPool(
                position_.token0,
                position_.token1,
                position_.property
            );
            if (pool_ == address(0)) revert InvalidParams();
            if (i == 0) {
                pool = pool_;
            } else if (pool != pool_) {
                revert InvalidParams();
            }
            _transferFrom(msg.sender, address(this), tokenId);
            _afterRebalance(tokenId, params.callbackParams, protocolParams_);
        }
        if (!hasLiquidity) revert InvalidParams();
        id = _positions.length;
        _userIds[params.owner].add(id);
        _positions.push(
            ManagedPositionInfo({
                owner: params.owner,
                ammPositionIds: params.ammPositionIds,
                pool: pool,
                property: ammModule.getProperty(pool),
                slippageD9: params.slippageD9,
                callbackParams: params.callbackParams,
                strategyParams: params.strategyParams,
                securityParams: params.securityParams
            })
        );
    }

    /// @inheritdoc ICore
    function withdraw(uint256 id, address to) external override nonReentrant {
        ManagedPositionInfo memory info = _positions[id];
        if (info.owner != msg.sender) revert Forbidden();
        _userIds[info.owner].remove(id);
        delete _positions[id];
        bytes memory protocolParams_ = _protocolParams;
        for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
            uint256 tokenId = info.ammPositionIds[i];
            _beforeRebalance(tokenId, info.callbackParams, protocolParams_);
            _transferFrom(address(this), to, tokenId);
        }
    }

    /// @inheritdoc ICore
    function rebalance(
        RebalanceParams memory params
    ) external override nonReentrant {
        if (operatorFlag) _requireAtLeastOperator();
        TargetPositionInfo[] memory targets = new TargetPositionInfo[](
            params.ids.length
        );
        uint256 iterator = 0;
        bytes memory protocolParams_ = _protocolParams;
        for (uint256 i = 0; i < params.ids.length; i++) {
            ManagedPositionInfo memory info = _positions[params.ids[i]];
            oracle.ensureNoMEV(info.pool, info.securityParams);
            (bool flag, TargetPositionInfo memory target) = strategyModule
                .getTargets(info, ammModule, oracle);
            if (!flag) continue;
            target.id = params.ids[i];
            target.info = info;
            _validateTarget(target);
            (uint160 sqrtPriceX96, ) = oracle.getOraclePrice(info.pool);
            uint256 priceX96 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, Q96);
            uint256 capitalInToken1 = _preprocess(
                params,
                info,
                protocolParams_,
                sqrtPriceX96,
                priceX96
            );
            uint256 targetCapitalInToken1X96 = _calculateTargetCapitalX96(
                target,
                sqrtPriceX96,
                priceX96
            );
            target.minLiquidities = new uint256[](info.ammPositionIds.length);
            for (uint256 j = 0; j < info.ammPositionIds.length; j++) {
                target.minLiquidities[j] = FullMath.mulDiv(
                    target.liquidityRatiosX96[j],
                    capitalInToken1,
                    targetCapitalInToken1X96
                );
                target.minLiquidities[j] = FullMath.mulDiv(
                    target.minLiquidities[j],
                    D9 - info.slippageD9,
                    D9
                );
            }
            targets[iterator++] = target;
        }

        assembly {
            mstore(targets, iterator)
        }

        uint256[][] memory newAmmPositionIds = IRebalanceCallback(
            params.callback
        ).call(params.data, targets);
        if (newAmmPositionIds.length != iterator) revert InvalidLength();
        for (uint256 i = 0; i < iterator; i++) {
            TargetPositionInfo memory target = targets[i];
            uint256[] memory ammPositionIds = newAmmPositionIds[i];
            if (ammPositionIds.length != target.liquidityRatiosX96.length) {
                revert InvalidLength();
            }
            for (uint256 j = 0; j < ammPositionIds.length; j++) {
                uint256 tokenId = ammPositionIds[j];
                IAmmModule.AmmPosition memory position_ = ammModule
                    .getAmmPosition(tokenId);
                if (
                    position_.liquidity < target.minLiquidities[j] ||
                    position_.tickLower != target.lowerTicks[j] ||
                    position_.tickUpper != target.upperTicks[j] ||
                    ammModule.getPool(
                        position_.token0,
                        position_.token1,
                        position_.property
                    ) !=
                    target.info.pool
                ) revert InvalidParams();
                _transferFrom(params.callback, address(this), tokenId);
                _afterRebalance(
                    tokenId,
                    target.info.callbackParams,
                    protocolParams_
                );

                _emitRebalanceEvent(
                    target.info.pool,
                    target.info.ammPositionIds[j],
                    tokenId
                );
            }
            _positions[target.id].ammPositionIds = ammPositionIds;
        }
    }

    function _emitRebalanceEvent(
        address pool,
        uint256 tokenIdBefore,
        uint256 tokenIdAfter
    ) private {
        IAmmModule.AmmPosition memory info = ammModule.getAmmPosition(
            tokenIdAfter
        );
        (uint160 sqrtPriceX96, ) = oracle.getOraclePrice(pool);
        (uint256 amount0, uint256 amount1) = ammModule.getAmountsForLiquidity(
            info.liquidity,
            sqrtPriceX96,
            info.tickLower,
            info.tickUpper
        );

        emit Rebalance(
            RebalanceEventParams({
                pool: pool,
                ammPositionInfo: info,
                sqrtPriceX96: sqrtPriceX96,
                amount0: amount0,
                amount1: amount1,
                ammPositionIdBefore: tokenIdBefore,
                ammPositionIdAfter: tokenIdAfter
            })
        );
    }

    /// @inheritdoc ICore
    function emptyRebalance(uint256 id) external override nonReentrant {
        ManagedPositionInfo memory params = _positions[id];
        if (params.owner != msg.sender) revert Forbidden();
        bytes memory protocolParams_ = _protocolParams;
        for (uint256 i = 0; i < params.ammPositionIds.length; i++) {
            uint256 tokenId = params.ammPositionIds[i];
            _beforeRebalance(tokenId, params.callbackParams, protocolParams_);
            _afterRebalance(tokenId, params.callbackParams, protocolParams_);
        }
    }

    /// @inheritdoc IERC721Receiver
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _validateTarget(TargetPositionInfo memory target) private pure {
        uint256 n = target.liquidityRatiosX96.length;
        if (n != target.lowerTicks.length) revert InvalidTarget();
        if (n != target.upperTicks.length) revert InvalidTarget();
        if (n != target.info.ammPositionIds.length) revert InvalidTarget();
        uint256 cumulativeLiquidityX96 = 0;
        for (uint256 i = 0; i < n; i++) {
            cumulativeLiquidityX96 += target.liquidityRatiosX96[i];
        }
        if (cumulativeLiquidityX96 != Q96) revert InvalidTarget();
        for (uint256 i = 0; i < n; i++) {
            if (target.lowerTicks[i] >= target.upperTicks[i]) {
                revert InvalidTarget();
            }
        }
    }

    function _calculateTargetCapitalX96(
        TargetPositionInfo memory target,
        uint160 sqrtPriceX96,
        uint256 priceX96
    ) private view returns (uint256 targetCapitalInToken1X96) {
        for (uint256 j = 0; j < target.lowerTicks.length; j++) {
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

    function _preprocess(
        RebalanceParams memory params,
        ManagedPositionInfo memory info,
        bytes memory protocolParams_,
        uint160 sqrtPriceX96,
        uint256 priceX96
    ) private returns (uint256 capitalInToken1) {
        for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
            uint256 tokenId = info.ammPositionIds[i];
            (uint256 amount0, uint256 amount1) = ammModule.tvl(
                tokenId,
                sqrtPriceX96,
                info.callbackParams,
                protocolParams_
            );
            capitalInToken1 +=
                FullMath.mulDiv(amount0, priceX96, Q96) +
                amount1;
            _beforeRebalance(tokenId, info.callbackParams, protocolParams_);
            _transferFrom(address(this), params.callback, tokenId);
        }
    }

    function _transferFrom(address from, address to, uint256 tokenId) private {
        (bool success, ) = address(ammModule).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.transferFrom.selector,
                from,
                to,
                tokenId
            )
        );
        if (!success) revert DelegateCallFailed();
    }

    function _beforeRebalance(
        uint256 tokenId,
        bytes memory callbackParams_,
        bytes memory protocolParams_
    ) private {
        (bool success, ) = address(ammModule).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.beforeRebalance.selector,
                tokenId,
                callbackParams_,
                protocolParams_
            )
        );
        if (!success) revert DelegateCallFailed();
    }

    function _afterRebalance(
        uint256 tokenId,
        bytes memory callbackParams_,
        bytes memory protocolParams_
    ) private {
        (bool success, ) = address(ammModule).delegatecall(
            abi.encodeWithSelector(
                IAmmModule.afterRebalance.selector,
                tokenId,
                callbackParams_,
                protocolParams_
            )
        );
        if (!success) revert DelegateCallFailed();
    }
}
