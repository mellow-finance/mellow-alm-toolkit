// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/utils/ILpWrapper.sol";

import "../libraries/external/FullMath.sol";

import "./DefaultAccessControlLateInit.sol";

contract LpWrapper is ILpWrapper, ERC20, DefaultAccessControlLateInit {
    /// @inheritdoc ILpWrapper
    address public immutable positionManager;

    /// @inheritdoc ILpWrapper
    IAmmDepositWithdrawModule public immutable ammDepositWithdrawModule;

    /// @inheritdoc ILpWrapper
    ICore public immutable core;

    /// @inheritdoc ILpWrapper
    IAmmModule public immutable ammModule;

    /// @inheritdoc ILpWrapper
    IOracle public immutable oracle;

    /// @inheritdoc ILpWrapper
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

    /// @inheritdoc ILpWrapper
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

    /// @inheritdoc ILpWrapper
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

    /// @inheritdoc ILpWrapper
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

    /// @inheritdoc ILpWrapper
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

    function emptyRebalance() external {
        _requireAtLeastOperator();
        core.emptyRebalance(tokenId);
    }
}
