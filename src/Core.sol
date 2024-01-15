// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./interfaces/ICore.sol";

import "./interfaces/modules/IAmmModule.sol";
import "./interfaces/modules/IStrategyModule.sol";

import "./interfaces/oracles/IOracle.sol";

import "./utils/DefaultAccessControl.sol";

contract Core is DefaultAccessControl, ICore {
    using EnumerableSet for EnumerableSet.UintSet;

    error DelegateCallFailed();
    error InvalidParameters();

    uint256 public constant D4 = 1e4;

    IAmmModule public immutable ammModule;
    IOracle public immutable oracle;
    IStrategyModule public immutable strategyModule;
    address public immutable positionManager;

    bool public operatorFlag;

    NftInfo[] private _nfts;
    mapping(address => EnumerableSet.UintSet) private _userIds;

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

    function nfts(uint256 index) public view override returns (NftInfo memory) {
        return _nfts[index];
    }

    function getUserIds(
        address user
    ) external view override returns (uint256[] memory ids) {
        return _userIds[user].values();
    }

    function setOperatorFlag(bool operatorFlag_) external override {
        _requireAdmin();
        operatorFlag = operatorFlag_;
    }

    function setPositionParams(
        uint256 id,
        uint16 slippageD4,
        bytes memory strategyParams,
        bytes memory securityParams
    ) external override {
        NftInfo memory info = _nfts[id];
        if (info.owner != msg.sender) revert Forbidden();
        strategyModule.validateStrategyParams(strategyParams);
        oracle.validateSecurityParams(securityParams);
        info.strategyParams = strategyParams;
        info.securityParams = securityParams;
        info.slippageD4 = slippageD4;
        _nfts[id] = info;
    }

    function deposit(
        DepositParams memory params
    ) external override returns (uint256 id) {
        IAmmModule.Position memory position = ammModule.getPositionInfo(
            params.tokenId
        );
        strategyModule.validateStrategyParams(params.strategyParams);
        oracle.validateSecurityParams(params.securityParams);
        if (params.slippageD4 * 4 > D4 || params.slippageD4 == 0)
            revert InvalidParameters();
        address pool = ammModule.getPool(
            position.token0,
            position.token1,
            position.property
        );
        if (pool == address(0)) revert InvalidParameters();
        if (params.tokenId == 0 || params.tokenId > type(uint80).max)
            revert InvalidParameters();
        if (position.liquidity == 0) revert InvalidParameters();
        IERC721(positionManager).transferFrom(
            params.owner,
            address(this),
            params.tokenId
        );
        {
            (bool success, ) = address(ammModule).delegatecall(
                abi.encodeWithSelector(
                    IAmmModule.afterRebalance.selector,
                    params.farm,
                    params.tokenId
                )
            );
            if (!success) revert DelegateCallFailed();
        }
        id = _nfts.length;
        _userIds[params.owner].add(id);
        _nfts.push(
            NftInfo({
                owner: params.owner,
                tokenId: uint80(params.tokenId),
                pool: pool,
                farm: params.farm,
                property: ammModule.getProperty(pool),
                tickLower: position.tickLower,
                tickUpper: position.tickUpper,
                slippageD4: params.slippageD4,
                strategyParams: params.strategyParams,
                securityParams: params.securityParams
            })
        );
    }

    function withdraw(uint256 id, address to) external override {
        NftInfo memory nftInfo = _nfts[id];
        if (nftInfo.tokenId == 0) revert();
        require(nftInfo.owner == msg.sender);
        _userIds[nftInfo.owner].remove(id);
        delete _nfts[id];
        {
            (bool success, ) = address(ammModule).delegatecall(
                abi.encodeWithSelector(
                    IAmmModule.beforeRebalance.selector,
                    nftInfo.farm,
                    nftInfo.tokenId
                )
            );
            if (!success) revert DelegateCallFailed();
        }
        IERC721(positionManager).transferFrom(
            address(this),
            to,
            nftInfo.tokenId
        );
    }

    function rebalance(RebalanceParams memory params) external override {
        if (operatorFlag) {
            _requireAtLeastOperator();
        }

        TargetNftInfo[] memory targets = new TargetNftInfo[](params.ids.length);
        uint256 iterator = 0;
        for (uint256 i = 0; i < params.ids.length; i++) {
            uint256 id = params.ids[i];
            NftInfo memory nftInfo = _nfts[id];
            oracle.ensureNoMEV(nftInfo.pool, nftInfo.securityParams);
            (bool flag, TargetNftInfo memory target) = strategyModule.getTarget(
                nftInfo,
                ammModule,
                oracle
            );
            if (!flag) continue;
            target.id = id;
            target.nftInfo = nftInfo;
            targets[iterator++] = target;
            {
                (bool success, ) = address(ammModule).delegatecall(
                    abi.encodeWithSelector(
                        IAmmModule.beforeRebalance.selector,
                        nftInfo.farm,
                        nftInfo.tokenId
                    )
                );
                if (!success) revert DelegateCallFailed();
            }
            IERC721(positionManager).transferFrom(
                address(this),
                params.callback,
                nftInfo.tokenId
            );
        }

        assembly {
            mstore(targets, iterator)
        }

        uint256[] memory newTokenIds = IRebalanceCallback(params.callback).call(
            params.data,
            targets
        );
        if (newTokenIds.length != iterator) revert InvalidParameters();
        for (uint256 i = 0; i < iterator; i++) {
            TargetNftInfo memory target = targets[i];
            IAmmModule.Position memory position = ammModule.getPositionInfo(
                newTokenIds[i]
            );
            if (
                position.liquidity < target.minLiquidity ||
                position.tickLower != target.tickLower ||
                position.tickUpper != target.tickUpper ||
                ammModule.getPool(
                    position.token0,
                    position.token1,
                    position.property
                ) !=
                target.nftInfo.pool
            ) revert InvalidParameters();
            IERC721(positionManager).transferFrom(
                params.callback,
                address(this),
                newTokenIds[i]
            );
            uint256 id = target.id;
            NftInfo memory nftInfo = _nfts[id];
            {
                (bool success, ) = address(ammModule).delegatecall(
                    abi.encodeWithSelector(
                        IAmmModule.afterRebalance.selector,
                        nftInfo.farm,
                        newTokenIds[i]
                    )
                );
                if (!success) revert DelegateCallFailed();
            }
            nftInfo.tickLower = position.tickLower;
            nftInfo.tickUpper = position.tickUpper;
            nftInfo.tokenId = uint80(newTokenIds[i]);
            _nfts[id] = nftInfo;
        }
    }
}
