// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../interfaces/modules/velo/IVeloAmmModule.sol";
import "../../interfaces/utils/IVeloFarm.sol";

import "../../interfaces/external/terminal/ITerminalContracts.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/libraries/PositionMath.sol";

contract TerminalAmmModule is IVeloAmmModule {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /// @inheritdoc IAmmModule
    string public constant protocolName = "Terminal";

    /// @inheritdoc IAmmModule
    string public constant protocolSymbol = "TERM";

    /// @inheritdoc IAmmModule
    string public constant protocolLetter = "T";

    /// @inheritdoc IVeloAmmModule
    uint256 public constant D9 = 1e9;

    /// @inheritdoc IVeloAmmModule
    uint32 public constant MAX_PROTOCOL_FEE = 3e8; // 30%

    /// @inheritdoc IAmmModule
    address public immutable positionManager;

    /// @inheritdoc IVeloAmmModule
    address public immutable factory;

    /// @inheritdoc IVeloAmmModule
    bytes4 public immutable selectorIsPool;

    /// ---------------------- INITIALIZER FUNCTIONS ----------------------

    constructor(INonfungiblePositionManager positionManager_) {
        positionManager = address(positionManager_);
        factory = positionManager_.factory();
    }

    /// @inheritdoc IAmmModule
    function isPool(address pool) public view override returns (bool) {
        if (pool == address(0)) {
            return false;
        }
        return ITerminalPoolFactory(factory).getPool(
            ITerminalPool(pool).token0(),
            ITerminalPool(pool).token1(),
            ITerminalPool(pool).tickSpacing()
        ) == pool;
    }

    /// @inheritdoc IAmmModule
    function validateProtocolParams(bytes memory params) external pure {
        if (params.length != 0xa0) {
            revert InvalidLength();
        }
        IVeloAmmModule.ProtocolParams memory params_ =
            abi.decode(params, (IVeloAmmModule.ProtocolParams));
        if (params_.feeD9 > MAX_PROTOCOL_FEE) {
            revert InvalidFee();
        }
        if (params_.treasury == address(0)) {
            revert AddressZero();
        }
    }

    /// @inheritdoc IAmmModule
    function validateCallbackParams(address pool, bytes memory params) external view {
        if (params.length != 0xa0) {
            revert InvalidLength();
        }
        IVeloAmmModule.CallbackParams memory params_ =
            abi.decode(params, (IVeloAmmModule.CallbackParams));
        if (params_.farm == address(0) || params_.gauge == address(0)) {
            revert AddressZero();
        }
        if (ITerminalPool(pool).gauge() != params_.gauge) {
            revert InvalidGauge();
        }
        if (IGauge(params_.gauge).pool() != pool) {
            revert InvalidGauge();
        }
    }

    /// @inheritdoc IAmmModule
    function tvl(uint256 tokenId) external view returns (uint256 amount0, uint256 amount1) {
        return _tvl(tokenId, 0);
    }

    /// @inheritdoc IAmmModule
    function tvl(uint256 tokenId, uint160 sqrtPriceX96)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return _tvl(tokenId, sqrtPriceX96);
    }

    /// @inheritdoc IAmmModule
    function getAmmPosition(uint256 tokenId) external view returns (AmmPosition memory position) {
        int24 tickSpacing;
        INonfungiblePositionManager.Position memory pos;
        (position.token0, position.token1, tickSpacing, pos) =
            INonfungiblePositionManager(positionManager).positions(tokenId);
        position.property = uint24(tickSpacing);
        position.liquidity = pos.liquidity;
        position.tickLower = pos.tickLower;
        position.tickUpper = pos.tickUpper;
    }

    /// @inheritdoc IAmmModule
    function getPool(address token0, address token1, uint24 property)
        external
        view
        returns (address)
    {
        return ITerminalPoolFactory(factory).getPool(token0, token1, int24(property));
    }

    /// @inheritdoc IAmmModule
    function getProperty(address pool) external view returns (uint24) {
        return uint24(ITerminalPool(pool).tickSpacing());
    }

    /// @inheritdoc IAmmModule
    function getSqrtPriceX96(address pool) external view returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96,,,,,,,) = ITerminalPool(pool).slot0();
    }

    /// @inheritdoc IAmmModule
    function getSqrtPriceX96AndTick(address pool)
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick)
    {
        (sqrtPriceX96,,,,,,,) = ITerminalPool(pool).slot0();
        tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }

    /// @inheritdoc IAmmModule
    function getToken0(address pool) external view returns (address) {
        return ITerminalPool(pool).token0();
    }

    /// @inheritdoc IAmmModule
    function getToken1(address pool) external view returns (address) {
        return ITerminalPool(pool).token1();
    }

    /// @inheritdoc IAmmModule
    function getPoolTokens(address pool) external view returns (address, address) {
        return (ITerminalPool(pool).token0(), ITerminalPool(pool).token1());
    }

    /// @inheritdoc IAmmModule
    function getRewardToken(address pool) external view returns (address) {
        return ITerminalPool(pool).term();
    }

    /// @inheritdoc IAmmModule
    function getGauge(address pool) external view returns (address) {
        return ITerminalPool(pool).gauge();
    }

    /// @inheritdoc IAmmModule
    function collectRewards(
        uint256 tokenId,
        bytes memory callbackParams,
        bytes memory protocolParams
    ) public {
        CallbackParams memory callbackParams_ = abi.decode(callbackParams, (CallbackParams));
        ProtocolParams memory protocolParams_ = abi.decode(protocolParams, (ProtocolParams));
        address gauge = callbackParams_.gauge;
        address farm = callbackParams_.farm;
        uint256 balance;
        IERC20 token = IERC20(IGauge(gauge).term());

        if (_isStaked(tokenId)) {
            address this_ = address(this);
            balance = token.balanceOf(this_);

            /// @dev collect only rewards, fees are collected when transferring the NFT back to the user
            INonfungiblePositionManager(positionManager).collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: tokenId,
                    recipient: address(this),
                    amount0Max: 0,
                    amount1Max: 0,
                    rewardMax: type(uint128).max
                })
            );

            balance = token.balanceOf(this_) - balance;
            if (balance > 0) {
                uint256 protocolReward = Math.mulDiv(protocolParams_.feeD9, balance, D9);

                if (protocolReward > 0) {
                    token.safeTransfer(protocolParams_.treasury, protocolReward);
                }

                balance -= protocolReward;
                if (balance > 0) {
                    token.safeTransfer(farm, balance);
                }
            }
        }
        // we want to provide this information to the farm anyway, even if we don't have any rewards to distribute
        IVeloFarm(farm).distribute(balance, address(token));
    }

    /// @inheritdoc IAmmModule
    function beforeRebalance(
        uint256 tokenId,
        bytes memory callbackParams,
        bytes memory protocolParams
    ) external {
        if (!_isStaked(tokenId)) {
            return;
        }
        collectRewards(tokenId, callbackParams, protocolParams);
    }

    /// @inheritdoc IAmmModule
    function afterRebalance(
        uint256 tokenId,
        bytes memory callbackParams,
        bytes memory protocolParams
    ) external {
        /// @dev nothing to do since positions are staked upon minting and never unstaked
    }

    /// @inheritdoc IAmmModule
    function transferFrom(address from, address to, uint256 tokenId) external {
        INonfungiblePositionManager(positionManager).transferFrom(from, to, tokenId);
        if (to == address(this)) {
            /// @dev transfers unclaimed fees back to the user or to the callback address
            INonfungiblePositionManager(positionManager).collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: tokenId,
                    recipient: from,
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max,
                    rewardMax: type(uint128).max
                })
            );
        }
    }

    /// @inheritdoc IAmmModule
    function mint(address depositor, MintInfo[] memory mintInfo)
        external
        returns (uint256[] memory tokenIds)
    {
        uint256 maxAmount0;
        uint256 maxAmount1;
        for (uint256 i = 0; i < mintInfo.length; i++) {
            maxAmount0 += mintInfo[i].amount0;
            maxAmount1 += mintInfo[i].amount1;
        }
        address pool = mintInfo[0].pool;
        address token0 = ITerminalPool(pool).token0();
        address token1 = ITerminalPool(pool).token1();
        int24 tickSpacing = ITerminalPool(pool).tickSpacing();

        _handleToken(depositor, token0, maxAmount0);
        _handleToken(depositor, token1, maxAmount1);

        tokenIds = new uint256[](mintInfo.length);
        for (uint256 i = 0; i < mintInfo.length; i++) {
            (tokenIds[i],,,) = INonfungiblePositionManager(positionManager).mint(
                INonfungiblePositionManager.MintParams({
                    token0: token0,
                    token1: token1,
                    tickSpacing: tickSpacing,
                    tickLower: mintInfo[i].tickLower,
                    tickUpper: mintInfo[i].tickUpper,
                    isStaked: true,
                    amount0Desired: mintInfo[i].amount0,
                    amount1Desired: mintInfo[i].amount1,
                    amount0Min: 0,
                    amount1Min: 0,
                    recipient: address(this),
                    deadline: type(uint256).max
                })
            );
        }
    }

    /// @inheritdoc IAmmModule
    function approveTokenId(address to, uint256 tokenId) external {
        INonfungiblePositionManager(positionManager).approve(to, tokenId);
    }

    function swapOnPool(address pool, bool zeroForOne, uint256 amountIn)
        external
        returns (int256 amount0, int256 amount1)
    {
        if (amountIn == 0) {
            return (0, 0);
        }
        return ITerminalPool(pool).swap(
            address(this),
            zeroForOne,
            int256(amountIn),
            zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            ""
        );
    }

    function poolCallback(address pool, bytes4 selector, bytes memory callbackData) external {
        if (selector != ITerminalSwapCallback.terminalSwapCallback.selector) {
            revert ForbiddenCallback();
        }

        address token0 = ITerminalPool(pool).token0();
        address token1 = ITerminalPool(pool).token1();
        int24 tickSpacing = ITerminalPool(pool).tickSpacing();

        if (ITerminalPoolFactory(factory).getPool(token0, token1, tickSpacing) != pool) {
            revert ForbiddenPool();
        }

        (int256 amount0Delta, int256 amount1Delta,) =
            abi.decode(callbackData, (int256, int256, bytes));

        if (amount0Delta > 0) {
            SafeERC20.safeTransfer(IERC20(token0), pool, uint256(amount0Delta));
        }

        if (amount1Delta > 0) {
            SafeERC20.safeTransfer(IERC20(token1), pool, uint256(amount1Delta));
        }
    }

    function getInfo(uint256[] memory tokenIds) external view returns (Position[] memory data) {
        data = new Position[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            data[i] = getPosition(tokenIds[i]);
        }
    }

    function getPosition(uint256 tokenId) public view returns (Position memory position) {
        INonfungiblePositionManager.Position memory pos;
        (position.token0, position.token1, position.tickSpacing, pos) =
            INonfungiblePositionManager(positionManager).positions(tokenId);
        position.liquidity = pos.liquidity;
        position.tickLower = pos.tickLower;
        position.tickUpper = pos.tickUpper;
        position.nonce = pos.nonce;
        position.operator = pos.operator;
        position.feeGrowthInside0LastX128 = pos.revenueGrowthInside0LastX128;
        position.feeGrowthInside1LastX128 = pos.revenueGrowthInside1LastX128;
        position.tokensOwed0 = pos.owed.amount0;
        position.tokensOwed1 = pos.owed.amount1;
        position.tokenId = tokenId;
    }

    function total(uint256 tokenId, uint160 sqrtRatioX96)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (uint256 amount0Principal, uint256 amount1Principal) = principal(tokenId, sqrtRatioX96);
        (uint256 amount0Fee, uint256 amount1Fee) = fees(tokenId);
        return (amount0Principal + amount0Fee, amount1Principal + amount1Fee);
    }

    /// ---------------------- INTERNAL MUTABLE FUNCTIONS ----------------------

    function _tvl(uint256 tokenId, uint160 sqrtPriceX96)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        Position memory position = getPosition(tokenId);

        address pool = ITerminalPoolFactory(factory).getPool(
            position.token0, position.token1, position.tickSpacing
        );
        if (sqrtPriceX96 == 0) {
            (sqrtPriceX96,,,,,,,) = ITerminalPool(pool).slot0();
        }
        (amount0, amount1) = principal(tokenId, sqrtPriceX96);
        if (!_isStaked(tokenId)) {
            (uint256 fees0, uint256 fees1) = fees(tokenId);
            amount0 += fees0;
            amount1 += fees1;
        }
    }

    function _isStaked(uint256 tokenId) internal view returns (bool) {
        (,,, INonfungiblePositionManager.Position memory pos) =
            INonfungiblePositionManager(positionManager).positions(tokenId);
        return pos.isStaked;
    }

    function _handleToken(address depositor, address token, uint256 amount) internal {
        address this_ = address(this);
        uint256 balance = IERC20(token).balanceOf(this_);
        if (balance < amount) {
            IERC20(token).safeTransferFrom(depositor, this_, amount - balance);
        }
        if (IERC20(token).allowance(this_, address(positionManager)) == 0) {
            IERC20(token).forceApprove(address(positionManager), type(uint256).max);
        }
    }

    /**
     * @notice Calculates the principal amounts of token0 and token1 that would be returned if the position were burned.
     * @dev Uses liquidity and tick bounds of the position to compute the value based on the current market price.
     * @param tokenId The ID of the NFT position token to calculate the principal for.
     * @param sqrtRatioX96 The square root of the current price, in Q96 format, used for calculating principal.
     * @return amount0 The principal amount of token0.
     * @return amount1 The principal amount of token1.
     */
    function principal(uint256 tokenId, uint160 sqrtRatioX96)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        Position memory position = getPosition(tokenId);
        return LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            TickMath.getSqrtRatioAtTick(position.tickLower),
            TickMath.getSqrtRatioAtTick(position.tickUpper),
            position.liquidity
        );
    }

    /**
     * @notice Calculates the accrued fees in token0 and token1 for a Uniswap V3 NFT position.
     * @dev Fetches current fee growth from the pool and subtracts the last recorded fee growth for the position.
     *      The result is multiplied by the position’s liquidity to calculate total fees owed.
     * @param tokenId The ID of the NFT position token to calculate fees for.
     * @return amount0 The accrued fees in token0.
     * @return amount1 The accrued fees in token1.
     */
    function fees(uint256 tokenId) internal view returns (uint256 amount0, uint256 amount1) {
        (
            address token0,
            address token1,
            int24 tickSpacing,
            INonfungiblePositionManager.Position memory pos
        ) = INonfungiblePositionManager(positionManager).positions(tokenId);

        return _fees(
            FeeParams({
                token0: token0,
                token1: token1,
                tickSpacing: tickSpacing,
                tickLower: pos.tickLower,
                tickUpper: pos.tickUpper,
                liquidity: pos.liquidity,
                positionFeeGrowthInside0LastX128: pos.revenueGrowthInside0LastX128,
                positionFeeGrowthInside1LastX128: pos.revenueGrowthInside1LastX128,
                tokensOwed0: pos.owed.amount0,
                tokensOwed1: pos.owed.amount1
            })
        );
    }

    /**
     * @notice Calculates fees accrued within a given tick range in the Uniswap V3 pool.
     * @dev Uses unchecked math for gas efficiency and to compute fees based on liquidity and fee growth changes.
     * @param feeParams Struct containing position details needed for fee calculation.
     * @return amount0 The accrued fees in token0.
     * @return amount1 The accrued fees in token1.
     */
    function _fees(FeeParams memory feeParams)
        private
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (uint256 poolFeeGrowthInside0LastX128, uint256 poolFeeGrowthInside1LastX128) =
        _getFeeGrowthInside(
            ITerminalPool(
                ITerminalPoolFactory(INonfungiblePositionManager(positionManager).factory()).getPool(
                    feeParams.token0, feeParams.token1, feeParams.tickSpacing
                )
            ),
            feeParams.tickLower,
            feeParams.tickUpper
        );
        unchecked {
            amount0 = Math.mulDiv(
                poolFeeGrowthInside0LastX128 - feeParams.positionFeeGrowthInside0LastX128,
                feeParams.liquidity,
                PositionMath.Q128
            ) + feeParams.tokensOwed0;

            amount1 = Math.mulDiv(
                poolFeeGrowthInside1LastX128 - feeParams.positionFeeGrowthInside1LastX128,
                feeParams.liquidity,
                PositionMath.Q128
            ) + feeParams.tokensOwed1;
        }
    }

    /**
     * @notice Retrieves the fee growth for the given tick range in the pool.
     * @dev Fetches tick data from the pool and calculates fee growth based on the position of the current tick.
     * @param pool The Uniswap V3 pool to get fee growth data from.
     * @param tickLower The lower tick boundary of the position.
     * @param tickUpper The upper tick boundary of the position.
     * @return feeGrowthInside0X128 The fee growth inside the tick range for token0.
     * @return feeGrowthInside1X128 The fee growth inside the tick range for token1.
     */
    function _getFeeGrowthInside(ITerminalPool pool, int24 tickLower, int24 tickUpper)
        private
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        (, int24 tickCurrent,,,,,,) = pool.slot0();
        (,,, uint256 lowerFeeGrowthOutside0X128, uint256 lowerFeeGrowthOutside1X128,,,,,) =
            pool.ticks(tickLower);
        (,,, uint256 upperFeeGrowthOutside0X128, uint256 upperFeeGrowthOutside1X128,,,,,) =
            pool.ticks(tickUpper);

        unchecked {
            if (tickCurrent < tickLower) {
                feeGrowthInside0X128 = lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
                feeGrowthInside1X128 = lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
            } else if (tickCurrent < tickUpper) {
                (uint256 feeGrowthGlobal0X128, uint256 feeGrowthGlobal1X128,) = pool.growthGlobals();
                feeGrowthInside0X128 =
                    feeGrowthGlobal0X128 - lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
                feeGrowthInside1X128 =
                    feeGrowthGlobal1X128 - lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
            } else {
                feeGrowthInside0X128 = upperFeeGrowthOutside0X128 - lowerFeeGrowthOutside0X128;
                feeGrowthInside1X128 = upperFeeGrowthOutside1X128 - lowerFeeGrowthOutside1X128;
            }
        }
    }
}
