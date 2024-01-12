// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/modules/IAmmModule.sol";
import "../interfaces/modules/IAmmDepositWithdrawModule.sol";

import "../interfaces/IAmmIntent.sol";

import "../libraries/external/FullMath.sol";

contract LpIntent is ERC20 {
    IAmmDepositWithdrawModule public immutable ammDepositWithdrawModule;
    IAmmModule public immutable ammModule;
    IAmmIntent public immutable ammIntent;
    uint256 public tokenId;

    constructor(
        IAmmIntent ammIntent_,
        IAmmModule ammModule_,
        IAmmDepositWithdrawModule ammDepositWithdrawModule_,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        ammIntent = ammIntent_;
        ammModule = ammModule_;
        ammDepositWithdrawModule = ammDepositWithdrawModule_;
    }

    function initialize(uint256 tokenId_) external {
        if (tokenId != 0) revert();
        tokenId = tokenId_;
    }

    function deposit(
        uint256 amount0,
        uint256 amount1,
        uint256 minLpAmount,
        address to
    )
        external
        returns (uint256 actualAmount0, uint256 actualAmount1, uint256 lpAmount)
    {
        IAmmIntent.NftInfo memory info = ammIntent.nfts(tokenId);
        ammIntent.withdraw(tokenId, address(this));

        IAmmModule.Position memory positionBefore = ammModule.getPositionInfo(
            info.tokenId
        );

        if (amount0 > 0 || amount1 > 0) {
            (bool success, bytes memory response) = address(
                ammDepositWithdrawModule
            ).delegatecall(
                    abi.encodeWithSelector(
                        IAmmDepositWithdrawModule.deposit.selector,
                        info.tokenId,
                        amount0,
                        amount1,
                        msg.sender
                    )
                );
            if (!success) revert();
            (actualAmount0, actualAmount1) = abi.decode(
                response,
                (uint256, uint256)
            );
        }

        IAmmModule.Position memory positionAfter = ammModule.getPositionInfo(
            info.tokenId
        );

        lpAmount = FullMath.mulDiv(
            positionAfter.liquidity - positionBefore.liquidity,
            totalSupply(),
            positionBefore.liquidity
        );

        if (lpAmount < minLpAmount) {
            revert();
        }

        _mint(to, lpAmount);

        tokenId = ammIntent.deposit(
            IAmmIntent.DepositParams({
                tokenId: info.tokenId,
                owner: info.owner,
                farm: info.farm,
                slippageD4: info.slippageD4,
                strategyParams: info.strategyParams,
                securityParams: info.securityParams
            })
        );
    }

    function withdraw(
        uint256 lpAmount,
        uint256 minAmount0,
        uint256 minAmount1,
        address to
    )
        external
        returns (uint256 amount0, uint256 amount1, uint256 actualLpAmount)
    {
        IAmmIntent.NftInfo memory info = ammIntent.nfts(tokenId);
        ammIntent.withdraw(tokenId, address(this));

        {
            uint256 userBalance = balanceOf(msg.sender);
            if (userBalance < lpAmount) {
                actualLpAmount = userBalance;
            } else {
                actualLpAmount = lpAmount;
            }
        }

        IAmmModule.Position memory position = ammModule.getPositionInfo(
            info.tokenId
        );
        uint256 liquidityAmount = FullMath.mulDiv(
            position.liquidity,
            actualLpAmount,
            totalSupply()
        );

        if (liquidityAmount > 0) {
            (bool success, bytes memory response) = address(
                ammDepositWithdrawModule
            ).delegatecall(
                    abi.encodeWithSelector(
                        IAmmDepositWithdrawModule.withdraw.selector,
                        info.tokenId,
                        liquidityAmount,
                        msg.sender
                    )
                );
            if (!success) revert();
            (amount0, amount1) = abi.decode(response, (uint256, uint256));
        }

        if (amount0 < minAmount0 || amount1 < minAmount1) {
            revert();
        }

        _burn(to, actualLpAmount);

        tokenId = ammIntent.deposit(
            IAmmIntent.DepositParams({
                tokenId: info.tokenId,
                owner: info.owner,
                farm: info.farm,
                slippageD4: info.slippageD4,
                strategyParams: info.strategyParams,
                securityParams: info.securityParams
            })
        );
    }
}
