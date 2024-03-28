// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "forge-std/Vm.sol";

import "@synthetix/contracts/StakingRewards.sol";

import "../../../interfaces/external/velo/ISwapRouter.sol";

import "../../../Core.sol";
import "../../../utils/VeloDeployFactory.sol";
import "../../../utils/VeloDeployFactoryHelper.sol";

import "../../../modules/velo/VeloAmmModule.sol";
import "../../../modules/velo/VeloDepositWithdrawModule.sol";

import "../../../modules/strategies/PulseStrategyModule.sol";

import "../../../oracles/VeloOracle.sol";

contract Deploy is Script {
    // constants:
    address public constant QUOTER_V2 =
        0xA2DEcF05c16537C702779083Fe067e308463CE45;
    address public constant SWAP_ROUTER =
        0x5F9a4bb5d3b0c5e233Ee3cB35701077504a6F0eb;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant OP = 0x4200000000000000000000000000000000000042;
    address public constant VELO = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;

    address public immutable VELO_DEPLOY_FACTORY_ADMIN =
        vm.envAddress("VELO_DEPLOY_FACTORY_ADMIN_ADDRESS");
    address public immutable VELO_DEPLOY_FACTORY_OPERATOR =
        vm.envAddress("VELO_DEPLOY_FACTORY_OPERATOR_ADDRESS");
    address public immutable CORE_ADMIN = vm.envAddress("CORE_ADMIN_ADDRESS");
    address public immutable CORE_OPERATOR =
        vm.envAddress("CORE_OPERATOR_ADDRESS");
    address public immutable MELLOW_PROTOCOL_TREASURY =
        vm.envAddress("MELLOW_PROTOCOL_TREASURY_ADDRESS");
    address public immutable WRAPPER_ADMIN =
        vm.envAddress("WRAPPER_ADMIN_ADDRESS");
    address public immutable FARM_OWNER = vm.envAddress("FARM_OWNER_ADDRESS");
    address public immutable FARM_OPERATOR =
        vm.envAddress("FARM_OPERATOR_ADDRESS");
    uint32 public immutable MELLOW_PROTOCOL_FEE = 1e8;
    address public immutable DEPOSITOR = vm.envAddress("DEPOSITOR_ADDRESS");
    address public immutable USER = vm.envAddress("USER_ADDRESS");

    address public immutable DEPLOYER =
        0x7ee9247b6199877F86703644c97784495549aC5E;

    INonfungiblePositionManager public positionManager =
        INonfungiblePositionManager(0xbB5DFE1380333CEE4c2EeBd7202c80dE2256AdF4);
    ICLFactory public factory = ICLFactory(positionManager.factory());
    ISwapRouter public swapRouter = ISwapRouter(SWAP_ROUTER);

    VeloOracle public oracle;
    VeloAmmModule public ammModule;
    VeloDepositWithdrawModule public dwModule;
    PulseStrategyModule public strategyModule;
    Core public core;
    VeloDeployFactory public deployFactory;
    VeloDeployFactoryHelper public deployFactoryHelper;

    function _deployContracts() private {
        vm.startBroadcast(uint256(bytes32(vm.envBytes("DEPLOYER_PK"))));
        ammModule = new VeloAmmModule(positionManager);
        dwModule = new VeloDepositWithdrawModule(positionManager);
        strategyModule = new PulseStrategyModule();
        oracle = new VeloOracle();
        core = new Core(ammModule, strategyModule, oracle, CORE_ADMIN);
        deployFactoryHelper = new VeloDeployFactoryHelper();
        deployFactory = new VeloDeployFactory(
            VELO_DEPLOY_FACTORY_ADMIN,
            core,
            dwModule,
            deployFactoryHelper
        );

        IERC20(WETH).transfer(address(deployFactory), 1e6);
        IERC20(OP).transfer(address(deployFactory), 1e6);
        vm.stopBroadcast();

        vm.startBroadcast(uint256(bytes32(vm.envBytes("CORE_ADMIN_PK"))));
        core.grantRole(core.ADMIN_DELEGATE_ROLE(), CORE_ADMIN);
        core.grantRole(core.OPERATOR(), CORE_OPERATOR);
        core.setProtocolParams(
            abi.encode(
                IVeloAmmModule.ProtocolParams({
                    feeD9: MELLOW_PROTOCOL_FEE,
                    treasury: MELLOW_PROTOCOL_TREASURY
                })
            )
        );

        vm.stopBroadcast();
        vm.startBroadcast(
            uint256(bytes32(vm.envBytes("VELO_DEPLOY_FACTORY_ADMIN_PK")))
        );

        deployFactory.updateMutableParams(
            IVeloDeployFactory.MutableParams({
                lpWrapperAdmin: WRAPPER_ADMIN,
                farmOwner: FARM_OWNER,
                farmOperator: FARM_OPERATOR,
                rewardsToken: VELO
            })
        );

        ICore.DepositParams memory depositParams;
        depositParams.slippageD4 = 5;
        depositParams.securityParams = new bytes(0);

        deployFactory.updateStrategyParams(
            1,
            IVeloDeployFactory.StrategyParams({
                tickNeighborhood: 0,
                intervalWidth: 3,
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                initialLiquidity: 1000000,
                minInitialLiquidity: 800000
            })
        );

        deployFactory.updateDepositParams(1, depositParams);

        deployFactory.updateStrategyParams(
            50,
            IVeloDeployFactory.StrategyParams({
                tickNeighborhood: 0,
                intervalWidth: 200,
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                initialLiquidity: 100000,
                minInitialLiquidity: 80000
            })
        );
        deployFactory.updateDepositParams(50, depositParams);

        deployFactory.updateStrategyParams(
            100,
            IVeloDeployFactory.StrategyParams({
                tickNeighborhood: 0,
                intervalWidth: 500,
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                initialLiquidity: 100000,
                minInitialLiquidity: 80000
            })
        );
        deployFactory.updateDepositParams(100, depositParams);

        deployFactory.updateStrategyParams(
            200,
            IVeloDeployFactory.StrategyParams({
                tickNeighborhood: 0,
                intervalWidth: 1000,
                strategyType: IPulseStrategyModule.StrategyType.LazySyncing,
                initialLiquidity: 100000,
                minInitialLiquidity: 80000
            })
        );
        deployFactory.updateDepositParams(200, depositParams);

        deployFactory.updateStrategyParams(
            2000,
            IVeloDeployFactory.StrategyParams({
                tickNeighborhood: 1000,
                intervalWidth: 10000,
                strategyType: IPulseStrategyModule.StrategyType.Original,
                initialLiquidity: 10000,
                minInitialLiquidity: 8000
            })
        );
        deployFactory.updateDepositParams(2000, depositParams);

        deployFactory.grantRole(
            deployFactory.ADMIN_DELEGATE_ROLE(),
            VELO_DEPLOY_FACTORY_ADMIN
        );

        deployFactory.grantRole(
            deployFactory.OPERATOR(),
            VELO_DEPLOY_FACTORY_OPERATOR
        );

        vm.stopBroadcast();
    }

    function deal(address token, address user, uint256 amount) public view {
        uint256 userBalance = IERC20(token).balanceOf(user);
        if (userBalance < amount) {
            revert(
                string(
                    abi.encodePacked(
                        "Insufficient balance. Required: ",
                        vm.toString(amount),
                        "; Actual: ",
                        vm.toString(userBalance)
                    )
                )
            );
        }
    }

    function createStrategy(
        ICLPool pool
    ) public returns (IVeloDeployFactory.PoolAddresses memory addresses) {
        vm.startBroadcast(
            uint256(bytes32(vm.envBytes("VELO_DEPLOY_FACTORY_ADMIN_PK")))
        );
        pool.increaseObservationCardinalityNext(2);
        deal(pool.token0(), address(deployFactory), 1e6);
        deal(pool.token1(), address(deployFactory), 1e6);

        addresses = deployFactory.createStrategy(
            pool.token0(),
            pool.token1(),
            pool.tickSpacing()
        );
        vm.stopBroadcast();
    }

    function build(
        int24 tickSpacing
    ) public returns (ILpWrapper wrapper, StakingRewards farm, ICLPool pool) {
        pool = ICLPool(factory.getPool(WETH, OP, tickSpacing));
        IVeloDeployFactory.PoolAddresses memory addresses = createStrategy(
            pool
        );
        wrapper = ILpWrapper(addresses.lpWrapper);
        farm = StakingRewards(addresses.synthetixFarm);
    }

    function _validateBalances() private view {
        require(
            DEPLOYER.balance >= 0.07 ether,
            "Insufficient balance for DEPOSITOR_ADDRESS"
        );
        require(
            vm.envAddress("VELO_DEPLOY_FACTORY_ADMIN_ADDRESS").balance >=
                0.07 ether,
            "Insufficient balance for VELO_DEPLOY_FACTORY_ADMIN_ADDRESS"
        );
        require(
            vm.envAddress("CORE_ADMIN_ADDRESS").balance >= 0.03 ether,
            "Insufficient balance for CORE_ADMIN_PK"
        );
    }

    function run() external {
        _validateBalances();
        _deployContracts();
        (ILpWrapper wrapper, StakingRewards farm, ICLPool pool) = build(200);
        console2.log("Wrapper:", address(wrapper));
        console2.log("StakingRewards:", address(farm));
        console2.log("ICLPool:", address(pool));
    }
}
