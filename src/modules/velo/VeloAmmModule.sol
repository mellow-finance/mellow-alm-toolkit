// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../interfaces/modules/velo/IVeloAmmModule.sol";
import "../../libraries/PositionValue.sol";

contract VeloAmmModule is IVeloAmmModule {
    using SafeERC20 for IERC20;

    /// @inheritdoc IVeloAmmModule
    uint256 public constant D9 = 1e9;

    /// @inheritdoc IVeloAmmModule
    uint32 public constant MAX_PROTOCOL_FEE = 3e8; // 30%

    /// @inheritdoc IAmmModule
    address public immutable positionManager;

    /// @inheritdoc IVeloAmmModule
    ICLFactory public immutable factory;

    /// @inheritdoc IVeloAmmModule
    bytes4 public immutable selectorIsPool;

    /// ---------------------- INITIALIZER FUNCTIONS ----------------------

    constructor(INonfungiblePositionManager positionManager_, bytes4 selectorIsPool_) {
        positionManager = address(positionManager_);
        factory = ICLFactory(positionManager_.factory());
        selectorIsPool = selectorIsPool_;
        /// @dev expect the next call to succeed without reverting. This logic is added
        // to support velodrome and aerodrome protocols using the same codebase
        assert(!isPool(address(0)));
    }

    /// ---------------------- EXTERNAL MUTATING FUNCTIONS ----------------------

    /// @inheritdoc IAmmModule
    function beforeRebalance(
        uint256 tokenId,
        bytes memory callbackParams,
        bytes memory protocolParams
    ) external virtual override {
        address gauge = abi.decode(callbackParams, (CallbackParams)).gauge;
        if (!_isStaked(gauge, tokenId)) {
            return;
        }
        collectRewards(tokenId, callbackParams, protocolParams);
        ICLGauge(gauge).withdraw(tokenId);
    }

    /// @inheritdoc IAmmModule
    function afterRebalance(uint256 tokenId, bytes memory callbackParams, bytes memory)
        external
        virtual
        override
    {
        address gauge = abi.decode(callbackParams, (CallbackParams)).gauge;
        if (!ICLGauge(gauge).voter().isAlive(gauge)) {
            return;
        }
        INonfungiblePositionManager(positionManager).approve(gauge, tokenId);
        ICLGauge(gauge).deposit(tokenId);
    }

    /// @inheritdoc IAmmModule
    function transferFrom(address from, address to, uint256 tokenId) external virtual override {
        INonfungiblePositionManager(positionManager).transferFrom(from, to, tokenId);
        if (to == address(this)) {
            // transfers unclaimed fees back to the user or to the callback address
            INonfungiblePositionManager(positionManager).collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: tokenId,
                    recipient: from,
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );
        }
    }

    /// ---------------------- EXTERNAL VIEW FUNCTIONS ----------------------

    /// @inheritdoc IAmmModule
    function validateCallbackParams(bytes memory params) external view {
        if (params.length != 0x40) {
            revert InvalidLength();
        }
        IVeloAmmModule.CallbackParams memory params_ =
            abi.decode(params, (IVeloAmmModule.CallbackParams));
        if (params_.farm == address(0) || params_.gauge == address(0)) {
            revert AddressZero();
        }
        ICLPool pool = ICLGauge(params_.gauge).pool();
        if (!isPool(address(pool)) || pool.gauge() != params_.gauge) {
            revert InvalidGauge();
        }
    }

    /// @inheritdoc IAmmModule
    function tvl(uint256 tokenId, uint160 sqrtRatioX96, bytes memory callbackParams, bytes memory)
        external
        view
        override
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1) = PositionValue.principal(
            INonfungiblePositionManager(positionManager), tokenId, sqrtRatioX96
        );
        address gauge = abi.decode(callbackParams, (CallbackParams)).gauge;
        if (!_isStaked(gauge, tokenId)) {
            (uint256 fees0, uint256 fees1) =
                PositionValue.fees(INonfungiblePositionManager(positionManager), tokenId);
            amount0 += fees0;
            amount1 += fees1;
        }
    }

    /// @inheritdoc IAmmModule
    function getPool(address token0, address token1, uint24 tickSpacing)
        external
        view
        override
        returns (address)
    {
        return factory.getPool(token0, token1, int24(tickSpacing));
    }

    /// @inheritdoc IAmmModule
    function getProperty(address pool) external view override returns (uint24) {
        return uint24(ICLPool(pool).tickSpacing());
    }

    /// ---------------------- EXTERNAL PURE FUNCTIONS ----------------------
    /// @inheritdoc IAmmModule
    function validateProtocolParams(bytes memory params) external pure {
        if (params.length != 0x40) {
            revert InvalidLength();
        }
        IVeloAmmModule.ProtocolParams memory params_ =
            abi.decode(params, (IVeloAmmModule.ProtocolParams));
        if (params_.feeD9 > MAX_PROTOCOL_FEE) {
            revert InvalidFee();
        }
        if (params_.treasury == address(0)) {
            revert AddressZero();
        }
    }

    /// ---------------------- PUBLIC MUTABLE FUNCTIONS ----------------------

    /// @inheritdoc IAmmModule
    function collectRewards(
        uint256 tokenId,
        bytes memory callbackParams,
        bytes memory protocolParams
    ) public virtual override {
        CallbackParams memory callbackParams_ = abi.decode(callbackParams, (CallbackParams));
        ProtocolParams memory protocolParams_ = abi.decode(protocolParams, (ProtocolParams));
        address gauge = callbackParams_.gauge;
        uint256 balance;
        if (_isStaked(gauge, tokenId)) {
            ICLGauge(gauge).getReward(tokenId);
            IERC20 token = IERC20(ICLGauge(gauge).rewardToken());
            balance = token.balanceOf(address(this));
            if (balance > 0) {
                uint256 protocolReward = Math.mulDiv(protocolParams_.feeD9, balance, D9);

                if (protocolReward > 0) {
                    token.safeTransfer(protocolParams_.treasury, protocolReward);
                }

                balance -= protocolReward;
                if (balance > 0) {
                    token.safeTransfer(callbackParams_.farm, balance);
                }
            }
        }
        // we want to provide this information to the farm anyway, even if we don't have any rewards to distribute
        IVeloFarm(callbackParams_.farm).distribute(balance);
    }

    /// ---------------------- PUBLIC VIEW FUNCTIONS ----------------------

    /// @inheritdoc IAmmModule
    function getAmmPosition(uint256 tokenId)
        public
        view
        override
        returns (AmmPosition memory position)
    {
        PositionLibrary.Position memory position_ =
            PositionLibrary.getPosition(positionManager, tokenId);
        position.token0 = position_.token0;
        position.token1 = position_.token1;
        position.property = uint24(position_.tickSpacing);
        position.tickLower = position_.tickLower;
        position.tickUpper = position_.tickUpper;
        position.liquidity = position_.liquidity;
    }

    /// ---------------------- PUBLIC PURE FUNCTIONS ----------------------
    /// @inheritdoc IAmmModule
    function isPool(address pool) public view override returns (bool) {
        bytes memory returnData = Address.functionStaticCall(
            address(factory), abi.encodeWithSelector(selectorIsPool, pool)
        );
        return abi.decode(returnData, (bool));
    }

    /// @inheritdoc IAmmModule
    function getAmountsForLiquidity(
        uint128 liquidity,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) public pure override returns (uint256, uint256) {
        return LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity
        );
    }

    /// ---------------------- INTERNAL MUTABLE FUNCTIONS ----------------------

    function _isStaked(address gauge, uint256 tokenId) internal view returns (bool) {
        return IERC721(positionManager).ownerOf(tokenId) == gauge;
    }
}
