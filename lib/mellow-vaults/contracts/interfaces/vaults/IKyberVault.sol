// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./IIntegrationVault.sol";
import "../external/kyber/periphery/IBasePositionManager.sol";
import "../external/kyber/IPool.sol";

import "../oracles/IOracle.sol";
import "../utils/IKyberHelper.sol";
import "../external/kyber/IKyberSwapElasticLM.sol";

interface IKyberVault is IERC721Receiver, IIntegrationVault {
    struct Options {
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /// @notice Reference to IBasePositionManager of KyberSwap protocol.
    function positionManager() external view returns (IBasePositionManager);

    /// @notice Reference to KyberSwap pool.
    function pool() external view returns (IPool);

    /// @notice NFT of KyberSwap position manager
    function kyberNft() external view returns (uint256);
    
    /// @notice Initialized a new contract.
    /// @dev Can only be initialized by vault governance
    /// @param nft_ NFT of the vault in the VaultRegistry
    /// @param vaultTokens_ ERC20 tokens that will be managed by this Vault
    /// @param fee_ Fee of the Kyber pool
    function initialize(
        uint256 nft_,
        address[] memory vaultTokens_,
        uint24 fee_
    ) external;

    function updateFarmInfo() external;

    function farm() external view returns (IKyberSwapElasticLM);

    function mellowOracle() external view returns (IOracle);

    function pid() external view returns (uint256);

    function isLiquidityInFarm() external view returns (bool);

    function kyberHelper() external view returns (IKyberHelper);
}
