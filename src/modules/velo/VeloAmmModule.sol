// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../interfaces/modules/velo/IVeloAmmModule.sol";
import "../../libraries/PositionValue.sol";

contract VeloAmmModule is IVeloAmmModule {
    using SafeERC20 for IERC20;
    using Math for uint256;

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
    function validateCallbackParams(address pool_, bytes memory params) external view {
        if (params.length != 0x40) {
            revert InvalidLength();
        }
        IVeloAmmModule.CallbackParams memory params_ =
            abi.decode(params, (IVeloAmmModule.CallbackParams));
        if (params_.farm == address(0) || params_.gauge == address(0)) {
            revert AddressZero();
        }
        if (ICLPool(pool_).gauge() != params_.gauge) {
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
        IERC20 token = IERC20(ICLGauge(gauge).rewardToken());
        if (_isStaked(gauge, tokenId)) {
            address this_ = address(this);
            balance = token.balanceOf(this_);
            ICLGauge(gauge).getReward(tokenId);
            balance = token.balanceOf(this_) - balance;
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
        IVeloFarm(callbackParams_.farm).distribute(balance, address(token));
    }

    function swapOnPool(address pool, bool zeroForOne, uint256 amountIn)
        external
        returns (int256 amount0, int256 amount1)
    {
        if (amountIn == 0) {
            return (0, 0);
        }
        return ICLPool(pool).swap(
            address(this),
            zeroForOne,
            int256(amountIn),
            zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            ""
        );
    }

    function poolCallback(address pool, bytes4 selector, bytes memory callbackData) external {
        if (selector != ICLSwapCallback.uniswapV3SwapCallback.selector) {
            revert ForbiddenCallback();
        }

        (int256 amount0Delta, int256 amount1Delta,) =
            abi.decode(callbackData, (int256, int256, bytes));

        address token0 = ICLPool(pool).token0();
        address token1 = ICLPool(pool).token1();

        if (amount0Delta > 0) {
            SafeERC20.safeTransfer(IERC20(token0), pool, uint256(amount0Delta));
        }

        if (amount1Delta > 0) {
            SafeERC20.safeTransfer(IERC20(token1), pool, uint256(amount1Delta));
        }
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
    function getLiquidityForAmounts(
        uint256 amount0,
        uint256 amount1,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) public pure override returns (uint128) {
        return LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            amount0,
            amount1
        );
    }

    /// @inheritdoc IAmmModule
    function getAmountsForLiquidity(
        uint256 liquidity,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) public pure override returns (uint256 amount0, uint256 amount1) {
        uint256 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint256 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        if (sqrtPriceX96 < sqrtPriceBX96) {
            uint256 sqrtRatioAX96_ = sqrtPriceAX96.max(sqrtPriceX96);
            amount0 = (liquidity << 96).mulDiv(sqrtPriceBX96 - sqrtRatioAX96_, sqrtPriceBX96)
                / sqrtRatioAX96_;
        }

        if (sqrtPriceX96 > sqrtPriceAX96) {
            amount1 = liquidity.mulDiv(sqrtPriceBX96.min(sqrtPriceX96) - sqrtPriceAX96, 2 ** 96);
        }
    }

    function getAmountsForLiquidityCeil(
        uint256 liquidity,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) public pure override returns (uint256 amount0, uint256 amount1) {
        uint256 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint256 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        if (sqrtPriceX96 < sqrtPriceBX96) {
            uint256 sqrtRatioAX96_ = sqrtPriceAX96.max(sqrtPriceX96);
            amount0 = Math.ceilDiv(
                (liquidity << 96).mulDiv(
                    sqrtPriceBX96 - sqrtRatioAX96_, sqrtPriceBX96, Math.Rounding.Ceil
                ),
                sqrtRatioAX96_
            );
        }

        if (sqrtPriceX96 > sqrtPriceAX96) {
            amount1 = liquidity.mulDiv(
                sqrtPriceBX96.min(sqrtPriceX96) - sqrtPriceAX96, 2 ** 96, Math.Rounding.Ceil
            );
        }
    }

    /// ---------------------- INTERNAL MUTABLE FUNCTIONS ----------------------

    function _isStaked(address gauge, uint256 tokenId) internal view returns (bool) {
        return IERC721(positionManager).ownerOf(tokenId) == gauge;
    }
}
