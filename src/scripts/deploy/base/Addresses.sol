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
    address immutable PROTOCOL_TREASURY =
        0xf0E36e9186Dbe927505d2588a6E6D56083Dd4a56; // treasury msig
    address immutable CORE_OPERATOR =
        0x0A16Bc694EeA56cbFc808a271178556d3f8c23aD; // bot eoa

    // ================================================================================
    /// @dev deployed addresses
    Core core = Core(0xd17613D91150a2345eCe9598D055C7197A1f5A71);
    VeloDeployFactory deployFactory =
        VeloDeployFactory(0x5B1b1aaC71bDca9Ed1dCb2AA357f678584db4029);
    CreateStrategyHelper createStrategyHelper =
        CreateStrategyHelper(0xfEcdcCA747Ad30b2f848b4af9BdC60a364F48410);
    Compounder compounder;
    VeloOracle oracle;
    PulseStrategyModule strategyModule;
    VeloDeployFactoryHelper velotrDeployFactoryHelper;
    VeloAmmModule ammModule;
    VeloDepositWithdrawModule veloDepositWithdrawModule;
    PulseVeloBotLazy pulseVeloBot;
    VeloSugarHelper veloSugarHelper;
}