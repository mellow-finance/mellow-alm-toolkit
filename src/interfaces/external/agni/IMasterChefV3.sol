// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMasterChefV3 {
    function latestPeriodEndTime() external view returns (uint256);

    function latestPeriodStartTime() external view returns (uint256);

    function upkeep(uint256 amount, uint256 duration, bool withUpdate) external;

    function withdraw(
        uint256 _tokenId,
        address _to
    ) external returns (uint256 reward);

    function harvest(
        uint256 _tokenId,
        address _to
    ) external returns (uint256 reward);

    function AGNI() external view returns (IERC20);
}
