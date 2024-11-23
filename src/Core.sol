// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "./interfaces/ICore.sol";

import "./utils/DefaultAccessControl.sol";

contract Core is ICore, DefaultAccessControl, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    uint256 private constant D9 = 1000000000;
    uint256 private constant Q96 = 0x1000000000000000000000000;
    uint256 private constant Q128 = 0x100000000000000000000000000000000;
    uint256 private constant Q192 = 0x1000000000000000000000000000000000000000000000000;

    address public immutable weth;

    /// @inheritdoc ICore
    IAmmModule public immutable ammModule;

    /// @inheritdoc ICore
    IAmmDepositWithdrawModule public immutable ammDepositWithdrawModule;

    /// @inheritdoc ICore
    IOracle public immutable oracle;
    /// @inheritdoc ICore
    IStrategyModule public immutable strategyModule;

    bytes private _protocolParams;
    ManagedPositionInfo[] private _positions;
    mapping(address => EnumerableSet.UintSet) private _userIds;

    /// ---------------------- INITIALIZER FUNCTIONS ----------------------

    /**
     * @dev Constructor function for the Core contract.
     * @param ammModule_ The address of the AMM module contract.
     * @param strategyModule_ The address of the strategy module contract.
     * @param oracle_ The address of the oracle contract.
     * @param admin_ The address of the admin for the Core contract.
     */
    constructor(
        IAmmModule ammModule_,
        IAmmDepositWithdrawModule ammDepositWithdrawModule_,
        IStrategyModule strategyModule_,
        IOracle oracle_,
        address admin_,
        address weth_
    ) initializer {
        __DefaultAccessControl_init(admin_);
        if (
            address(ammModule_) == address(0) || address(ammDepositWithdrawModule_) == address(0)
                || address(strategyModule_) == address(0) || address(oracle_) == address(0)
                || weth_ == address(0)
        ) {
            revert AddressZero();
        }
        ammModule = ammModule_;
        ammDepositWithdrawModule = ammDepositWithdrawModule_;
        strategyModule = strategyModule_;
        oracle = oracle_;
        weth = weth_;
    }

    /// ---------------------- EXTERNAL MUTATING FUNCTIONS ----------------------

    receive() external payable {
        uint256 amount = msg.value;
        IWETH9(weth).deposit{value: amount}();
        IERC20(weth).safeTransfer(tx.origin, amount);
    }

    /// @inheritdoc ICore
    function deposit(DepositParams calldata params)
        external
        override
        nonReentrant
        returns (uint256 id)
    {
        address pool = _getPoolAndValidate(params.ammPositionIds);
        ammModule.validateCallbackParams(pool, params.callbackParams);
        strategyModule.validateStrategyParams(params.strategyParams);
        oracle.validateSecurityParams(params.securityParams);
        if (params.slippageD9 > D9 / 4 || params.slippageD9 == 0 || params.owner == address(0)) {
            revert InvalidParams();
        }

        bytes memory protocolParams_ = _protocolParams;
        for (uint256 i = 0; i < params.ammPositionIds.length; i++) {
            uint256 tokenId = params.ammPositionIds[i];
            _transferFrom(msg.sender, address(this), tokenId);
            _afterRebalance(tokenId, params.callbackParams, protocolParams_);
        }

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
        if (info.owner != msg.sender) {
            revert Forbidden();
        }
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
    function directDeposit(
        uint256 id,
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1,
        uint256 minAmount0,
        uint256 minAmount1
    ) external nonReentrant returns (uint256 actualAmount0, uint256 actualAmount1) {
        ManagedPositionInfo memory info = _positions[id];
        if (info.owner != msg.sender) {
            revert Forbidden();
        }
        bool hasTokenId = false;
        for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
            if (info.ammPositionIds[i] == tokenId) {
                hasTokenId = true;
                break;
            }
        }
        if (!hasTokenId) {
            revert InvalidParams();
        }

        bytes memory protocolParams_ = _protocolParams;
        _beforeRebalance(tokenId, info.callbackParams, protocolParams_);
        IAmmModule.AmmPosition memory position_ = ammModule.getAmmPosition(tokenId);
        bytes memory response = Address.functionDelegateCall(
            address(ammDepositWithdrawModule),
            abi.encodeWithSelector(
                IAmmDepositWithdrawModule.deposit.selector,
                tokenId,
                amount0,
                amount1,
                info.owner,
                position_.token0,
                position_.token1
            )
        );
        if (response.length != 0x40) {
            revert InvalidLength();
        }
        (actualAmount0, actualAmount1) = abi.decode(response, (uint256, uint256));
        if (actualAmount0 < minAmount0 || actualAmount1 < minAmount1) {
            revert InsufficientAmount();
        }
        _afterRebalance(tokenId, info.callbackParams, protocolParams_);
    }

    /// @inheritdoc ICore
    function directWithdraw(
        uint256 id,
        uint256 tokenId,
        uint256 liquidity,
        address to,
        uint256 minAmount0,
        uint256 minAmount1
    ) external nonReentrant returns (uint256 actualAmount0, uint256 actualAmount1) {
        ManagedPositionInfo memory info = _positions[id];
        if (info.owner != msg.sender) {
            revert Forbidden();
        }
        bool hasTokenId = false;
        for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
            if (info.ammPositionIds[i] == tokenId) {
                hasTokenId = true;
                break;
            }
        }
        if (!hasTokenId) {
            revert InvalidParams();
        }

        bytes memory protocolParams_ = _protocolParams;
        _beforeRebalance(tokenId, info.callbackParams, protocolParams_);
        bytes memory response = Address.functionDelegateCall(
            address(ammDepositWithdrawModule),
            abi.encodeWithSelector(
                IAmmDepositWithdrawModule.withdraw.selector, tokenId, liquidity, to
            )
        );
        if (response.length != 0x40) {
            revert InvalidLength();
        }
        (actualAmount0, actualAmount1) = abi.decode(response, (uint256, uint256));
        if (actualAmount0 < minAmount0 || actualAmount1 < minAmount1) {
            revert InsufficientAmount();
        }

        _afterRebalance(tokenId, info.callbackParams, protocolParams_);
    }

    /// @inheritdoc ICore
    function rebalance(RebalanceParams memory params) external override nonReentrant {
        _requireAtLeastOperator();

        ManagedPositionInfo memory info = _positions[params.id];
        oracle.ensureNoMEV(info.pool, info.securityParams);
        (bool isRebalanceNeeded, TargetPositionInfo memory target) =
            strategyModule.getTargets(info, ammModule, oracle);
        if (!isRebalanceNeeded) {
            revert NoRebalanceNeeded();
        }
        target.id = params.id;
        _validateTarget(target);

        (uint160 sqrtPriceX96,) = oracle.getOraclePrice(info.pool);
        bytes memory protocolParams_ = _protocolParams;
        uint256 capital = _preprocess(params, info, protocolParams_, sqrtPriceX96);
        uint256 targetCapitalX96 = _calculateTargetCapitalX96(target, sqrtPriceX96);

        uint256 length = target.liquidityRatiosX96.length;
        target.minLiquidities = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            target.minLiquidities[i] =
                Math.mulDiv(target.liquidityRatiosX96[i], capital, targetCapitalX96);
            target.minLiquidities[i] =
                Math.mulDiv(target.minLiquidities[i], D9 - info.slippageD9, D9);
        }

        uint256[] memory ammPositionIds =
            IRebalanceCallback(params.callback).call(params.data, target, info);

        if (ammPositionIds.length != length) {
            revert InvalidLength();
        }
        IAmmModule.AmmPosition memory position_;
        address this_ = address(this);
        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = ammPositionIds[i];
            position_ = ammModule.getAmmPosition(tokenId);
            if (
                position_.liquidity < target.minLiquidities[i]
                    || position_.tickLower != target.lowerTicks[i]
                    || position_.tickUpper != target.upperTicks[i]
                    || ammModule.getPool(position_.token0, position_.token1, position_.property)
                        != info.pool
            ) {
                revert InvalidParams();
            }
            _transferFrom(params.callback, this_, tokenId);
            _afterRebalance(tokenId, info.callbackParams, protocolParams_);

            _emitRebalanceEvent(
                info.pool, i < info.ammPositionIds.length ? info.ammPositionIds[i] : 0, tokenId
            );
        }
        _positions[target.id].ammPositionIds = ammPositionIds;
    }

    /// @inheritdoc ICore
    function setProtocolParams(bytes memory params) external override nonReentrant {
        _requireAdmin();
        ammModule.validateProtocolParams(params);
        _protocolParams = params;
        emit ProtocolParamsSet(params, msg.sender);
    }

    /// @inheritdoc ICore
    function emptyRebalance(uint256 id) external override nonReentrant {
        ManagedPositionInfo memory params = _positions[id];
        if (params.owner != msg.sender) {
            revert Forbidden();
        }
        bytes memory protocolParams_ = _protocolParams;
        for (uint256 i = 0; i < params.ammPositionIds.length; i++) {
            uint256 tokenId = params.ammPositionIds[i];
            _beforeRebalance(tokenId, params.callbackParams, protocolParams_);
            _afterRebalance(tokenId, params.callbackParams, protocolParams_);
        }
    }

    /// @inheritdoc ICore
    function collectRewards(uint256 id) external override nonReentrant {
        ManagedPositionInfo memory params = _positions[id];
        if (params.owner != msg.sender) {
            revert Forbidden();
        }
        bytes memory protocolParams_ = _protocolParams;
        for (uint256 i = 0; i < params.ammPositionIds.length; i++) {
            uint256 tokenId = params.ammPositionIds[i];
            _collectRewards(tokenId, params.callbackParams, protocolParams_);
        }
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
        if (info.owner != msg.sender) {
            revert Forbidden();
        }
        ammModule.validateCallbackParams(info.pool, callbackParams);
        strategyModule.validateStrategyParams(strategyParams);
        oracle.validateSecurityParams(securityParams);
        if (slippageD9 > D9 / 4 || slippageD9 == 0) {
            revert InvalidParams();
        }
        info.callbackParams = callbackParams;
        info.strategyParams = strategyParams;
        info.securityParams = securityParams;
        info.slippageD9 = slippageD9;
        _positions[id] = info;
        emit PositionParamsSet(
            id, slippageD9, callbackParams, strategyParams, securityParams, msg.sender
        );
    }

    /// ---------------------- EXTERNAL VIEW FUNCTIONS ----------------------

    /// @inheritdoc ICore
    function getUserIds(address user) external view override returns (uint256[] memory ids) {
        return _userIds[user].values();
    }

    /// @inheritdoc ICore
    function protocolParams() external view override returns (bytes memory) {
        return _protocolParams;
    }

    /// @inheritdoc IERC721Receiver
    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @inheritdoc ICore
    function positionCount() public view override returns (uint256) {
        return _positions.length;
    }

    /// @inheritdoc ICore
    function managedPositionAt(uint256 id)
        public
        view
        override
        returns (ManagedPositionInfo memory)
    {
        return _positions[id];
    }

    /// ---------------------- PRIVATE MUTATING FUNCTIONS ----------------------

    function _preprocess(
        RebalanceParams memory params,
        ManagedPositionInfo memory info,
        bytes memory protocolParams_,
        uint160 sqrtPriceX96
    ) private returns (uint256 capital) {
        for (uint256 i = 0; i < info.ammPositionIds.length; i++) {
            uint256 tokenId = info.ammPositionIds[i];
            (uint256 amount0, uint256 amount1) =
                ammModule.tvl(tokenId, sqrtPriceX96, info.callbackParams, protocolParams_);
            capital += _calculateCapital(amount0, amount1, sqrtPriceX96);
            _beforeRebalance(tokenId, info.callbackParams, protocolParams_);
            _transferFrom(address(this), params.callback, tokenId);
        }
    }

    function _transferFrom(address from, address to, uint256 tokenId) private {
        Address.functionDelegateCall(
            address(ammModule),
            abi.encodeWithSelector(IAmmModule.transferFrom.selector, from, to, tokenId)
        );
    }

    function _collectRewards(
        uint256 tokenId,
        bytes memory callbackParams_,
        bytes memory protocolParams_
    ) private {
        Address.functionDelegateCall(
            address(ammModule),
            abi.encodeWithSelector(
                IAmmModule.collectRewards.selector, tokenId, callbackParams_, protocolParams_
            )
        );
    }

    function _beforeRebalance(
        uint256 tokenId,
        bytes memory callbackParams_,
        bytes memory protocolParams_
    ) private {
        Address.functionDelegateCall(
            address(ammModule),
            abi.encodeWithSelector(
                IAmmModule.beforeRebalance.selector, tokenId, callbackParams_, protocolParams_
            )
        );
    }

    function _afterRebalance(
        uint256 tokenId,
        bytes memory callbackParams_,
        bytes memory protocolParams_
    ) private {
        Address.functionDelegateCall(
            address(ammModule),
            abi.encodeWithSelector(
                IAmmModule.afterRebalance.selector, tokenId, callbackParams_, protocolParams_
            )
        );
    }

    function _emitRebalanceEvent(address pool, uint256 tokenIdBefore, uint256 tokenIdAfter)
        private
    {
        IAmmModule.AmmPosition memory info = ammModule.getAmmPosition(tokenIdAfter);
        (uint160 sqrtPriceX96,) = oracle.getOraclePrice(pool);
        (uint256 amount0, uint256 amount1) = ammModule.getAmountsForLiquidity(
            info.liquidity, sqrtPriceX96, info.tickLower, info.tickUpper
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

    /// ---------------------- PRIVATE VIEW FUNCTIONS ----------------------

    function _calculateCapital(uint256 amount0, uint256 amount1, uint256 sqrtPriceX96)
        internal
        pure
        returns (uint256)
    {
        if (sqrtPriceX96 < Q128) {
            return Math.mulDiv(amount0, sqrtPriceX96 * sqrtPriceX96, Q192) + amount1;
        } else {
            /*
                During the calculations below, the following holds true:
                 - `term` is always greater than 1.
                 - the new `sqrtPriceX96` is guaranteed to lie within the range `[Q128 / 2, Q128 - 1]`.
                 - `amount0 * term` might trigger a revert due to overflow, but this will only occur if 
                    `Math.mulDiv(amount0, priceX96, Q96)` would also result in an overflow.
            */
            uint256 term = Math.ceilDiv(sqrtPriceX96, Q128 - 1);
            sqrtPriceX96 /= term;
            return Math.mulDiv(amount0 * term, sqrtPriceX96 * sqrtPriceX96, Q192 / term) + amount1;
        }
    }

    function _calculateTargetCapitalX96(TargetPositionInfo memory target, uint160 sqrtPriceX96)
        private
        view
        returns (uint256 capitalX96)
    {
        for (uint256 j = 0; j < target.lowerTicks.length; j++) {
            (uint256 amount0, uint256 amount1) = ammModule.getAmountsForLiquidity(
                uint128(target.liquidityRatiosX96[j]),
                sqrtPriceX96,
                target.lowerTicks[j],
                target.upperTicks[j]
            );
            capitalX96 += _calculateCapital(amount0, amount1, sqrtPriceX96);
        }
    }

    function _getPoolAndValidate(uint256[] calldata ammPositionIds)
        private
        view
        returns (address pool)
    {
        bool hasLiquidity = false;
        IAmmModule.AmmPosition memory position;
        for (uint256 i = 0; i < ammPositionIds.length; i++) {
            uint256 tokenId = ammPositionIds[i];
            if (tokenId == 0) {
                revert InvalidParams();
            }
            position = ammModule.getAmmPosition(tokenId);
            if (position.liquidity != 0) {
                hasLiquidity = true;
            }
            address pool_ = ammModule.getPool(position.token0, position.token1, position.property);
            if (pool_ == address(0)) {
                revert InvalidParams();
            }
            if (i == 0) {
                pool = pool_;
            } else if (pool != pool_) {
                revert InvalidParams();
            }
        }
        if (!hasLiquidity) {
            revert InvalidParams();
        }
    }

    function _validateTarget(TargetPositionInfo memory target) private pure {
        uint256 n = target.liquidityRatiosX96.length;
        if (n != target.lowerTicks.length) {
            revert InvalidTarget();
        }
        if (n != target.upperTicks.length) {
            revert InvalidTarget();
        }
        uint256 cumulativeLiquidityX96 = 0;
        for (uint256 i = 0; i < n; i++) {
            cumulativeLiquidityX96 += target.liquidityRatiosX96[i];
        }
        if (cumulativeLiquidityX96 != Q96) {
            revert InvalidTarget();
        }
        for (uint256 i = 0; i < n; i++) {
            if (target.lowerTicks[i] >= target.upperTicks[i]) {
                revert InvalidTarget();
            }
        }
    }
}
