// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

/// @title Minimal Redeemable ERC20 interface for Terminal AMM
/// @notice Contains a subset of the full RedeemableERC20 interface that is used in Terminal AMM
interface IRedeemableERC20Minimal {
    /// @notice Return the address of the underlying token
    function underlyingToken() external view returns (address);

    /// @notice Return the amount of underlying tokens corresponding to a given amount of rToken, rounded up
    /// @param amount The amount of rToken
    /// @return underlying The corresponding amount of underlying tokens
    function toUnderlyingRoundUp(uint256 amount) external view returns (uint256 underlying);

    /// @notice Mint rTokens by depositing a corresponding amount of underlying tokens
    /// @param recipient The account to mint the rTokens to
    /// @param amount The amount of rTokens to mint
    /// @return underlying The amount of underlying tokens deposited
    function mint(address recipient, uint256 amount) external returns (uint256 underlying);

    /// @notice Burn rTokens and withdraw a corresponding amount of underlying tokens
    /// @param recipient The address to send the withdrawn underlying tokens to
    /// @param amount The amount of rTokens to burn
    /// @return underlying The amount of underlying tokens withdrawn
    function burn(address recipient, uint256 amount) external returns (uint256 underlying);

    /// @notice Redeem the yield for msg.sender.
    /// @return yield The amount of yield in underlying tokens redeemed.
    function redeem() external returns (uint256 yield);
}
