// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../interfaces/modules/IAmmModule.sol";

import "../../interfaces/external/velo/ICLPool.sol";
import "../../interfaces/external/velo/ICLGauge.sol";
import "../../interfaces/external/velo/ICLFactory.sol";
import "../../interfaces/external/velo/INonfungiblePositionManager.sol";

import "../../libraries/external/LiquidityAmounts.sol";
import "../../libraries/external/TickMath.sol";

import "../../utils/DefaultAccessControl.sol";

contract VeloAmmModule is IAmmModule, DefaultAccessControl {
    using SafeERC20 for IERC20;

    uint256 public constant D9 = 1e9;
    uint256 public constant MAX_PROTOCOL_FEE = 3e8; // 30%

    INonfungiblePositionManager public immutable positionManager;
    ICLFactory public immutable factory;

    uint256 public protocolFeeD9 = 0;
    address public protocolTreasury;

    constructor(
        INonfungiblePositionManager positionManager_,
        address admin_,
        address protocolTreasury_,
        uint256 protocolFeeD9_
    ) DefaultAccessControl(admin_) {
        if (protocolFeeD9_ > MAX_PROTOCOL_FEE) revert Forbidden();
        positionManager = positionManager_;
        factory = ICLFactory(positionManager.factory());
        protocolTreasury = protocolTreasury_;
        protocolFeeD9 = protocolFeeD9_;
    }

    /**
     * @dev Updates the protocol fee.
     * @param newProtocolFeeD9 The new protocol fee in D9 format.
     * @notice Only the admin can update the protocol fee.
     * @notice The new protocol fee must not exceed the maximum protocol fee.
     */
    function updateProtocolFee(uint256 newProtocolFeeD9) external {
        _requireAdmin();
        if (newProtocolFeeD9 > MAX_PROTOCOL_FEE) revert Forbidden();
        protocolFeeD9 = newProtocolFeeD9;
    }

    function updateProtocolTreasury(address newProtocolTreasury) external {
        _requireAdmin();
        if (newProtocolTreasury == address(0)) revert Forbidden();
        protocolTreasury = newProtocolTreasury;
    }

    /**
     * @dev Calculates the amounts of token0 and token1 for a given liquidity amount.
     * @param liquidity The liquidity amount.
     * @param sqrtPriceX96 The square root of the current price of the pool.
     * @param tickLower The lower tick of the range.
     * @param tickUpper The upper tick of the range.
     * @return The amounts of token0 and token1.
     */
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

    /**
     * @dev Calculates the total value locked (TVL) for a given token ID and pool.
     * @param tokenId The ID of the token.
     * @param sqrtRatioX96 The square root of the current tick value of the pool.
     * @return uint256, uint256 - amount0 and amount1 locked in the position.
     */
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

    /**
     * @dev Retrieves the information of a position.
     * @param tokenId The ID of the position.
     * @return position The Position struct containing the position information.
     */
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

    /**
     * @dev Retrieves the address of the pool for the specified tokens and fee.
     * @param token0 The address of the first token in the pool.
     * @param token1 The address of the second token in the pool.
     * @param tickSpacing The tickSpacing of the pool.
     * @return address The address of the pool.
     */
    function getPool(
        address token0,
        address token1,
        uint24 tickSpacing
    ) external view override returns (address) {
        return factory.getPool(token0, token1, int24(tickSpacing));
    }

    /**
     * @dev Retrieves the fee property of a given pool.
     * @param pool The address of the pool.
     * @return uint24 fee value of the pool.
     */
    function getProperty(address pool) external view override returns (uint24) {
        return uint24(ICLPool(pool).tickSpacing());
    }

    /**
     * @dev Executes actions before rebalancing.
     * @param gauge The address of the gauge contract.
     * @param synthetixFarm The address of the Synthetix farm contract.
     * @param tokenId The ID of the token.
     */
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
    }

    /**
     * @dev Executes after a rebalance operation.
     * @param farm The address of the farm.
     * @param tokenId The ID of the token being transferred.
     */
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
