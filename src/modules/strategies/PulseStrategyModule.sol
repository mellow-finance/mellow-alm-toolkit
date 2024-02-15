// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/modules/IStrategyModule.sol";

import "../../libraries/external/FullMath.sol";

/**
 * @title PulseStrategyModule
 * @dev A strategy module that implements the Pulse V1 strategy.
 */
contract PulseStrategyModule is IStrategyModule {
    error InvalidParams();
    error InvalidLength();

    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D4 = 1e4;

    struct StrategyParams {
        int24 tickNeighborhood;
        int24 tickSpacing;
    }

    /**
     * @dev Validates the strategy parameters.
     * @param params The encoded strategy parameters.
     * @notice throws InvalidParams if the tick neighborhood or tick spacing is zero.
     */
    function validateStrategyParams(
        bytes memory params
    ) external pure override {
        StrategyParams memory strategyParams = abi.decode(
            params,
            (StrategyParams)
        );
        if (
            strategyParams.tickNeighborhood == 0 ||
            strategyParams.tickSpacing == 0
        ) {
            revert InvalidParams();
        }
    }

    /**
     * @dev Retrieves the target information for rebalancing based on the given parameters.
     * @param info The NFTs information.
     * @param ammModule The AMM module.
     * @param oracle The oracle.
     * @return isRebalanceRequired A boolean indicating whether rebalancing is required.
     * @return target The target NFTs information for rebalancing.
     */
    function getTargets(
        ICore.NftsInfo memory info,
        IAmmModule ammModule,
        IOracle oracle
    )
        external
        view
        override
        returns (bool isRebalanceRequired, ICore.TargetNftsInfo memory target)
    {
        {
            StrategyParams memory strategyParams = abi.decode(
                info.strategyParams,
                (StrategyParams)
            );
            int24 tick;
            (, tick) = oracle.getOraclePrice(info.pool);
            if (info.tokenIds.length != 1) {
                revert InvalidLength();
            }
            uint256 tokenId = info.tokenIds[0];
            IAmmModule.Position memory position = ammModule.getPositionInfo(
                tokenId
            );
            if (
                tick >= position.tickLower + strategyParams.tickNeighborhood &&
                tick <= position.tickUpper - strategyParams.tickNeighborhood
            ) {
                return (false, target);
            }

            target.lowerTicks = new int24[](1);
            target.upperTicks = new int24[](1);
            target.liquidityRatiosX96 = new uint256[](1);

            int24 width = position.tickUpper - position.tickLower;
            target.lowerTicks[0] = tick - width / 2;
            int24 remainder = target.lowerTicks[0] % strategyParams.tickSpacing;
            if (remainder < 0) remainder += strategyParams.tickSpacing;
            target.lowerTicks[0] -= remainder;
            target.upperTicks[0] = target.lowerTicks[0] + width;
        }
        isRebalanceRequired = true;
        target.liquidityRatiosX96[0] = Q96;
    }
}
