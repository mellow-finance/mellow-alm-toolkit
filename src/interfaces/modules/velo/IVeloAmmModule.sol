// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../IAmmModule.sol";

import "../../external/velo/ICLPool.sol";
import "../../external/velo/ICLGauge.sol";
import "../../external/velo/ICLFactory.sol";
import "../../external/velo/INonfungiblePositionManager.sol";

interface IVeloAmmModule is IAmmModule {
    function D9() external view returns (uint256);

    function MAX_PROTOCOL_FEE() external view returns (uint256);

    function positionManager()
        external
        view
        returns (INonfungiblePositionManager);

    function factory() external view returns (ICLFactory);

    function protocolTreasury() external view returns (address);

    function protocolFeeD9() external view returns (uint256);

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
    ) external pure override returns (uint256, uint256);

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
    ) external view override returns (uint256, uint256);

    /**
     * @dev Retrieves the information of a position.
     * @param tokenId The ID of the position.
     * @return position The Position struct containing the position information.
     */
    function getPositionInfo(
        uint256 tokenId
    ) external view override returns (Position memory position);

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
    ) external view override returns (address);
    /**
     * @dev Retrieves the fee property of a given pool.
     * @param pool The address of the pool.
     * @return uint24 fee value of the pool.
     */
    function getProperty(address pool) external view override returns (uint24);
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
    ) external;
    /**
     * @dev Executes after a rebalance operation.
     * @param farm The address of the farm.
     * @param tokenId The ID of the token being transferred.
     */
    function afterRebalance(address farm, address, uint256 tokenId) external;
}
