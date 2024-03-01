// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./interfaces/ICore.sol";

import "./libraries/external/FullMath.sol";

import "./utils/DefaultAccessControl.sol";

contract Core is ICore, DefaultAccessControl, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public constant D4 = 1e4;
    uint256 public constant Q96 = 2 ** 96;

    IAmmModule public immutable ammModule;
    IOracle public immutable oracle;
    IStrategyModule public immutable strategyModule;

    bool public operatorFlag;

    bytes private _protocolParams;
    PositionInfo[] private _positions;
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
    function position(
        uint256 id
    ) public view override returns (PositionInfo memory) {
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
    function setOperatorFlag(bool operatorFlag_) external override {
        _requireAdmin();
        operatorFlag = operatorFlag_;
    }

    /// @inheritdoc ICore
    function setProtocolParams(bytes memory params) external override {
        _requireAdmin();
        ammModule.validateProtocolParams(params);
        _protocolParams = params;
    }

    /// @inheritdoc ICore
    function setPositionParams(
        uint256 id,
        uint16 slippageD4,
        bytes memory callbackParams,
        bytes memory strategyParams,
        bytes memory securityParams
    ) external override {
        PositionInfo memory info = _positions[id];
        if (info.owner != msg.sender) revert Forbidden();
        ammModule.validateCallbackParams(callbackParams);
        strategyModule.validateStrategyParams(strategyParams);
        oracle.validateSecurityParams(securityParams);
        info.strategyParams = strategyParams;
        info.securityParams = securityParams;
        info.callbackParams = callbackParams;
        info.slippageD4 = slippageD4;
        _positions[id] = info;
    }

    /// @inheritdoc ICore
    function deposit(
        DepositParams memory params
    ) external override returns (uint256 id) {
        strategyModule.validateStrategyParams(params.strategyParams);
        oracle.validateSecurityParams(params.securityParams);
        if (params.slippageD4 * 4 > D4 || params.slippageD4 == 0)
            revert InvalidParameters();

        address pool;
        bytes memory protocolParams_ = _protocolParams;
        for (uint256 i = 0; i < params.tokenIds.length; i++) {
            uint256 tokenId = params.tokenIds[i];
            if (tokenId == 0) revert InvalidParameters();
            IAmmModule.Position memory position_ = ammModule.getPositionInfo(
                tokenId
            );
            if (position_.liquidity == 0) revert InvalidParameters();
            address pool_ = ammModule.getPool(
                position_.token0,
                position_.token1,
                position_.property
            );
            if (pool_ == address(0)) revert InvalidParameters();
            if (i == 0) {
                pool = pool_;
            } else if (pool != pool_) {
                revert InvalidParameters();
            }
            _transferFrom(msg.sender, address(this), tokenId);
            _afterRebalance(tokenId, params.callbackParams, protocolParams_);
        }
        id = _positions.length;
        _userIds[params.owner].add(id);
        _positions.push(
            PositionInfo({
                owner: params.owner,
                tokenIds: params.tokenIds,
                pool: pool,
                property: ammModule.getProperty(pool),
                slippageD4: params.slippageD4,
                callbackParams: params.callbackParams,
                strategyParams: params.strategyParams,
                securityParams: params.securityParams
            })
        );
    }

    /// @inheritdoc ICore
    function withdraw(uint256 id, address to) external override {
        PositionInfo memory info = _positions[id];
        if (info.owner != msg.sender) revert Forbidden();
        if (info.tokenIds.length == 0) revert InvalidLength();
        _userIds[info.owner].remove(id);
        delete _positions[id];
        bytes memory protocolParams_ = _protocolParams;
        for (uint256 i = 0; i < info.tokenIds.length; i++) {
            uint256 tokenId = info.tokenIds[i];
            _beforeRebalance(tokenId, info.callbackParams, protocolParams_);
            _transferFrom(address(this), to, tokenId);
        }
    }

    function _prepare(
        RebalanceParams memory params,
        PositionInfo memory info,
        bytes memory protocolParams_,
        uint160 sqrtPriceX96,
        uint256 priceX96
    ) private returns (uint256 capitalInToken1) {
        for (uint256 j = 0; j < info.tokenIds.length; j++) {
            uint256 tokenId = info.tokenIds[j];
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
            TargetPositionInfo memory target;
            ICore.PositionInfo memory info = _positions[params.ids[i]];
            oracle.ensureNoMEV(info.pool, info.securityParams);
            {
                bool flag;
                (flag, target) = strategyModule.getTargets(
                    info,
                    ammModule,
                    oracle
                );
                if (!flag) continue;
            }
            target.id = params.ids[i];
            target.info = info;
            _validateTarget(target);
            (uint160 sqrtPriceX96, ) = oracle.getOraclePrice(info.pool);
            uint256 priceX96 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, Q96);
            uint256 capitalInToken1 = _prepare(
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
            uint256 n = info.tokenIds.length;
            target.minLiquidities = new uint256[](n);
            for (uint256 j = 0; j < n; j++) {
                target.minLiquidities[j] = FullMath.mulDiv(
                    target.liquidityRatiosX96[j],
                    capitalInToken1,
                    targetCapitalInToken1X96
                );
                target.minLiquidities[j] = FullMath.mulDiv(
                    target.minLiquidities[j],
                    D4 - info.slippageD4,
                    D4
                );
            }
            targets[iterator++] = target;
        }

        assembly {
            mstore(targets, iterator)
        }

        uint256[][] memory newTokenIds = IRebalanceCallback(params.callback)
            .call(params.data, targets);
        if (newTokenIds.length != iterator) revert InvalidLength();
        for (uint256 i = 0; i < iterator; i++) {
            TargetPositionInfo memory target = targets[i];
            uint256[] memory tokenIds = newTokenIds[i];

            if (tokenIds.length != target.liquidityRatiosX96.length) {
                revert InvalidLength();
            }
            for (uint256 j = 0; j < tokenIds.length; j++) {
                uint256 tokenId = tokenIds[j];
                IAmmModule.Position memory position_ = ammModule
                    .getPositionInfo(tokenId);
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
                ) revert InvalidParameters();
                _transferFrom(params.callback, address(this), tokenId);
                _afterRebalance(
                    tokenId,
                    target.info.callbackParams,
                    protocolParams_
                );
            }
            _positions[target.id].tokenIds = tokenIds;
        }
    }

    /// @inheritdoc ICore
    function emptyRebalance(uint256 id) external override {
        PositionInfo memory params = _positions[id];
        if (params.owner != msg.sender) revert Forbidden();
        bytes memory protocolParams_ = _protocolParams;
        for (uint256 i = 0; i < params.tokenIds.length; i++) {
            uint256 tokenId = params.tokenIds[i];
            if (tokenId == 0) revert InvalidParameters();
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

    function _validateTarget(TargetPositionInfo memory target) private pure {
        uint256 n = target.liquidityRatiosX96.length;

        if (n != target.lowerTicks.length) revert InvalidTarget();
        if (n != target.upperTicks.length) revert InvalidTarget();
        if (n != target.info.tokenIds.length) revert InvalidTarget();

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
}
