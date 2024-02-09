// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/modules/IAmmModule.sol";
import "../interfaces/modules/IAmmDepositWithdrawModule.sol";

import "../interfaces/ICore.sol";

import "../libraries/external/FullMath.sol";

// import "./external/StakingRewards.sol";

contract LpFarmWrapper is ERC20 {
    IAmmDepositWithdrawModule public immutable ammDepositWithdrawModule;
    ICore public immutable core;
    IAmmModule public immutable ammModule;
    IOracle public immutable oracle;
    uint256 public tokenId;

    constructor(
        ICore core_,
        IAmmDepositWithdrawModule ammDepositWithdrawModule_,
        string memory name,
        string memory symbol
    )
        // ,
        // address farmOwner,
        // address farmOperator,
        // address rewardToken
        ERC20(name, symbol)
    // StakingRewards(farmOwner, farmOperator, rewardToken, address(this))
    {
        core = core_;
        ammModule = core.ammModule();
        oracle = core.oracle();
        ammDepositWithdrawModule = ammDepositWithdrawModule_;
        // IERC20(address(this)).safeApprove(address(this), type(uint256).max);
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
        ICore.NftsInfo memory info = core.nfts(tokenId);
        core.withdraw(tokenId, address(this));

        IAmmModule.Position[]
            memory positionsBefore = new IAmmModule.Position[](
                info.tokenIds.length
            );
        for (uint256 i = 0; i < positionsBefore.length; i++) {
            positionsBefore[i] = ammModule.getPositionInfo(info.tokenIds[i]);
        }

        uint256[] memory amounts0 = new uint256[](positionsBefore.length);
        uint256[] memory amounts1 = new uint256[](positionsBefore.length);

        {
            (uint160 sqrtPriceX96, ) = oracle.getOraclePrice(
                info.pool,
                info.securityParams
            );
            uint256 totalAmount0 = 0;
            uint256 totalAmount1 = 0;
            for (uint256 i = 0; i < positionsBefore.length; i++) {
                (amounts0[i], amounts1[i]) = ammModule.getAmountsForLiquidity(
                    positionsBefore[i].liquidity,
                    sqrtPriceX96,
                    positionsBefore[i].tickLower,
                    positionsBefore[i].tickUpper
                );
                totalAmount0 += amounts0[i];
                totalAmount1 += amounts1[i];
            }
            for (uint256 i = 0; i < positionsBefore.length; i++) {
                amounts0[i] = FullMath.mulDiv(
                    amount0,
                    amounts0[i],
                    totalAmount0
                );
                amounts1[i] = FullMath.mulDiv(
                    amount1,
                    amounts1[i],
                    totalAmount1
                );
            }
        }
        if (amount0 > 0 || amount1 > 0) {
            for (uint256 i = 0; i < positionsBefore.length; i++) {
                (bool success, bytes memory response) = address(
                    ammDepositWithdrawModule
                ).delegatecall(
                        abi.encodeWithSelector(
                            IAmmDepositWithdrawModule.deposit.selector,
                            info.tokenIds[i],
                            amounts0[i],
                            amounts1[i],
                            msg.sender
                        )
                    );
                if (!success) revert();
                (uint256 amount0_, uint256 amount1_) = abi.decode(
                    response,
                    (uint256, uint256)
                );

                actualAmount0 += amount0_;
                actualAmount1 += amount1_;
            }
        }

        IAmmModule.Position[] memory positionsAfter = new IAmmModule.Position[](
            positionsBefore.length
        );
        for (uint256 i = 0; i < positionsAfter.length; i++) {
            positionsAfter[i] = ammModule.getPositionInfo(info.tokenIds[i]);
        }

        uint256 totalSupply_ = totalSupply();
        lpAmount = type(uint256).max;

        for (uint256 i = 0; i < positionsAfter.length; i++) {
            uint256 currentLpAmount = FullMath.mulDiv(
                positionsAfter[i].liquidity - positionsBefore[i].liquidity,
                totalSupply_,
                positionsBefore[i].liquidity
            );
            if (lpAmount > currentLpAmount) {
                lpAmount = currentLpAmount;
            }
        }

        if (lpAmount < minLpAmount) {
            revert();
        }

        _mint(to, lpAmount);

        tokenId = core.deposit(
            ICore.DepositParams({
                tokenIds: info.tokenIds,
                owner: info.owner,
                farm: info.farm,
                vault: info.vault,
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
        ICore.NftsInfo memory info = core.nfts(tokenId);
        core.withdraw(tokenId, address(this));

        actualLpAmount = balanceOf(msg.sender);
        if (actualLpAmount > lpAmount) {
            actualLpAmount = lpAmount;
        }

        uint256 totalSupply_ = totalSupply();
        _burn(msg.sender, actualLpAmount);

        {
            for (uint256 i = 0; i < info.tokenIds.length; i++) {
                IAmmModule.Position memory position = ammModule.getPositionInfo(
                    info.tokenIds[i]
                );
                uint256 liquidity = FullMath.mulDiv(
                    position.liquidity,
                    actualLpAmount,
                    totalSupply_
                );
                (bool success, bytes memory response) = address(
                    ammDepositWithdrawModule
                ).delegatecall(
                        abi.encodeWithSelector(
                            IAmmDepositWithdrawModule.withdraw.selector,
                            info.tokenIds[i],
                            liquidity,
                            to
                        )
                    );
                if (!success) revert();
                (uint256 actualAmount0, uint256 actualAmount1) = abi.decode(
                    response,
                    (uint256, uint256)
                );

                amount0 += actualAmount0;
                amount1 += actualAmount1;
            }
        }

        if (amount0 < minAmount0 || amount1 < minAmount1) {
            revert();
        }

        tokenId = core.deposit(
            ICore.DepositParams({
                tokenIds: info.tokenIds,
                owner: info.owner,
                farm: info.farm,
                vault: info.vault,
                slippageD4: info.slippageD4,
                strategyParams: info.strategyParams,
                securityParams: info.securityParams
            })
        );
    }
}
