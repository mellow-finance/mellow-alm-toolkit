// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../ICore.sol";
import "../modules/velo/IVeloDepositWithdrawModule.sol";
import "../utils/IVeloDeployFactory.sol";
import "src/interfaces/modules/strategies/IPulseStrategyModule.sol";

/**
 * @title IVeloDeployFactory Interface
 * @dev Interface for the VeloDeployFactory contract, facilitating the creation of strategies,
 * LP wrappers, and managing their configurations for Velo pools.
 */
interface IVeloFactoryDeposit {
    error Forbidden();
    error AddressZero();
    error ZeroLiquidity();
    error ZeroNFT();
    error ForbiddenPool();
    error InvalidParams();

    struct PoolStrategyParameter {
        ICLPool pool;
        IPulseStrategyModule.StrategyType strategyType;
        int24 width;
        int24 tickNeighborhood;
        uint256 maxAmount0;
        uint256 maxAmount1;
        uint256 maxLiquidityRatioDeviationX96;
        bytes securityParams;
        uint256[] tokenId;
    }

    /**
     * @dev Creates Core position (may include array of NFT positions) and deposit it in favor of VeloDeployFactory.
     * @notice In case of absence tokenId's it mints them, else just checks that theya are along with parameters.
     * @param depositor Address of depositor who will pay for.
     * @param owner Address of Core position owner.
     * @param creationParameters Structure with specific strategy parameter.
     * @return tokenIds Array of NFTs that were created align `PoolStrategyParameter`
     * Requirements:
     *  - `depositor` must approve this contract as spender.
     */
    function create(
        address depositor,
        address owner,
        PoolStrategyParameter calldata creationParameters
    ) external returns (uint256[] memory tokenIds);

    /**
     * @dev Mint specific position via NFT manager in favor of `to`.
     * @notice Remain assets will hold on contract and can be withdraw by `collect` method.
     * @param depositor Address of depositor who will pay for.
     * @param to Address of owner of minted position.
     * @param pool Address of pool.
     * @param tickLower Lower tick of position.
     * @param tickUpper Upper tick of position.
     * @param liquidity Desired liquidity.
     * @return tokenId Id of NFT in terms of NFT manager.
     * Requirements:
     *  - `depositor` must approve this contract as spender.
     */
    function mint(
        address depositor,
        address to,
        ICLPool pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) external returns (uint256 tokenId);
}
