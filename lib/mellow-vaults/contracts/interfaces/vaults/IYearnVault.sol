// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IIntegrationVault.sol";

interface IYearnVault is IIntegrationVault {
    /// @notice Initialized a new contract.
    /// @dev Can only be initialized by vault governance
    /// @param nft_ NFT of the vault in the VaultRegistry
    /// @param vaultTokens_ ERC20 tokens that will be managed by this Vault
    function initialize(uint256 nft_, address[] memory vaultTokens_) external;

    /// @notice Default maximal loss for withdraw
    function DEFAULT_MAX_LOSS() external view returns (uint256);
}
