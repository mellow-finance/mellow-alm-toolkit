// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../../interfaces/modules/velo/IVeloAmmModule.sol";

contract VeloAmmModule is IVeloAmmModule {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /// @inheritdoc IAmmModule
    string public constant protocolName = "Velodrome";

    /// @inheritdoc IAmmModule
    string public constant protocolSymbol = "VELO";

    /// @inheritdoc IAmmModule
    string public constant protocolLetter = "V";

    /// @inheritdoc IVeloAmmModule
    uint256 public constant D9 = 1e9;

    /// @inheritdoc IVeloAmmModule
    uint32 public constant MAX_PROTOCOL_FEE = 3e8; // 30%

    /// @inheritdoc IAmmModule
    address public immutable positionManager;

    /// @inheritdoc IVeloAmmModule
    ICLFactory public immutable factory;

    /// @inheritdoc IVeloAmmModule
    bytes4 public immutable selectorIsPool;

    /// ---------------------- INITIALIZER FUNCTIONS ----------------------

    constructor(INonfungiblePositionManager positionManager_, bytes4 selectorIsPool_) {
        positionManager = address(positionManager_);
        factory = ICLFactory(positionManager_.factory());
        selectorIsPool = selectorIsPool_;
        /// @dev expect the next call to succeed without reverting. This logic is added
        // to support velodrome and aerodrome protocols using the same codebase
        assert(!isPool(address(0)));
    }

    /// ---------------------- EXTERNAL MUTATING FUNCTIONS ----------------------

    /// @inheritdoc IAmmModule
    function beforeRebalance(
        uint256 tokenId,
        bytes memory callbackParams,
        bytes memory protocolParams
    ) external virtual override {
        address gauge = abi.decode(callbackParams, (CallbackParams)).gauge;
        if (!_isStaked(gauge, tokenId)) {
            return;
        }
        collectRewards(tokenId, callbackParams, protocolParams);
        ICLGauge(gauge).withdraw(tokenId);
    }

    /// @inheritdoc IAmmModule
    function afterRebalance(uint256 tokenId, bytes memory callbackParams, bytes memory)
        external
        virtual
        override
    {
        address gauge = abi.decode(callbackParams, (CallbackParams)).gauge;
        if (!ICLGauge(gauge).voter().isAlive(gauge)) {
            return;
        }
        INonfungiblePositionManager(positionManager).approve(gauge, tokenId);
        ICLGauge(gauge).deposit(tokenId);
    }

    /// @inheritdoc IAmmModule
    function transferFrom(address from, address to, uint256 tokenId) external virtual override {
        INonfungiblePositionManager(positionManager).transferFrom(from, to, tokenId);
        if (to == address(this)) {
            // transfers unclaimed fees back to the user or to the callback address
            INonfungiblePositionManager(positionManager).collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: tokenId,
                    recipient: from,
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
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
        address token0 = ICLPool(pool).token0();
        address token1 = ICLPool(pool).token1();
        int24 tickSpacing = ICLPool(pool).tickSpacing();

        _handleToken(depositor, token0, maxAmount0);
        _handleToken(depositor, token1, maxAmount1);

        tokenIds = new uint256[](mintInfo.length);
        for (uint256 i = 0; i < mintInfo.length; i++) {
            (tokenIds[i],,,) = INonfungiblePositionManager(positionManager).mint(
                INonfungiblePositionManager.MintParams({
                    token0: token0,
                    token1: token1,
                    tickLower: mintInfo[i].tickLower,
                    tickUpper: mintInfo[i].tickUpper,
                    tickSpacing: tickSpacing,
                    amount0Desired: mintInfo[i].amount0,
                    amount1Desired: mintInfo[i].amount1,
                    amount0Min: 0,
                    amount1Min: 0,
                    recipient: address(this),
                    deadline: type(uint256).max,
                    sqrtPriceX96: 0
                })
            );
        }
    }

    /// @inheritdoc IAmmModule
    function approveTokenId(address to, uint256 tokenId) external {
        INonfungiblePositionManager(positionManager).approve(to, tokenId);
    }

    /// @inheritdoc IAmmModule
    function deposit(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1,
        address from,
        address token0,
        address token1
    ) external returns (uint256 actualAmount0, uint256 actualAmount1) {
        address this_ = address(this);
        if (amount0 != 0) {
            IERC20(token0).safeTransferFrom(from, this_, amount0);
            IERC20(token0).safeIncreaseAllowance(address(positionManager), amount0);
        }
        if (amount1 != 0) {
            IERC20(token1).safeTransferFrom(from, this_, amount1);
            IERC20(token1).safeIncreaseAllowance(address(positionManager), amount1);
        }
        (, actualAmount0, actualAmount1) = INonfungiblePositionManager(positionManager)
            .increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint256).max
            })
        );
        if (actualAmount0 != amount0) {
            IERC20(token0).safeTransfer(from, amount0 - actualAmount0);
        }
        if (actualAmount1 != amount1) {
            IERC20(token1).safeTransfer(from, amount1 - actualAmount1);
        }
    }

    /// @inheritdoc IAmmModule
    function withdraw(uint256 tokenId, uint256 liquidity, address to)
        external
        returns (uint256 actualAmount0, uint256 actualAmount1)
    {
        INonfungiblePositionManager(positionManager).decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: uint128(liquidity),
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint256).max
            })
        );
        (actualAmount0, actualAmount1) = INonfungiblePositionManager(positionManager).collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: to,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
    }

    /// ---------------------- EXTERNAL VIEW FUNCTIONS ----------------------

    /// @inheritdoc IAmmModule
    function validateCallbackParams(address pool_, bytes memory params) external view {
        if (params.length != 0x40) {
            revert InvalidLength();
        }
        IVeloAmmModule.CallbackParams memory params_ =
            abi.decode(params, (IVeloAmmModule.CallbackParams));
        if (params_.farm == address(0) || params_.gauge == address(0)) {
            revert AddressZero();
        }
        if (ICLPool(pool_).gauge() != params_.gauge) {
            revert InvalidGauge();
        }
    }

    /// @inheritdoc IAmmModule
    function tvl(uint256 tokenId)
        external
        view
        override
        returns (uint256 amount0, uint256 amount1)
    {
        return _tvl(tokenId, 0);
    }

    /// @inheritdoc IAmmModule
    function tvl(uint256 tokenId, uint160 sqrtPriceX96)
        external
        view
        override
        returns (uint256 amount0, uint256 amount1)
    {
        return _tvl(tokenId, sqrtPriceX96);
    }

    /// @inheritdoc IAmmModule
    function getPool(address token0, address token1, uint24 tickSpacing)
        external
        view
        override
        returns (address)
    {
        return factory.getPool(token0, token1, int24(tickSpacing));
    }

    /// @inheritdoc IAmmModule
    function getProperty(address pool) external view override returns (uint24) {
        return uint24(ICLPool(pool).tickSpacing());
    }

    /// @inheritdoc IAmmModule
    function getSqrtPriceX96(address pool) external view returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96,,,,,) = ICLPool(pool).slot0();
    }

    function getSqrtPriceX96AndTick(address pool)
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick)
    {
        (sqrtPriceX96,,,,,) = ICLPool(pool).slot0();
        // Reasoning for using sqrtPriceX96 to get actual tick:
        // uniswap V3: https://github.com/Uniswap/v3-core/blob/main/contracts/interfaces/pool/IUniswapV3PoolState.sol#L12
        // velodrome slipstream: https://github.com/velodrome-finance/slipstream/blob/main/contracts/core/interfaces/pool/ICLPoolState.sol#L12
        tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }

    /// @inheritdoc IAmmModule
    function getPoolTokens(address pool) external view returns (address, address) {
        return (ICLPool(pool).token0(), ICLPool(pool).token1());
    }

    /// @inheritdoc IAmmModule
    function getRewardToken(address pool) external view returns (address) {
        return ICLGauge(ICLPool(pool).gauge()).rewardToken();
    }

    /// @inheritdoc IAmmModule
    function getGauge(address pool) external view returns (address) {
        return ICLPool(pool).gauge();
    }

    /// ---------------------- EXTERNAL PURE FUNCTIONS ----------------------

    /// @inheritdoc IAmmModule
    function validateProtocolParams(bytes memory params) external pure {
        if (params.length != 0x40) {
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

    /// ---------------------- PUBLIC MUTABLE FUNCTIONS ----------------------

    /// @inheritdoc IAmmModule
    function collectRewards(
        uint256 tokenId,
        bytes memory callbackParams,
        bytes memory protocolParams
    ) public virtual override {
        CallbackParams memory callbackParams_ = abi.decode(callbackParams, (CallbackParams));
        ProtocolParams memory protocolParams_ = abi.decode(protocolParams, (ProtocolParams));
        address gauge = callbackParams_.gauge;
        uint256 balance;
        IERC20 token = IERC20(ICLGauge(gauge).rewardToken());
        if (_isStaked(gauge, tokenId)) {
            address this_ = address(this);
            balance = token.balanceOf(this_);
            ICLGauge(gauge).getReward(tokenId);
            balance = token.balanceOf(this_) - balance;
            if (balance > 0) {
                uint256 protocolReward = Math.mulDiv(protocolParams_.feeD9, balance, D9);

                if (protocolReward > 0) {
                    token.safeTransfer(protocolParams_.treasury, protocolReward);
                }

                balance -= protocolReward;
                if (balance > 0) {
                    token.safeTransfer(callbackParams_.farm, balance);
                }
            }
        }
        // we want to provide this information to the farm anyway, even if we don't have any rewards to distribute
        IVeloFarm(callbackParams_.farm).distribute(balance, address(token));
    }

    function swapOnPool(address pool, bool zeroForOne, uint256 amountIn)
        external
        returns (int256 amount0, int256 amount1)
    {
        if (amountIn == 0) {
            return (0, 0);
        }
        return ICLPool(pool).swap(
            address(this),
            zeroForOne,
            int256(amountIn),
            zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            ""
        );
    }

    function poolCallback(address pool, bytes4 selector, bytes memory callbackData) external {
        if (selector != ICLSwapCallback.uniswapV3SwapCallback.selector) {
            revert ForbiddenCallback();
        }

        if (!isPool(pool)) {
            revert ForbiddenPool();
        }

        (int256 amount0Delta, int256 amount1Delta,) =
            abi.decode(callbackData, (int256, int256, bytes));

        address token0 = ICLPool(pool).token0();
        address token1 = ICLPool(pool).token1();

        if (amount0Delta > 0) {
            SafeERC20.safeTransfer(IERC20(token0), pool, uint256(amount0Delta));
        }

        if (amount1Delta > 0) {
            SafeERC20.safeTransfer(IERC20(token1), pool, uint256(amount1Delta));
        }
    }

    /// ---------------------- PUBLIC VIEW FUNCTIONS ----------------------

    /// @inheritdoc IAmmModule
    function getAmmPosition(uint256 tokenId)
        public
        view
        override
        returns (AmmPosition memory position)
    {
        Position memory position_ = getPosition(tokenId);
        position.token0 = position_.token0;
        position.token1 = position_.token1;
        position.property = uint24(position_.tickSpacing);
        position.tickLower = position_.tickLower;
        position.tickUpper = position_.tickUpper;
        position.liquidity = position_.liquidity;
    }

    function getPosition(uint256 tokenId) public view returns (Position memory position) {
        address positionManagerAddress = positionManager;
        assembly {
            // Set up a memory pointer for the function selector and arguments
            let memPtr := mload(0x40)

            // Store the function selector of `positions(uint256)` in memory (0x99fbab88)
            mstore(memPtr, 0x99fbab8800000000000000000000000000000000000000000000000000000000)

            // Store the tokenId argument directly after the function selector
            mstore(add(memPtr, 0x04), tokenId)

            // Call the positionManager contract with staticcall to fetch the position data
            // gas() provides remaining gas, and 0x24 is the calldata size (4 bytes for selector + 32 bytes for tokenId)
            // The data is returned to the position memory location, with expected size 0x180
            let success := staticcall(gas(), positionManagerAddress, memPtr, 0x24, position, 0x180)

            // Revert if the call fails
            if iszero(success) { revert(0, 0) }

            // Store the tokenId at the end of the position memory (0x180 offset)
            mstore(add(position, 0x180), tokenId)
        }
    }

    function getInfo(uint256[] memory tokenIds) external view returns (Position[] memory data) {
        data = new Position[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            data[i] = getPosition(tokenIds[i]);
        }
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

    /// @inheritdoc IAmmModule
    function isPool(address pool) public view override returns (bool) {
        bytes memory returnData = Address.functionStaticCall(
            address(factory), abi.encodeWithSelector(selectorIsPool, pool)
        );
        return abi.decode(returnData, (bool));
    }

    /// ---------------------- INTERNAL VIEW FUNCTIONS ----------------------

    function _tvl(uint256 tokenId, uint160 sqrtPriceX96)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        Position memory position = getPosition(tokenId);

        address pool = factory.getPool(position.token0, position.token1, position.tickSpacing);
        if (sqrtPriceX96 == 0) {
            (sqrtPriceX96,,,,,) = ICLPool(pool).slot0();
        }
        (amount0, amount1) = principal(tokenId, sqrtPriceX96);
        address gauge = ICLPool(pool).gauge();
        if (!_isStaked(gauge, tokenId)) {
            (uint256 fees0, uint256 fees1) = fees(tokenId);
            amount0 += fees0;
            amount1 += fees1;
        }
    }

    /// ---------------------- INTERNAL MUTABLE FUNCTIONS ----------------------

    function _isStaked(address gauge, uint256 tokenId) internal view returns (bool) {
        return IERC721(positionManager).ownerOf(tokenId) == gauge;
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

    // =======================================================================================

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
        Position memory position = getPosition(tokenId);
        return _fees(
            FeeParams({
                token0: position.token0,
                token1: position.token1,
                tickSpacing: position.tickSpacing,
                tickLower: position.tickLower,
                tickUpper: position.tickUpper,
                liquidity: position.liquidity,
                positionFeeGrowthInside0LastX128: position.feeGrowthInside0LastX128,
                positionFeeGrowthInside1LastX128: position.feeGrowthInside1LastX128,
                tokensOwed0: position.tokensOwed0,
                tokensOwed1: position.tokensOwed1
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
            ICLPool(
                ICLFactory(INonfungiblePositionManager(positionManager).factory()).getPool(
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
    function _getFeeGrowthInside(ICLPool pool, int24 tickLower, int24 tickUpper)
        private
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        (, int24 tickCurrent,,,,) = pool.slot0();
        (,,, uint256 lowerFeeGrowthOutside0X128, uint256 lowerFeeGrowthOutside1X128,,,,,) =
            pool.ticks(tickLower);
        (,,, uint256 upperFeeGrowthOutside0X128, uint256 upperFeeGrowthOutside1X128,,,,,) =
            pool.ticks(tickUpper);

        unchecked {
            if (tickCurrent < tickLower) {
                feeGrowthInside0X128 = lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
                feeGrowthInside1X128 = lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
            } else if (tickCurrent < tickUpper) {
                uint256 feeGrowthGlobal0X128 = pool.feeGrowthGlobal0X128();
                uint256 feeGrowthGlobal1X128 = pool.feeGrowthGlobal1X128();
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
