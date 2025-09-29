// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "scripts/deploy/DeployScript.sol";
import "src/interfaces/ICore.sol";
import "src/interfaces/modules/velo/IVeloAmmModule.sol";
import "src/interfaces/utils/ILpStaker.sol";
import "src/interfaces/utils/ILpWrapper.sol";
import "src/utils/VeloDeployFactory.sol";

interface ISugarHelper {
    struct CoreDeployment {
        address core;
        address ammModule;
        address depositWithdrawModule;
        address oracle;
        address strategyModule;
        address deployFactory;
        address lpWrapperImplementation;
        address lpStakerImplementation;
    }

    struct TokenData {
        address addr;
        uint256 amountALM;
        uint256 amountPool;
        uint256 amountStaker;
        uint8 decimals;
        string symbol;
    }

    struct StrategyData {
        address pool;
        address lpStaker;
        address lpWrapper;
        uint256 supply;
        uint256 supplyLimit;
        string name;
        string symbol;
        TokenData tokenData0;
        TokenData tokenData1;
    }
}

contract SugarHelper is ISugarHelper {
    VeloDeployFactory public immutable factory;
    address public immutable core;
    address public immutable ammModule;
    address public immutable depositWithdrawModule;
    address public immutable oracle;
    address public immutable strategyModule;
    address public immutable deployFactory;
    address public immutable lpWrapperImplementation;
    address public immutable lpStakerImplementation;

    constructor(address deployFactoryAddress) {
        factory = VeloDeployFactory(payable(deployFactoryAddress));
        core = address(factory.core());
        ammModule = address(ICore(core).ammModule());
        depositWithdrawModule = address(ICore(core).ammDepositWithdrawModule());
        oracle = address(ICore(core).oracle());
        strategyModule = address(ICore(core).strategyModule());
        lpWrapperImplementation = factory.lpWrapperImplementation();
        lpStakerImplementation = factory.lpStakerImplementation();
    }

    function getCoreDeployment() internal view returns (CoreDeployment memory contracts) {
        contracts.deployFactory = address(factory);
        contracts.core = core;
        contracts.ammModule = ammModule;
        contracts.depositWithdrawModule = depositWithdrawModule;
        contracts.oracle = oracle;
        contracts.strategyModule = strategyModule;
        contracts.deployFactory = deployFactory;
        contracts.lpWrapperImplementation = lpWrapperImplementation;
        contracts.lpStakerImplementation = lpStakerImplementation;
    }

    function getManagedPoolPositions() external view returns (StrategyData[] memory data) {
        ICore core = factory.core();
        uint256 positionCount = core.positionCount();
        uint256 length;
        bool belongFactory;
        data = new StrategyData[](positionCount);
        for (uint256 i = 0; i < positionCount; i++) {
            (data[length], belongFactory) = positionData(core.managedPositionAt(i).owner);
            if (belongFactory) {
                length++;
            }
        }
        assembly {
            mstore(data, length)
        }
    }

    function positionData(address lpWrapper)
        public
        view
        returns (StrategyData memory data, bool belongFactory)
    {
        if (!factory.isEntity(lpWrapper)) {
            return (data, false);
        }
        belongFactory = true;
        uint256 positionId = ILpWrapper(lpWrapper).positionId();
        ICore core = ICore(ILpWrapper(lpWrapper).core());
        IAmmModule ammModule = core.ammModule();
        ICore.ManagedPositionInfo memory position = core.managedPositionAt(positionId);

        data.pool = ILpWrapper(lpWrapper).pool();
        data.lpWrapper = lpWrapper;
        data.supply = IERC20(lpWrapper).totalSupply();
        data.supplyLimit = ILpWrapper(lpWrapper).totalSupplyLimit();
        data.name = ERC20(lpWrapper).name();
        data.symbol = ERC20(lpWrapper).symbol();
        data.lpStaker = ILpWrapper(lpWrapper).lpStaker();
        data.tokenData0 = getTokenData(ILpWrapper(lpWrapper).token0());
        data.tokenData1 = getTokenData(ILpWrapper(lpWrapper).token1());

        for (uint256 id = 0; id < position.ammPositionIds.length; id++) {
            (uint256 amount0, uint256 amount1) = ammModule.tvl(position.ammPositionIds[id]);
            data.tokenData0.amountALM += amount0;
            data.tokenData1.amountALM += amount1;
        }
        data.tokenData0.amountPool = IERC20(data.tokenData0.addr).balanceOf(data.pool);
        data.tokenData1.amountPool = IERC20(data.tokenData1.addr).balanceOf(data.pool);

        if (data.lpStaker != address(0)) {
            (data.tokenData0.amountStaker, data.tokenData1.amountStaker) = ILpWrapper(lpWrapper)
                .previewBurn(IERC20(address(lpWrapper)).balanceOf(data.lpStaker));
        }
    }

    function getTokenData(address addr) internal view returns (TokenData memory token) {
        token.addr = addr;
        token.symbol = ERC20(addr).symbol();
        token.decimals = ERC20(addr).decimals();
    }

    function managedPositionInfo(address lpWrapper)
        public
        view
        returns (uint256 positionId, ICore.ManagedPositionInfo memory managedPositionInfo)
    {
        positionId = ILpWrapper(lpWrapper).positionId();
        ICore core = ICore(ILpWrapper(lpWrapper).core());
        managedPositionInfo = core.managedPositionAt(positionId);
    }

    function needRebalancePositions() public view returns (address[] memory lpWrappers) {
        ICore core = factory.core();
        IStrategyModule strategyModule = core.strategyModule();
        uint256 positionCount = core.positionCount();
        lpWrappers = new address[](positionCount);
        IAmmModule ammModule = core.ammModule();
        IOracle oracle = core.oracle();
        uint256 length;
        for (uint256 i = 0; i < positionCount; i++) {
            ICore.ManagedPositionInfo memory managedPositionInfo = core.managedPositionAt(i);
            (bool isRebalanceRequired,) =
                strategyModule.getTargets(managedPositionInfo, ammModule, oracle);
            if (isRebalanceRequired && factory.isEntity(managedPositionInfo.owner)) {
                lpWrappers[length] = managedPositionInfo.owner;
                length++;
            }
        }
        assembly {
            mstore(lpWrappers, length)
        }
    }

    function needRebalancePosition(address lpWrapper)
        public
        view
        returns (bool isRebalanceRequired)
    {
        (, ICore.ManagedPositionInfo memory managedPositionInfo) = managedPositionInfo(lpWrapper);
        (isRebalanceRequired,) = ICore(core).strategyModule().getTargets(
            managedPositionInfo, IAmmModule(ammModule), IOracle(oracle)
        );
    }

    function getStrategyParams(address lpWrapper)
        public
        view
        returns (IPulseStrategyModule.StrategyParams memory strategyParams)
    {
        (, ICore.ManagedPositionInfo memory managedPositionInfo) = managedPositionInfo(lpWrapper);
        return abi.decode(managedPositionInfo.strategyParams, (IPulseStrategyModule.StrategyParams));
    }

    function getSecurityParams(address lpWrapper)
        public
        view
        returns (IVeloOracle.SecurityParams memory securityParams)
    {
        (, ICore.ManagedPositionInfo memory managedPositionInfo) = managedPositionInfo(lpWrapper);
        return abi.decode(managedPositionInfo.securityParams, (IVeloOracle.SecurityParams));
    }
}
