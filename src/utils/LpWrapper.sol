// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "../interfaces/modules/IAmmModule.sol";
import "../interfaces/modules/IAmmDepositWithdrawModule.sol";

import "../interfaces/ICore.sol";

import "../libraries/external/FullMath.sol";

import "./DefaultAccessControlLateInit.sol";

contract LpWrapper is ERC20, DefaultAccessControlLateInit {
    error InsufficientAmounts();
    error InsufficientLpAmount();
    error AlreadyInitialized();
    error DepositCallFailed();
    error WithdrawCallFailed();

    address public immutable positionManager;
    IAmmDepositWithdrawModule public immutable ammDepositWithdrawModule;
    ICore public immutable core;
    IAmmModule public immutable ammModule;
    IOracle public immutable oracle;

    uint256 public tokenId;

    /**
     * @dev Constructor function for the LpWrapper contract.
     * @param core_ The address of the ICore contract.
     * @param ammDepositWithdrawModule_ The address of the IAmmDepositWithdrawModule contract.
     * @param name The name of the ERC20 token.
     * @param symbol The symbol of the ERC20 token.
     */
    constructor(
        ICore core_,
        IAmmDepositWithdrawModule ammDepositWithdrawModule_,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        core = core_;
        positionManager = core.positionManager();
        ammModule = core.ammModule();
        oracle = core.oracle();
        ammDepositWithdrawModule = ammDepositWithdrawModule_;
    }

    /**
     * @dev Initializes the LP wrapper contract with the given token ID and initial total supply.
     * @param tokenId_ The token ID to be associated with the LP wrapper contract.
     * @param initialTotalSupply The initial total supply of the LP wrapper contract.
     * @param admin The address of the admin of the LP wrapper contract.
     */
    function initialize(
        uint256 tokenId_,
        uint256 initialTotalSupply,
        address admin
    ) external {
        if (tokenId != 0) revert AlreadyInitialized();
        tokenId = tokenId_;
        _mint(address(this), initialTotalSupply);
        init(admin);
    }

    /**
     * @dev Deposits specified amounts of tokens into the LP wrapper contract and mints LP tokens to the specified address.
     * @param amount0 The amount of token0 to deposit.
     * @param amount1 The amount of token1 to deposit.
     * @param minLpAmount The minimum amount of LP tokens required to be minted.
     * @param to The address to receive the minted LP tokens.
     * @return actualAmount0 The actual amount of token0 deposited.
     * @return actualAmount1 The actual amount of token1 deposited.
     * @return lpAmount The amount of LP tokens minted.
     */
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

        uint256 n = info.tokenIds.length;
        IAmmModule.Position[]
            memory positionsBefore = new IAmmModule.Position[](n);
        for (uint256 i = 0; i < n; i++) {
            positionsBefore[i] = ammModule.getPositionInfo(info.tokenIds[i]);
        }

        uint256[] memory amounts0 = new uint256[](n);
        uint256[] memory amounts1 = new uint256[](n);
        {
            uint256 totalAmount0 = 0;
            uint256 totalAmount1 = 0;
            {
                (uint160 sqrtPriceX96, ) = oracle.getOraclePrice(info.pool);
                for (uint256 i = 0; i < n; i++) {
                    (amounts0[i], amounts1[i]) = ammModule
                        .getAmountsForLiquidity(
                            positionsBefore[i].liquidity,
                            sqrtPriceX96,
                            positionsBefore[i].tickLower,
                            positionsBefore[i].tickUpper
                        );
                    totalAmount0 += amounts0[i];
                    totalAmount1 += amounts1[i];
                }
            }
            for (uint256 i = 0; i < n; i++) {
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
            for (uint256 i = 0; i < n; i++) {
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
                if (!success) revert DepositCallFailed();
                (uint256 amount0_, uint256 amount1_) = abi.decode(
                    response,
                    (uint256, uint256)
                );

                actualAmount0 += amount0_;
                actualAmount1 += amount1_;
            }
        }

        IAmmModule.Position[] memory positionsAfter = new IAmmModule.Position[](
            n
        );
        for (uint256 i = 0; i < n; i++) {
            positionsAfter[i] = ammModule.getPositionInfo(info.tokenIds[i]);
        }

        uint256 totalSupply_ = totalSupply();
        for (uint256 i = 0; i < n; i++) {
            IERC721(positionManager).approve(address(core), info.tokenIds[i]);
        }

        lpAmount = type(uint256).max;
        for (uint256 i = 0; i < n; i++) {
            uint256 currentLpAmount = FullMath.mulDiv(
                positionsAfter[i].liquidity - positionsBefore[i].liquidity,
                totalSupply_,
                positionsBefore[i].liquidity
            );
            if (lpAmount > currentLpAmount) {
                lpAmount = currentLpAmount;
            }
        }

        if (lpAmount < minLpAmount) revert InsufficientLpAmount();
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

    /**
     * @dev Withdraws LP tokens and transfers the underlying assets to the specified address.
     * @param lpAmount The amount of LP tokens to withdraw.
     * @param minAmount0 The minimum amount of asset 0 to receive.
     * @param minAmount1 The minimum amount of asset 1 to receive.
     * @param to The address to transfer the underlying assets to.
     * @return amount0 The actual amount of asset 0 received.
     * @return amount1 The actual amount of asset 1 received.
     * @return actualLpAmount The actual amount of LP tokens withdrawn.
     */
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
                IERC721(positionManager).approve(
                    address(core),
                    info.tokenIds[i]
                );
                IAmmModule.Position memory position = ammModule.getPositionInfo(
                    info.tokenIds[i]
                );
                uint256 liquidity = FullMath.mulDiv(
                    position.liquidity,
                    actualLpAmount,
                    totalSupply_
                );
                if (liquidity == 0) continue;
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
                if (!success) revert WithdrawCallFailed();
                (uint256 actualAmount0, uint256 actualAmount1) = abi.decode(
                    response,
                    (uint256, uint256)
                );

                amount0 += actualAmount0;
                amount1 += actualAmount1;
            }
        }

        if (amount0 < minAmount0 || amount1 < minAmount1) {
            revert InsufficientAmounts();
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

    /**
     * @dev Sets the position parameters for a given ID.
     * @param slippageD4 The slippage value in basis points (0.01%).
     * @param strategyParams The strategy parameters.
     * @param securityParams The security parameters.
     * Requirements:
     * - The caller must have the ADMIN_ROLE.
     * - The strategy parameters must be valid.
     * - The security parameters must be valid.
     */
    function setPositionParams(
        uint16 slippageD4,
        bytes memory strategyParams,
        bytes memory securityParams
    ) external {
        _requireAdmin();
        core.setPositionParams(
            tokenId,
            slippageD4,
            strategyParams,
            securityParams
        );
    }
}
