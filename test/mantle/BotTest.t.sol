// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Fixture.sol";

contract Integration is Test {
    using SafeERC20 for IERC20;

    INonfungiblePositionManager public positionManager =
        INonfungiblePositionManager(Constants.NONFUNGIBLE_POSITION_MANAGER);
    IAgniFactory public factory = IAgniFactory(Constants.AGNI_FACTORY);
    IAgniPool public pool =
        IAgniPool(factory.getPool(Constants.USDC, Constants.WETH, 2500));

    function testBot() external {
        Core core = Core(0x4b8e8aDbC9120ed438dF9DEe7ed0009f9D4B33E9);
        PulseAgniBot bot = PulseAgniBot(
            0x15b1bC5DF5C44F469394D295959bBEC861893F09
        );
        PulseStrategyModule strategyModule = PulseStrategyModule(
            0xc02a7B4658861108f9837007b2DF2007d6977116
        );
        AgniOracle oracle = AgniOracle(
            0x4c31e14F344CDD2921995C62F7a15Eea6B9E7521
        );
        AgniAmmModule ammModule = AgniAmmModule(
            0xCD8237f2b332e482DaEaA609D9664b739e93097d
        );

        uint256 nftId = 0;
        ICore.NftsInfo memory nft = core.nfts(nftId);

        (bool rebalanceRequired, ) = strategyModule.getTargets(
            nft,
            ammModule,
            oracle
        );
        console2.log(rebalanceRequired);

        (, int24 spotTick, , uint16 observationCardinality, , , ) = pool
            .slot0();
        console2.log(
            "Spot0 params:",
            vm.toString(spotTick),
            vm.toString(observationCardinality)
        );
    }
}
