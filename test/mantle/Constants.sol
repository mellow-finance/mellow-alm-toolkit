// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

// import "forge-std/Test.sol";
// import "forge-std/Vm.sol";

// import "@openzeppelin/contracts/utils/Strings.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// import "@synthetix/contracts/StakingRewards.sol";

// import "../../src/Core.sol";
// import "../../src/bots/PulseAgniBot.sol";

// import "../../src/modules/agni/AgniAmmModule.sol";
// import "../../src/modules/agni/AgniDepositWithdrawModule.sol";
// import "../../src/modules/strategies/PulseStrategyModule.sol";
// import "../../src/oracles/AgniOracle.sol";

// import "../../src/interfaces/external/agni/IAgniFactory.sol";
// import "../../src/interfaces/external/agni/IAgniPool.sol";
// import "../../src/interfaces/external/agni/INonfungiblePositionManager.sol";

// import "../../src/libraries/external/agni/PositionValue.sol";
// import "../../src/libraries/external/LiquidityAmounts.sol";

// import "../../src/utils/LpWrapper.sol";

// library Constants {
//     address public constant USDC = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9;
//     address public constant WETH = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111;
//     address public constant USDT = 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE;
//     address public constant METH = 0xcDA86A272531e8640cD7F1a92c01839911B90bb0;
//     address public constant USDY = 0x5bE26527e817998A7206475496fDE1E68957c5A6;
//     address public constant AXLETH = 0xb829b68f57CC546dA7E5806A929e53bE32a4625D;

//     address public constant NONFUNGIBLE_POSITION_MANAGER =
//         0x218bf598D1453383e2F4AA7b14fFB9BfB102D637;
//     address public constant AGNI_FACTORY =
//         0x25780dc8Fc3cfBD75F33bFDAB65e969b603b2035;
//     address public constant AGNI_SWAP_ROUTER =
//         0x319B69888b0d11cEC22caA5034e25FfFBDc88421;
//     address public constant AGNI_QUOTER_V2 =
//         0xc4aaDc921E1cdb66c5300Bc158a313292923C0cb;
//     address public constant DEPLOYER = address(bytes20(keccak256("deployer")));
//     address public constant DEPOSITOR =
//         address(bytes20(keccak256("depositor-1")));
//     address public constant DEPOSITOR_2 =
//         address(bytes20(keccak256("depositor-2")));
//     address public constant DEPOSITOR_3 =
//         address(bytes20(keccak256("depositor-3")));
//     address public constant DEPOSITOR_4 =
//         address(bytes20(keccak256("depositor-4")));
//     address public constant OWNER = address(bytes20(keccak256("owner")));
// }
