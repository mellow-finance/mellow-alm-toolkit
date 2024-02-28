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
    function positionCount() public view returns (uint256) {
        return _positions.length;
    }

    /// @inheritdoc ICore
    function getUserIds(
        address user
    ) external view override returns (uint256[] memory ids) {
        return _userIds[user].values();
    }

    /// @inheritdoc ICore
    function setOperatorFlag(bool operatorFlag_) external override {
        _requireAdmin();
        operatorFlag = operatorFlag_;
    }

    /// @inheritdoc ICore
    function setPositionParams(
        uint256 id,
        uint16 slippageD4,
        bytes memory strategyParams,
        bytes memory securityParams
    ) external override {
        PositionInfo memory info = _positions[id];
        if (info.owner != msg.sender) revert Forbidden();
        strategyModule.validateStrategyParams(strategyParams);
        oracle.validateSecurityParams(securityParams);
        info.strategyParams = strategyParams;
        info.securityParams = securityParams;
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
        for (uint256 i = 0; i < params.tokenIds.length; i++) {
            uint256 tokenId = params.tokenIds[i];
            if (tokenId == 0) {
                revert InvalidParameters();
            }

            IAmmModule.Position memory ammPosition = ammModule.getPositionInfo(
                tokenId
            );

            if (ammPosition.liquidity == 0) revert InvalidParameters();
            address positionPool = ammModule.getPool(
                ammPosition.token0,
                ammPosition.token1,
                ammPosition.property
            );

            if (positionPool == address(0)) {
                revert InvalidParameters();
            }

            if (pool == address(0)) {
                pool = positionPool;
            } else if (pool != positionPool) {
                revert InvalidParameters();
            }

            {
                (bool success, ) = address(ammModule).delegatecall(
                    abi.encodeWithSelector(
                        IAmmModule.transferFrom.selector,
                        msg.sender,
                        address(this),
                        tokenId
                    )
                );
                if (!success) revert DelegateCallFailed();
            }

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
        id = _positions.length;
        _userIds[params.owner].add(id);
        _positions.push(
            PositionInfo({
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

    /// @inheritdoc ICore
    function withdraw(uint256 id, address to) external override {
        PositionInfo memory info = _positions[id];
        if (info.tokenIds.length == 0) revert InvalidLength();
        if (info.owner != msg.sender) revert Forbidden();
        _userIds[info.owner].remove(id);
        delete _positions[id];
        for (uint256 i = 0; i < info.tokenIds.length; i++) {
            uint256 tokenId = info.tokenIds[i];
            {
                (bool success, ) = address(ammModule).delegatecall(
                    abi.encodeWithSelector(
                        IAmmModule.beforeRebalance.selector,
                        info.farm,
                        info.vault,
                        tokenId
                    )
                );
                if (!success) revert DelegateCallFailed();
            }
            {
                (bool success, ) = address(ammModule).delegatecall(
                    abi.encodeWithSelector(
                        IAmmModule.transferFrom.selector,
                        address(this),
                        to,
                        tokenId
                    )
                );
                if (!success) revert DelegateCallFailed();
            }
        }
    }

    /// @inheritdoc ICore
    function rebalance(
        RebalanceParams memory params
    ) external override nonReentrant {
        if (operatorFlag) {
            _requireAtLeastOperator();
        }
        TargetPositionInfo[] memory targets = new TargetPositionInfo[](
            params.ids.length
        );
        uint256 iterator = 0;
        for (uint256 i = 0; i < params.ids.length; i++) {
            uint256 id = params.ids[i];
            PositionInfo memory info = _positions[id];
            oracle.ensureNoMEV(info.pool, info.securityParams);
            TargetPositionInfo memory target;
            {
                bool flag;
                (flag, target) = strategyModule.getTargets(
                    info,
                    ammModule,
                    oracle
                );
                if (!flag) continue;
                _validateTarget(target);
            }
            (uint160 sqrtPriceX96, ) = oracle.getOraclePrice(info.pool);
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
                {
                    (bool success, ) = address(ammModule).delegatecall(
                        abi.encodeWithSelector(
                            IAmmModule.beforeRebalance.selector,
                            target.info.farm,
                            target.info.vault,
                            tokenId
                        )
                    );
                    if (!success) revert DelegateCallFailed();
                }
                {
                    (bool success, ) = address(ammModule).delegatecall(
                        abi.encodeWithSelector(
                            IAmmModule.transferFrom.selector,
                            address(this),
                            params.callback,
                            tokenId
                        )
                    );
                    if (!success) revert DelegateCallFailed();
                }
            }

            uint256 targetCapitalInToken1X96 = _calculateTargetCapitalX96(
                target,
                sqrtPriceX96,
                priceX96
            );
            target.minLiquidities = new uint256[](
                target.liquidityRatiosX96.length
            );
            for (uint256 j = 0; j < target.minLiquidities.length; j++) {
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

            target.id = id;
            target.info = info;
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
                IAmmModule.Position memory ammPosition = ammModule
                    .getPositionInfo(tokenId);
                if (
                    ammPosition.liquidity < target.minLiquidities[j] ||
                    ammPosition.tickLower != target.lowerTicks[j] ||
                    ammPosition.tickUpper != target.upperTicks[j] ||
                    ammModule.getPool(
                        ammPosition.token0,
                        ammPosition.token1,
                        ammPosition.property
                    ) !=
                    target.info.pool
                ) revert InvalidParameters();
                {
                    (bool success, ) = address(ammModule).delegatecall(
                        abi.encodeWithSelector(
                            IAmmModule.transferFrom.selector,
                            params.callback,
                            address(this),
                            tokenId
                        )
                    );
                    if (!success) revert DelegateCallFailed();
                }
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
            _positions[target.id].tokenIds = tokenIds;
        }
    }

    /// @inheritdoc ICore
    function emptyRebalance(uint256 id) external {
        PositionInfo memory params = _positions[id];
        if (params.owner != msg.sender) revert Forbidden();
        uint256[] memory tokenIds = params.tokenIds;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            if (tokenId == 0) revert InvalidParameters();
            (bool success, ) = address(ammModule).delegatecall(
                abi.encodeWithSelector(
                    IAmmModule.beforeRebalance.selector,
                    params.farm,
                    params.vault,
                    tokenId
                )
            );
            if (!success) revert DelegateCallFailed();
            (success, ) = address(ammModule).delegatecall(
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

    function _validateTarget(TargetPositionInfo memory target) private pure {
        uint256 n = target.liquidityRatiosX96.length;
        {
            uint256 cumulativeLiquidityX96 = 0;
            for (uint256 i = 0; i < n; i++) {
                cumulativeLiquidityX96 += target.liquidityRatiosX96[i];
            }
            if (cumulativeLiquidityX96 != Q96) revert InvalidTarget();
        }

        if (n != target.lowerTicks.length) revert InvalidTarget();
        if (n != target.upperTicks.length) revert InvalidTarget();

        for (uint256 i = 0; i < n; i++) {
            if (target.lowerTicks[i] > target.upperTicks[i]) {
                revert InvalidTarget();
            }
        }
    }
}
