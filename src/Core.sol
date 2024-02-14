// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./interfaces/ICore.sol";

import "./interfaces/modules/IAmmModule.sol";
import "./interfaces/modules/IStrategyModule.sol";

import "./interfaces/oracles/IOracle.sol";

import "./libraries/external/FullMath.sol";

import "./utils/DefaultAccessControl.sol";

contract Core is DefaultAccessControl, ICore {
    using EnumerableSet for EnumerableSet.UintSet;

    error DelegateCallFailed();
    error InvalidParameters();
    error InvalidLength();

    uint256 public constant D4 = 1e4;
    uint256 public constant Q96 = 2 ** 96;

    IAmmModule public immutable ammModule;
    IOracle public immutable oracle;
    IStrategyModule public immutable strategyModule;
    address public immutable positionManager;

    bool public operatorFlag;

    NftsInfo[] private _nfts;
    mapping(address => EnumerableSet.UintSet) private _userIds;

    /**
     * @dev Constructor function for the Core contract.
     * @param ammModule_ The address of the AMM module contract.
     * @param strategyModule_ The address of the strategy module contract.
     * @param oracle_ The address of the oracle contract.
     * @param positionManager_ The address of the position manager contract.
     * @param admin_ The address of the admin for the Core contract.
     */
    constructor(
        IAmmModule ammModule_,
        IStrategyModule strategyModule_,
        IOracle oracle_,
        address positionManager_,
        address admin_
    ) DefaultAccessControl(admin_) {
        ammModule = ammModule_;
        strategyModule = strategyModule_;
        oracle = oracle_;
        positionManager = positionManager_;
    }

    /**
     * @dev Retrieves the NftsInfo struct at the specified index.
     * @param index The index of the NftsInfo struct to retrieve.
     * @return The NftsInfo struct at the specified index.
     */
    function nfts(
        uint256 index
    ) public view override returns (NftsInfo memory) {
        return _nfts[index];
    }

    /**
     * @dev Returns the count of NFTs in the contract.
     * @return uint256 count of NFTs.
     */
    function nftCount() public view returns (uint256) {
        return _nfts.length;
    }

    /**
     * @dev Retrieves the array of user IDs associated with the given user address.
     * @param user The address of the user.
     * @return ids array of user IDs.
     */
    function getUserIds(
        address user
    ) external view override returns (uint256[] memory ids) {
        return _userIds[user].values();
    }

    /**
     * @dev Sets the operator flag to enable or disable operator functionality.
     * Only the admin can call this function.
     * @param operatorFlag_ The new value for the operator flag.
     */
    function setOperatorFlag(bool operatorFlag_) external override {
        _requireAdmin();
        operatorFlag = operatorFlag_;
    }

    /**
     * @dev Sets the position parameters for a given ID.
     * @param id The ID of the position.
     * @param slippageD4 The maximum permissible proportion of the capital allocated to positions
     * that can be used to compensate rebalancers for their services. A value of 10,000 (1e4) represents 100%.
     * @param strategyParams The strategy parameters.
     * @param securityParams The security parameters.
     * Requirements:
     * - The caller must be the owner of the position.
     * - The strategy parameters must be valid.
     * - The security parameters must be valid.
     */
    function setPositionParams(
        uint256 id,
        uint16 slippageD4,
        bytes memory strategyParams,
        bytes memory securityParams
    ) external override {
        NftsInfo memory info = _nfts[id];
        if (info.owner != msg.sender) revert Forbidden();
        strategyModule.validateStrategyParams(strategyParams);
        oracle.validateSecurityParams(securityParams);
        info.strategyParams = strategyParams;
        info.securityParams = securityParams;
        info.slippageD4 = slippageD4;
        _nfts[id] = info;
    }

    /**
     * @dev Deposits multiple tokens into the contract.
     * @param params The deposit parameters including strategy parameters, security parameters, slippage, and token IDs.
     * @return id The ID of the deposited tokens.
     */
    function deposit(
        DepositParams memory params
    ) external override returns (uint256 id) {
        strategyModule.validateStrategyParams(params.strategyParams);
        oracle.validateSecurityParams(params.securityParams);
        if (params.slippageD4 * 4 > D4 || params.slippageD4 == 0)
            revert InvalidParameters();

        address pool;
        for (uint256 i = 0; i < params.tokenIds.length; i++) {
            uint256 tokenId = params.tokenIds[i];
            if (tokenId == 0 || tokenId > type(uint80).max) {
                revert InvalidParameters();
            }

            IAmmModule.Position memory position = ammModule.getPositionInfo(
                tokenId
            );

            if (position.liquidity == 0) revert InvalidParameters();
            address positionPool = ammModule.getPool(
                position.token0,
                position.token1,
                position.property
            );

            if (positionPool == address(0)) {
                revert InvalidParameters();
            }

            if (pool == address(0)) {
                pool = positionPool;
            } else if (pool != positionPool) {
                revert InvalidParameters();
            }

            IERC721(positionManager).transferFrom(
                msg.sender,
                address(this),
                tokenId
            );

            {
                (bool success, ) = address(ammModule).delegatecall(
                    abi.encodeWithSelector(
                        IAmmModule.afterRebalance.selector,
                        params.farm,
                        params.vault,
                        tokenId
                    )
                );
                if (!success) revert DelegateCallFailed();
            }
        }
        id = _nfts.length;
        _userIds[params.owner].add(id);
        _nfts.push(
            NftsInfo({
                owner: params.owner,
                tokenIds: params.tokenIds,
                pool: pool,
                farm: params.farm,
                vault: params.vault,
                property: ammModule.getProperty(pool),
                slippageD4: params.slippageD4,
                strategyParams: params.strategyParams,
                securityParams: params.securityParams
            })
        );
    }

    /**
     * @dev Withdraws NFTs from the contract and transfers them to the specified address.
     * Only the owner of the NFTs can call this function.
     *
     * @param id The ID of the NFTs to withdraw.
     * @param to The address to transfer the NFTs to.
     */
    function withdraw(uint256 id, address to) external override {
        NftsInfo memory info = _nfts[id];
        if (info.tokenIds.length == 0) revert();
        if (info.owner != msg.sender) revert Forbidden();
        _userIds[info.owner].remove(id);
        delete _nfts[id];
        for (uint256 i = 0; i < info.tokenIds.length; i++) {
            uint256 tokenId = info.tokenIds[i];
            (bool success, ) = address(ammModule).delegatecall(
                abi.encodeWithSelector(
                    IAmmModule.beforeRebalance.selector,
                    info.farm,
                    info.vault,
                    tokenId
                )
            );
            if (!success) revert DelegateCallFailed();
            IERC721(positionManager).transferFrom(address(this), to, tokenId);
        }
    }

    /**
     * @dev Calculates the target capital in Token1X96 based on the given parameters.
     * @param target The TargetNftsInfo struct containing the target information.
     * @param sqrtPriceX96 The square root of the priceX96.
     * @param priceX96 The priceX96 value.
     * @return targetCapitalInToken1X96 The calculated target capital in Token1X96.
     */
    function _calculateTargetCapitalX96(
        TargetNftsInfo memory target,
        uint160 sqrtPriceX96,
        uint256 priceX96
    ) private view returns (uint256 targetCapitalInToken1X96) {
        for (uint256 j = 0; j < target.lowerTicks.length; j++) {
            {
                (uint256 amount0, uint256 amount1) = ammModule
                    .getAmountsForLiquidity(
                        uint128(target.liquidityRatiosX96[j]),
                        sqrtPriceX96,
                        target.lowerTicks[j],
                        target.upperTicks[j]
                    );
                targetCapitalInToken1X96 +=
                    FullMath.mulDiv(amount0, priceX96, Q96) +
                    amount1;
            }
        }
    }

    /**
     * @dev Rebalances the portfolio based on the given parameters.
     * @param params The parameters for rebalancing.
     *   - ids: An array of NFT IDs to rebalance.
     *   - callback: The address of the callback contract.
     *   - data: Additional data to be passed to the callback contract.
     */
    function rebalance(RebalanceParams memory params) external override {
        if (operatorFlag) {
            _requireAtLeastOperator();
        }
        TargetNftsInfo[] memory targets = new TargetNftsInfo[](
            params.ids.length
        );
        uint256 iterator = 0;
        for (uint256 i = 0; i < params.ids.length; i++) {
            uint256 id = params.ids[i];
            NftsInfo memory info = _nfts[id];
            oracle.ensureNoMEV(info.pool, info.securityParams);
            TargetNftsInfo memory target;
            {
                bool flag;
                (flag, target) = strategyModule.getTargets(
                    info,
                    ammModule,
                    oracle
                );
                if (!flag) continue;
            }
            (uint160 sqrtPriceX96, ) = oracle.getOraclePrice(info.pool);
            uint256 priceX96 = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, Q96);
            uint256 capitalInToken1 = 0;
            for (uint256 j = 0; j < info.tokenIds.length; j++) {
                uint256 tokenId = info.tokenIds[j];
                {
                    (uint256 amount0, uint256 amount1) = ammModule.tvl(
                        tokenId,
                        sqrtPriceX96,
                        info.pool,
                        info.farm
                    );
                    capitalInToken1 +=
                        FullMath.mulDiv(amount0, priceX96, Q96) +
                        amount1;
                }
                (bool success, ) = address(ammModule).delegatecall(
                    abi.encodeWithSelector(
                        IAmmModule.beforeRebalance.selector,
                        target.info.farm,
                        target.info.vault,
                        tokenId
                    )
                );
                if (!success) revert DelegateCallFailed();
                IERC721(positionManager).transferFrom(
                    address(this),
                    params.callback,
                    tokenId
                );
            }

            uint256 targetCapitalInToken1X96 = _calculateTargetCapitalX96(
                target,
                sqrtPriceX96,
                priceX96
            );
            target.minLiquidities = new uint256[](
                target.liquidityRatiosX96.length
            );
            for (uint256 j = 0; j < target.minLiquidities.length; j++) {
                target.minLiquidities[j] = FullMath.mulDiv(
                    target.liquidityRatiosX96[j],
                    capitalInToken1,
                    targetCapitalInToken1X96
                );
                target.minLiquidities[j] = FullMath.mulDiv(
                    target.minLiquidities[j],
                    D4 - info.slippageD4,
                    D4
                );
            }

            target.id = id;
            target.info = info;
            targets[iterator++] = target;
        }

        assembly {
            mstore(targets, iterator)
        }

        uint256[][] memory newTokenIds = IRebalanceCallback(params.callback)
            .call(params.data, targets);
        if (newTokenIds.length != iterator) revert InvalidLength();
        for (uint256 i = 0; i < iterator; i++) {
            TargetNftsInfo memory target = targets[i];
            uint256[] memory tokenIds = newTokenIds[i];

            if (tokenIds.length != target.liquidityRatiosX96.length) {
                revert InvalidLength();
            }
            for (uint256 j = 0; j < tokenIds.length; j++) {
                uint256 tokenId = tokenIds[j];
                IAmmModule.Position memory position = ammModule.getPositionInfo(
                    tokenId
                );
                if (
                    position.liquidity < target.minLiquidities[j] ||
                    position.tickLower != target.lowerTicks[j] ||
                    position.tickUpper != target.upperTicks[j] ||
                    ammModule.getPool(
                        position.token0,
                        position.token1,
                        position.property
                    ) !=
                    target.info.pool
                ) revert InvalidParameters();
                IERC721(positionManager).transferFrom(
                    params.callback,
                    address(this),
                    tokenId
                );
                {
                    (bool success, ) = address(ammModule).delegatecall(
                        abi.encodeWithSelector(
                            IAmmModule.afterRebalance.selector,
                            target.info.farm,
                            target.info.vault,
                            tokenId
                        )
                    );
                    if (!success) revert DelegateCallFailed();
                }
            }
            _nfts[target.id].tokenIds = tokenIds;
        }
    }
}
