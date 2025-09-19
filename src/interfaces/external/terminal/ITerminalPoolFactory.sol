// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title The interface for the Terminal Pool Factory
/// @notice The Terminal Pool Factory facilitates creation of Terminal pools and control over the unstaked tax
interface ITerminalPoolFactory {
    /// @notice Emitted when the voter address is changed
    event VoterChanged(address voter);

    /// @notice Emitted when a pool is created
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param tickSpacing The minimum number of ticks between initialized ticks
    /// @param pool The address of the created pool
    event PoolCreated(
        address indexed token0, address indexed token1, int24 indexed tickSpacing, address pool
    );

    /// @notice Emitted when a new tick spacing is enabled for pool creation via the factory
    /// @param tickSpacing The minimum number of ticks between initialized ticks for pools created with this spacing
    event TickSpacingEnabled(int24 indexed tickSpacing);

    /// @notice Emitted when a new custom fee is set for a given pool
    /// @param pool The address of the pool
    /// @param customFee The custom fee to be applied to the pool
    event CustomFeeChanged(address indexed pool, uint24 customFee);

    /// @notice Emitted when a new default fee is set for a given tick spacing
    /// @param tickSpacing The tick spacing for which the default fee is set
    /// @param defaultFee The default fee to be applied to all pools created with the spacing
    event DefaultFeeChanged(int24 indexed tickSpacing, uint24 defaultFee);

    /// @notice Emitted when a user's fee exemption status is changed
    /// @param user The address of the user
    /// @param exempt The new exemption status of the user
    event FeeExemptChanged(address indexed user, bool exempt);

    /// @notice Returns the address of the voter
    /// @return The address of the voter
    function voter() external view returns (address);

    /// @notice Returns the custom fee for a given pool, or 0 if no custom fee is set
    /// @param pool The address of the pool
    /// @return The custom fee for the pool, denominated in hundredths of a bip
    function customFee(address pool) external view returns (uint24);

    /// @notice Returns the default fee for a given tick spacing, if enabled, or 0 if not enabled
    /// @param tickSpacing The tick spacing
    /// @return fee The enabled fee, denominated in hundredths of a bip. Returns 0 in case of unenabled tick spacing
    function defaultFee(int24 tickSpacing) external view returns (uint24);

    /// @notice Returns whether a user is exempt from fees
    /// @param user The address of the user
    /// @return True if the user is exempt from fees, false otherwise
    function isFeeExempt(address user) external view returns (bool);

    /// @notice Returns the pool address for a given pair of tokens and a tick spacing, or address 0 if it does not exist
    /// @dev tokenA and tokenB may be passed in either token0/token1 or token1/token0 order
    /// @param tokenA The contract address of either token0 or token1
    /// @param tokenB The contract address of the other token
    /// @param tickSpacing The tick spacing of the pool
    /// @return pool The pool address
    function getPool(address tokenA, address tokenB, int24 tickSpacing)
        external
        view
        returns (address pool);

    /// @notice Returns the fee for a given pool, user, and tick spacing, denominated in hundredths of a bip
    /// This is the custom fee if one is set for the pool. Else, it's the default fee for the pool's tick spacing.
    /// If pool is not created by the factory or does not have the given tick spacing, behavior is undefined
    /// @param pool The address of the pool
    /// @param user The address of the user performing the swap. For default users, pass address(0).
    /// @param tickSpacing The tick spacing of the pool
    /// @return fee The fee for the pool, denominated in hundredths of a bip
    function getFee(address pool, address user, int24 tickSpacing)
        external
        view
        returns (uint24 fee);

    /// @notice Creates a pool for the given two tokens and tick spacing
    /// @param tokenA One of the two tokens in the desired pool
    /// @param tokenB The other of the two tokens in the desired pool
    /// @param data Additional data to be passed to the pool constructor, expected to contain the tick spacing
    /// @dev tokenA and tokenB may be passed in either order: token0/token1 or token1/token0.
    /// The call will revert if the pool already exists, the tick spacing is invalid, or the token arguments
    /// are invalid.
    /// @return pool The address of the newly created pool
    function createPool(address tokenA, address tokenB, bytes memory data)
        external
        returns (address pool);

    /// @notice Updates the voter address
    /// @dev Must be called by the current voter
    /// @param _voter The new voter of the factory
    function setVoter(address _voter) external;

    /// @notice Enables a tick spacing with the given default fee
    /// @dev Tick spacings may never be unenabled once enabled
    /// @param tickSpacing The spacing between ticks to be enforced for all pools created with the spacing
    /// @param _defaultFee The default fee of pools with the spacing, denominated in hundredths of a bip
    function enableTickSpacing(int24 tickSpacing, uint24 _defaultFee) external;

    /// @notice Sets a custom fee for a given pool.
    /// Only callable by the Governor
    /// @param pool The address of the pool
    /// @param fee The custom fee to set, denominated in hundredths of a bip
    function setCustomFee(address pool, uint24 fee) external;

    /// @notice Remove the custom fee for a given pool.
    /// Only callable by the Governor.
    /// @param _pool The address of the pool
    function removeCustomFee(address _pool) external;

    /// @notice Sets a default fee for a given tick spacing.
    /// Only callable by the Governor.
    /// @param tickSpacing The tick spacing for which to set the default fee
    /// @param fee The new default fee to set, denominated in hundredths of a bip
    function setDefaultFee(int24 tickSpacing, uint24 fee) external;

    /// @notice Sets or unsets a user's fee exemption status.
    /// Only callable by the Governor.
    /// @param user The address of the user
    /// @param exempt The new exemption status of the user
    function setFeeExempt(address user, bool exempt) external;
}
