// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Interface for WMNT
interface IWMNT is IERC20 {
    /// @notice Deposit ether to get wrapped ether
    function deposit() external payable;

    /// @notice Withdraw wrapped ether to get ether
    function withdraw(uint256) external;

    function totalSupply() external view override returns (uint);

    function approve(address guy, uint wad) external override returns (bool);

    function transfer(address dst, uint wad) external override returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint wad
    ) external override returns (bool);
}
