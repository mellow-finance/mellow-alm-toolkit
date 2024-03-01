// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IAmmDepositWithdrawModule {
    function deposit(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1,
        address from
    ) external returns (uint256 actualAmount0, uint256 actualAmount1);

    function withdraw(
        uint256 tokenId,
        uint256 liquidity,
        address to
    ) external returns (uint256 actualAmount0, uint256 actualAmount1);
}
