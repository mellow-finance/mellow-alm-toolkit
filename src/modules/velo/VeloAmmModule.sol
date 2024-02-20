// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/modules/velo/IVeloAmmModule.sol";

import "../../libraries/external/LiquidityAmounts.sol";
import "../../libraries/external/TickMath.sol";

import "../../utils/DefaultAccessControl.sol";

contract VeloAmmModule is IVeloAmmModule {
    using SafeERC20 for IERC20;

    /// @inheritdoc IVeloAmmModule
    uint256 public constant D9 = 1e9;
    /// @inheritdoc IVeloAmmModule
    uint256 public constant MAX_PROTOCOL_FEE = 3e8; // 30%

    /// @inheritdoc IVeloAmmModule
    INonfungiblePositionManager public immutable positionManager;
    /// @inheritdoc IVeloAmmModule
    ICLFactory public immutable factory;
    /// @inheritdoc IVeloAmmModule
    address public immutable protocolTreasury;
    /// @inheritdoc IVeloAmmModule
    uint256 public immutable protocolFeeD9;

    constructor(
        INonfungiblePositionManager positionManager_,
        address protocolTreasury_,
        uint256 protocolFeeD9_
    ) {
        positionManager = positionManager_;
        factory = ICLFactory(positionManager.factory());
        if (protocolTreasury_ == address(0))
            revert("VeloAmmModule: treasury is zero");
        if (protocolFeeD9_ > MAX_PROTOCOL_FEE)
            revert("VeloAmmModule: invalid fee");
        protocolTreasury = protocolTreasury_;
        protocolFeeD9 = protocolFeeD9_;
    }

    /// @inheritdoc IVeloAmmModule
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

    /// @inheritdoc IVeloAmmModule
    function tvl(
        uint256 tokenId,
        uint160 sqrtRatioX96,
        address,
        address
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

        ) = positionManager.positions(tokenId);
        return
            getAmountsForLiquidity(
                liquidity,
                sqrtRatioX96,
                tickLower,
                tickUpper
            );
    }

    /// @inheritdoc IVeloAmmModule
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

        ) = positionManager.positions(tokenId);
        position.property = uint24(tickSpacing);
    }

    /// @inheritdoc IVeloAmmModule
    function getPool(
        address token0,
        address token1,
        uint24 tickSpacing
    ) external view override returns (address) {
        return factory.getPool(token0, token1, int24(tickSpacing));
    }

    /// @inheritdoc IVeloAmmModule
    function getProperty(address pool) external view override returns (uint24) {
        return uint24(ICLPool(pool).tickSpacing());
    }

    /// @inheritdoc IVeloAmmModule
    function beforeRebalance(
        address gauge,
        address synthetixFarm,
        uint256 tokenId
    ) external virtual {
        if (gauge == address(0)) return;
        require(
            synthetixFarm != address(0),
            "VeloAmmModule: synthetixFarm is zero"
        );

        ICLGauge(gauge).getReward(tokenId);
        address token = ICLGauge(gauge).rewardToken();
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            uint256 protocolReward = FullMath.mulDiv(
                protocolFeeD9,
                balance,
                D9
            );

            if (protocolReward > 0) {
                IERC20(token).safeTransfer(protocolTreasury, protocolReward);
            }

            balance -= protocolReward;
            if (balance > 0) {
                IERC20(token).safeTransfer(synthetixFarm, balance);
            }
        }
        ICLGauge(gauge).withdraw(tokenId);
    }

    /// @inheritdoc IVeloAmmModule
    function afterRebalance(
        address farm,
        address,
        uint256 tokenId
    ) external virtual {
        if (farm == address(0)) return;
        positionManager.approve(farm, tokenId);
        ICLGauge(farm).deposit(tokenId);
    }
}
