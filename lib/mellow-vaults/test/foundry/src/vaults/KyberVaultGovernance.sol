// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../interfaces/vaults/IKyberVaultGovernance.sol";
import "../interfaces/vaults/IKyberVault.sol";
import "../libraries/ExceptionsLibrary.sol";
import "../libraries/CommonLibrary.sol";
import "../utils/ContractMeta.sol";
import "./VaultGovernance.sol";

/// @notice Governance that manages all Kyber Vaults params and can deploy a new Kyber Vault.
contract KyberVaultGovernance is ContractMeta, IKyberVaultGovernance, VaultGovernance {
    /// @notice Creates a new contract.
    /// @param internalParams_ Initial Internal Params
    constructor(InternalParams memory internalParams_) VaultGovernance(internalParams_) {}

    // -------------------  EXTERNAL, VIEW  -------------------

    /// @inheritdoc IKyberVaultGovernance
    function strategyParams(uint256 nft) external view returns (StrategyParams memory) {
        if (_strategyParams[nft].length == 0) {
            bytes[] memory paths = new bytes[](0);
            return StrategyParams({farm: IKyberSwapElasticLM(address(0)), paths: paths, pid: type(uint256).max});
        }
        return abi.decode(_strategyParams[nft], (StrategyParams));
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId) || type(IKyberVaultGovernance).interfaceId == interfaceId;
    }

    // -------------------  EXTERNAL, MUTATING  -------------------

    /// @inheritdoc IKyberVaultGovernance
    function setStrategyParams(uint256 nft, StrategyParams calldata params) external {
        require(address(params.farm) != address(0), ExceptionsLibrary.ADDRESS_ZERO);

        address vault = _internalParams.registry.vaultForNft(nft);

        for (uint256 i = 0; i < params.paths.length; ++i) {
            address firstAddress = CommonLibrary.toAddress(params.paths[i], 0);
            address lastAddress = CommonLibrary.toAddress(params.paths[i], params.paths[i].length - 20);
            (, , , , , , , address[] memory rewardTokens, ) = params.farm.getPoolInfo(params.pid);

            bool exists = false;

            for (uint256 j = 0; j < rewardTokens.length; ++j) {
                if (rewardTokens[j] == firstAddress) {
                    exists = true;
                }
            }

            require(exists, ExceptionsLibrary.INVARIANT);

            exists = false;

            address[] memory vaultTokens = IVault(vault).vaultTokens();

            for (uint256 j = 0; j < vaultTokens.length; ++j) {
                if (vaultTokens[j] == lastAddress) {
                    exists = true;
                }
            }

            require(exists, ExceptionsLibrary.INVARIANT);
        }

        _setStrategyParams(nft, abi.encode(params));
        IKyberVault(vault).updateFarmInfo();
        emit SetStrategyParams(tx.origin, msg.sender, nft, params);
    }

    /// @inheritdoc IKyberVaultGovernance
    function createVault(
        address[] memory vaultTokens_,
        address owner_,
        uint24 fee_
    ) external returns (IKyberVault vault, uint256 nft) {
        address vaddr;
        (vaddr, nft) = _createVault(owner_);
        vault = IKyberVault(vaddr);
        vault.initialize(nft, vaultTokens_, fee_);
        emit DeployedVault(tx.origin, msg.sender, vaultTokens_, abi.encode(fee_), owner_, vaddr, nft);
    }

    // -------------------  INTERNAL, VIEW  -------------------

    function _contractName() internal pure override returns (bytes32) {
        return bytes32("KyberVaultGovernance");
    }

    function _contractVersion() internal pure override returns (bytes32) {
        return bytes32("1.0.0");
    }

    // --------------------------  EVENTS  --------------------------

    /// @notice Emitted when new StrategyParams are set
    /// @param origin Origin of the transaction (tx.origin)
    /// @param sender Sender of the call (msg.sender)
    /// @param nft VaultRegistry NFT of the vault
    /// @param params New set params
    event SetStrategyParams(address indexed origin, address indexed sender, uint256 indexed nft, StrategyParams params);
}
