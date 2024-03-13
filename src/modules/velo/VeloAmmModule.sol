// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/modules/velo/IVeloAmmModule.sol";

import "../../libraries/external/LiquidityAmounts.sol";
import "../../libraries/external/TickMath.sol";

import "forge-std/Test.sol";

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

    constructor(INonfungiblePositionManager positionManager_) {
        positionManager = address(positionManager_);
        factory = ICLFactory(positionManager_.factory());
    }

    /// @inheritdoc IAmmModule
    function validateProtocolParams(bytes memory params) external pure {
        if (params.length != 0x40) revert InvalidLength();
        IVeloAmmModule.ProtocolParams memory params_ = abi.decode(
            params,
            (IVeloAmmModule.ProtocolParams)
        );
        if (params_.feeD9 > MAX_PROTOCOL_FEE) revert InvalidFee();
        if (params_.treasury == address(0)) revert AddressZero();
    }

    /// @inheritdoc IAmmModule
    function validateCallbackParams(bytes memory params) external pure {
        if (params.length == 0) return;
        if (params.length != 0x60) revert InvalidLength();
        IVeloAmmModule.CallbackParams memory params_ = abi.decode(
            params,
            (IVeloAmmModule.CallbackParams)
        );
        if (params_.farm == address(0)) revert AddressZero();
        if (params_.gauge == address(0)) revert AddressZero();
        if (params_.counter == address(0)) revert AddressZero();
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
        bytes memory,
        bytes memory
    ) external view override returns (uint256, uint256) {
        (
            ,
            ,
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(positionManager).positions(tokenId);
        return
            getAmountsForLiquidity(
                liquidity,
                sqrtRatioX96,
                tickLower,
                tickUpper
            );
    }

    /// @inheritdoc IAmmModule
    function getPositionInfo(
        uint256 tokenId
    ) public view override returns (Position memory position) {
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
    function getProperty(address pool) external view override returns (uint24) {
        return uint24(ICLPool(pool).tickSpacing());
    }

    /// @inheritdoc IAmmModule
    function beforeRebalance(
        uint256 tokenId,
        bytes memory callbackParams,
        bytes memory protocolParams
    ) external virtual override {
        if (callbackParams.length == 0) return;
        CallbackParams memory callbackParams_ = abi.decode(
            callbackParams,
            (CallbackParams)
        );
        if (callbackParams_.farm == address(0)) revert AddressZero();
        ProtocolParams memory protocolParams_ = abi.decode(
            protocolParams,
            (ProtocolParams)
        );
        if (protocolParams_.feeD9 > MAX_PROTOCOL_FEE) revert InvalidFee();
        ICLGauge(callbackParams_.gauge).getReward(tokenId);
        address token = ICLGauge(callbackParams_.gauge).rewardToken();
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            uint256 protocolReward = FullMath.mulDiv(
                protocolParams_.feeD9,
                balance,
                D9
            );

            if (protocolReward > 0) {
                IERC20(token).safeTransfer(
                    protocolParams_.treasury,
                    protocolReward
                );
            }

            balance -= protocolReward;
            if (balance > 0) {
                IERC20(token).safeTransfer(callbackParams_.farm, balance);
                ICounter(callbackParams_.counter).add(balance);
            }
        }
        ICLGauge(callbackParams_.gauge).withdraw(tokenId);
    }

    /// @inheritdoc IAmmModule
    function afterRebalance(
        uint256 tokenId,
        bytes memory callbackParams,
        bytes memory
    ) external virtual override {
        if (callbackParams.length == 0) return;
        address gauge = abi.decode(callbackParams, (CallbackParams)).gauge;
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
    }
}
