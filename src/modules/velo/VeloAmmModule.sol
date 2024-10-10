// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/modules/velo/IVeloAmmModule.sol";

import "../../libraries/external/LiquidityAmounts.sol";
import "../../libraries/external/TickMath.sol";
import "../../libraries/external/velo/PositionValue.sol";

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

    constructor(
        INonfungiblePositionManager positionManager_,
        bytes4 selectorIsPool_
    ) {
        positionManager = address(positionManager_);
        factory = ICLFactory(positionManager_.factory());
        selectorIsPool = selectorIsPool_;
        _validateSelectorIsPool();
    }

    /// @inheritdoc IAmmModule
    function validateProtocolParams(
        ProtocolParams memory params
    ) external pure {
        if (params.feeD9 > MAX_PROTOCOL_FEE) revert InvalidFee();
        if (params.treasury == address(0)) revert AddressZero();
    }

    /// @inheritdoc IAmmModule
    function validateCallbackParams(
        CallbackParams memory params
    ) external view {
        if (params.farm == address(0)) revert AddressZero();
        if (params.gauge == address(0)) revert AddressZero();
        if (params.counter == address(0)) revert AddressZero();
        ICLPool pool = ICLGauge(params.gauge).pool();
        if (!isPool(address(pool))) revert InvalidGauge();
        if (pool.gauge() != params.gauge) revert InvalidGauge();
    }

    /// @inheritdoc IAmmModule
    function getAmountsForLiquidity(
        uint128 liquidity,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    ) public pure override returns (uint256, uint256) {
        return
            LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );
    }

    /// @inheritdoc IAmmModule
    function tvl(
        uint256 tokenId,
        uint160 sqrtRatioX96,
        CallbackParams memory callbackParams,
        ProtocolParams memory
    ) external view override returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = PositionValue.principal(
            INonfungiblePositionManager(positionManager),
            tokenId,
            sqrtRatioX96
        );
        address gauge = callbackParams.gauge;
        if (IERC721(positionManager).ownerOf(tokenId) != gauge) {
            (uint256 fees0, uint256 fees1) = PositionValue.fees(
                INonfungiblePositionManager(positionManager),
                tokenId
            );
            amount0 += fees0;
            amount1 += fees1;
        }
    }

    /// @inheritdoc IAmmModule
    function getAmmPosition(
        uint256 tokenId
    ) public view override returns (AmmPosition memory position) {
        int24 tickSpacing;
        (
            ,
            ,
            position.token0,
            position.token1,
            tickSpacing,
            position.tickLower,
            position.tickUpper,
            position.liquidity,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(positionManager).positions(tokenId);
        position.property = uint24(tickSpacing);
    }

    /// @inheritdoc IAmmModule
    function getPool(
        address token0,
        address token1,
        uint24 tickSpacing
    ) external view override returns (address) {
        return factory.getPool(token0, token1, int24(tickSpacing));
    }

    /// @inheritdoc IAmmModule
    function isPool(address pool) public view override returns (bool) {
        (bool success, bytes memory returnData) = address(factory).staticcall(
            abi.encodeWithSelector(selectorIsPool, pool)
        );
        if (!success) revert IsPool();
        return abi.decode(returnData, (bool));
    }

    /// @inheritdoc IAmmModule
    function getProperty(address pool) external view override returns (uint24) {
        return uint24(ICLPool(pool).tickSpacing());
    }

    /// @inheritdoc IAmmModule
    function beforeRebalance(
        uint256 tokenId,
        CallbackParams memory callbackParams,
        ProtocolParams memory protocolParams
    ) external virtual override {
        if (callbackParams.farm == address(0)) revert AddressZero();
        if (protocolParams.feeD9 > MAX_PROTOCOL_FEE) revert InvalidFee();
        address gauge = callbackParams.gauge;
        if (IERC721(positionManager).ownerOf(tokenId) != gauge) return;
        ICLGauge(gauge).getReward(tokenId);
        address token = ICLGauge(gauge).rewardToken();
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            uint256 protocolReward = FullMath.mulDiv(
                protocolParams.feeD9,
                balance,
                D9
            );

            if (protocolReward > 0) {
                IERC20(token).safeTransfer(
                    protocolParams.treasury,
                    protocolReward
                );
            }

            balance -= protocolReward;
            if (balance > 0) {
                IERC20(token).safeTransfer(callbackParams.farm, balance);
                ICounter(callbackParams.counter).add(
                    balance,
                    token,
                    callbackParams.farm
                );
            }
        }
        ICLGauge(gauge).withdraw(tokenId);
    }

    /// @inheritdoc IAmmModule
    function afterRebalance(
        uint256 tokenId,
        CallbackParams memory callbackParams,
        ProtocolParams memory
    ) external virtual override {
        address gauge = callbackParams.gauge;
        if (!ICLGauge(gauge).voter().isAlive(gauge)) return;
        INonfungiblePositionManager(positionManager).approve(gauge, tokenId);
        ICLGauge(gauge).deposit(tokenId);
    }

    /// @inheritdoc IAmmModule
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external virtual override {
        INonfungiblePositionManager(positionManager).transferFrom(
            from,
            to,
            tokenId
        );
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

    /**
     * @dev makes a call to the ICLFactory and checks that address(0) does not belong to
     *  if selectorIsPool is wrong then reverts with IsPool() reason
     * */
    function _validateSelectorIsPool() internal view {
        require(isPool(address(0)) == false);
    }
}
