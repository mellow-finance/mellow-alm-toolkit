// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/modules/IStrategyModule.sol";

import "../../libraries/external/FullMath.sol";

/**
 * @title PulseStrategyModule
 * @dev A strategy module that implements the Pulse V1 strategy and Lazy Pulse strategy.
 */
contract PulseStrategyModule is IStrategyModule {
    error InvalidParams();
    error InvalidLength();

    uint256 public constant Q96 = 2 ** 96;
    uint256 public constant D4 = 1e4;

    struct StrategyParams {
        int24 tickNeighborhood;
        int24 tickSpacing;
        bool lazyMode;
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
        if (info.tokenIds.length != 1) {
            revert InvalidLength();
        }
        IAmmModule.Position memory position = ammModule.getPositionInfo(
            info.tokenIds[0]
        );
        StrategyParams memory strategyParams = abi.decode(
            info.strategyParams,
            (StrategyParams)
        );
        (, int24 tick) = oracle.getOraclePrice(info.pool);
        return
            calculateTarget(
                tick,
                position.tickLower,
                position.tickUpper,
                strategyParams
            );
    }

    function _max(int24 a, int24 b) private pure returns (int24) {
        if (a < b) return b;
        return a;
    }

    function calculateTarget(
        int24 tick,
        int24 tickLower,
        int24 tickUpper,
        StrategyParams memory params
    )
        public
        pure
        returns (bool isRebalanceRequired, ICore.TargetNftsInfo memory target)
    {
        if (
            tick >= tickLower + params.tickNeighborhood &&
            tick <= tickUpper - params.tickNeighborhood
        ) {
            return (false, target);
        }

        int24 targetTickLower;
        int24 targetTickUpper;
        int24 positionWidth = tickUpper - tickLower;
        if (params.lazyMode) {
            int24 delta = -(tick % params.tickSpacing);
            if (tick < tickLower) {
                if (delta < 0) delta += params.tickSpacing;
                targetTickLower = tick + delta;
            } else {
                if (delta > 0) delta -= params.tickSpacing;
                targetTickLower = tick + delta - positionWidth;
            }
            targetTickUpper = targetTickLower + positionWidth;
        } else {
            targetTickLower = tick - positionWidth / 2;
            int24 remainder = targetTickLower % params.tickSpacing;
            if (remainder < 0) remainder += params.tickSpacing;
            targetTickLower -= remainder;
            targetTickUpper = targetTickLower + positionWidth;
            if (
                targetTickUpper < tick ||
                _max(tick - targetTickLower, targetTickUpper - tick) >
                _max(
                    tick - (targetTickLower + params.tickSpacing),
                    (targetTickUpper + params.tickSpacing) - tick
                )
            ) {
                targetTickLower += params.tickSpacing;
                targetTickUpper += params.tickSpacing;
            }
        }

        target.lowerTicks = new int24[](1);
        target.upperTicks = new int24[](1);
        target.lowerTicks[0] = targetTickLower;
        target.upperTicks[0] = targetTickUpper;
        target.liquidityRatiosX96 = new uint256[](1);
        target.liquidityRatiosX96[0] = Q96;
        isRebalanceRequired = true;
    }
}
