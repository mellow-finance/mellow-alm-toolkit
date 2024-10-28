// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.25;

import "../../src.sol";

contract Addresses is Script {
    /// @dev addresses of current deployment
    uint256 immutable operatorPrivateKey = vm.envUint("OPERATOR_PRIVATE_KEY");
    uint256 immutable deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address immutable DEPLOYER = vm.addr(deployerPrivateKey);
    address immutable OPERATOR = vm.addr(operatorPrivateKey);
    address immutable CORE_ADMIN = 0x893df22649247AD4e57E4926731F9Cf0dA344829; // protocol msig
    address immutable PROTOCOL_TREASURY = 0xf0E36e9186Dbe927505d2588a6E6D56083Dd4a56; // treasury msig
    address immutable CORE_OPERATOR = 0x0A16Bc694EeA56cbFc808a271178556d3f8c23aD; // bot eoa

    // ================================================================================
    /// @dev deployed addresses
    Core core = Core(0x71D022eBA6F2607Ab8EC32Cb894075D94e10CEb8);
    VeloDeployFactory deployFactory = VeloDeployFactory(0xeD8b81E3fF6c54951621715F5992CA52007D88bA);
    Compounder compounder;
    VeloOracle oracle;
    PulseStrategyModule strategyModule;
    VeloDeployFactoryHelper velotrDeployFactoryHelper;
    VeloAmmModule ammModule;
    VeloDepositWithdrawModule veloDepositWithdrawModule;
    PulseVeloBotLazy pulseVeloBot;
    VeloSugarHelper veloSugarHelper;
}
