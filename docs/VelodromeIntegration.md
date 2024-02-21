# mellow-alm-toolkit.

Introduction
The mellow-alm-toolkit is a liquidity management tool designed for use with Automated Market Makers (AMM). The tool allows users to deposit AMM protocol NFT positions, select and customize rebalancing strategies, and set oracle parameters for price retrieval and protection against MEV manipulations.


The system consists of the following list of main contracts:
    - Core - the main contract, through which most user interactions occur. It implements basic functions: deposit, withdraw, rebalance, as well as a number of auxiliary functions.
    - AmmModule - a module that implements interaction with a specific AMM protocol, allowing for information about pools and positions to be obtained, and implements callbacks - beforeRebalance and afterRebalance.
    - AmmOracle - an oracle that allows for checking the presence of price manipulations in a pool, as well as enabling price retrieval from a pool.
    - StrategyModule - a module that implements the logic of a strategy's operation. It allows for the validation of strategy parameters and returns the expected positions after rebalance based on current parameters.
    - LpWrapper - a wrapper contract that implements the IERC20 token interface, allowing users to deposit into a common position in exchange for lp tokens. The contract works with only one position in Core. A user with ADMIN_ROLE rigths can update strategy parameters, and a user with OPERATOR or ADMIN_ROLE rights can call emptyRebalance. To deposit into the corresponding AMM, the AmmDepositWithdrawModule is used.
    - AmmDepositWithdrawModule - a module that implements the logic of deposits and withdrawals into a specific AMM protocol.

System Architecture for Integration with Velodrome V2.
The system consists of the Core contract, modules, and auxiliary contracts. The complete list of main contracts is below:
    - Core.sol
    - VeloAmmModule.sol
    - VeloAmmDepositWithdrawModule.sol
    - VeloOracle.sol
    - PulseStrategyModule.sol
    - LpWrapper.sol
    - StakingRewards.sol - (synthetix farm contract)
    - VeloDeployFactory.sol
    - VeloDeployFactoryHelper.sol

It is implied that the entire integration will initially require the deployment of Core.sol, VeloAmmModule.sol, VeloAmmDepositWithdrawModule.sol, VeloOracle.sol, PulseStrategyModule.sol, VeloDeployFactory.sol, VeloDeployFactoryHelper.sol. Meanwhile, for each Velodrome V2 pool accordingly, only one pair of LpWrapper.sol and StakingRewards.sol will be deployed.

User interaction with the system will occur exclusively with LpWrapper.sol and StakingRewards.sol. To deposit into a position, the user must select the corresponding LpWrapper.sol, call the function deposit(amount0, amount1, minLpAmount, to), receiving a certain number of LpWrapper.sol contract lp tokens to the address `to`. Next, on behalf of address `to`, the user must set an IERC20 approve for the address StakingRewards.sol, and call in it the function stake(uint256 amount), passing in the amount of lp tokens for staking.

After that, to claim the received VELO tokens, the user needs to call the function getReward() in the StakingRewards.sol contract.

To withdraw LpWrapper.sol tokens from StakingRewards.sol, the user must call the function withdraw(uint256 amount), specifying the number of lp tokens. Next, to withdraw funds from LpWrapper.sol, the user must call in it the function withdraw(uint256 lpAmount, uint256 minAmount0, uint256 minAmount1, address to), and in case of successful transaction execution, address `to` will receive not less than minAmount0 of token0 and minAmount1 of token1.

When creating a position for a pool, all interaction occurs with the VeloDeployFactory.sol contract. To deploy a new position, it is necessary to call the function createStrategy(token0, token1, tickSpacing). If the position was previously created, an attempt will result in an LpWrapperAlreadyCreated error. Also, for successful position creation, it is required that the corresponding pool already existed, and IVeloDeployFactory.StrategyParams and ICore.DepositParams were specified for the chosen tickSpacing. In addition, when creating a new position, a certain amount of token0 and token1 may be charged from the address msg.sender for minting the new position in the selected pool. After creation, the function returns the PoolAddresses structure, with the addresses of LpWrapper.sol and StakingRewards.sol.

Detailed Description of Contract Interactions:
Core:
    The contract consists of three main functions - deposit, withdraw, rebalance, as well as several auxiliary functions.

    function deposit(ICore.DepositParams):
        The DepositParams structure contains information about the position in the following format:
            tokenIds - an array of Velodrome V2 NFT positions. All NFTs belong to one Velodrome V2 pool, and msg.sender is the owner of these NFTs.
            owner - the address of the future owner of the position in Core.sol (usually the depositor's address or the address of the LpWrapper contract)
            farm and vault - two auxiliary addresses, the interaction with which is defined in the IAmmModule contract in the beforeRebalance and afterRebalance functions. Formally, in the case of Velodrome V2, farm is the address of the gauge of the corresponding pool, and vault is the address of the synthetixFarm, through which VELO tokens will be distributed to users.
            slippageD4 - a parameter that defines what maximum part of the TVL of the position can be transferred to the rebalancer as payment for the rebalance. To work with whole numbers, a *1e4 representation is used, i.e., slippageD4 = 5 corresponds to 0.05% of the TVL of all positions defined by the array tokenIds.
            strategyParams - a byte array, which is decoded into IPulseStrategyModule.StrategyParams and defines the behavior of the strategy module.
            securityParams - a byte array, which is decoded into IVeloOracle.SecurityParams and defines the logic for protection against MEV manipulations.

        @notice before depositing, the user must set IERC721 approve for all NFTs from the tokenIds array to the Core.sol address.

        Upon deposit, all Velodrome V2 NFTs are transferred from the user's address to the Core.sol address, after which the afterRebalance callback function from the VeloAmmModule is immediately executed through delegatecall.
        After this, information about the user's position is recorded in the storage array _positions in the form of ICore.PositionInfo.
        Below is a description of the fields of ICore.PositionInfo:
            uint16 slippageD4 - the same as ICore.DepositParams.slippageD4
            uint24 property - tickSpacing of the pool, which corresponds to all positions from tokenIds;
            address owner - the same as ICore.DepositParams.owner
            address pool - the address of the Velodrome V2 pool, which corresponds to all positions from tokenIds;
            address farm - the same as ICore.DepositParams.farm;
            address vault - the same as ICore.DepositParams.vault;
            uint256[] tokenIds - the same as ICore.DepositParams.tokenIds;
            bytes securityParams - the same as ICore.DepositParams.securityParams;
            bytes strategyParams - the same as ICore.DepositParams.strategyParams;

    function withdraw(uint256 id, address to):
        id - the index of the position that will be withdrawn from Core.sol
        to - the address to which all Velodrome V2 NFTs described in tokenIds will be transferred

        @notice when calling, it must be executed _positions[id].owner == msg.sender, otherwise, an error Forbidden will be received.

        For each Velodrome V2 NFTs from tokenIds, IVeloAmmModule.beforeRebalance will be executed, followed by a transfer of NFTs to the address to.

    function rebalance(RebalanceParams):
        The RebalanceParams structure stores information for rebalancing in the following format:
        uint256[] ids; - a list of position indices to be rebalanced
        address callback; - the address of the callback contract, which will perform all operations with rebalances
        bytes data; - data for the callback contract.

        When the function is called, three main parts occur:

            1. Target positions and the minimum liquidity in each are calculated, after which all Velodrome V2 NFTs from the tokenIds array are transferred to the callback address.
            2. The callback is executed with the specified data.
            3. Positions are transferred from the callback address to the Core.sol address, after which the parameters of all received positions are checked.

            In part 1 during the rebalance process for each position from uint256[] ids, the expected post-rebalance parameters are calculated - the upper and lower ticks of the positions, as well as the liquidity ratio between the positions (here, liquidity is understood in terms of the AMM protocol). All pools are preliminarily checked for MEV manipulations. Next, the minimum liquidity in each position after the rebalance is calculated. The formula for calculation is presented below:

            1. l[i] - target liquidity in i-th position
            2. L := sum(l[i]) - total liquidity in all target positions
            3. lQ96[i] := l[i] * Q96 / L
            4. LQ96 := sum(lQ96[i]) = sum(l[i] * Q96 / L) = sum(l[i]) * Q96 / L = L * Q96 / L = Q96
            lets calculate capital in token1 in all positions (formula: capital = amount0 * price + amount1):
            6. capital[i] = amount0[i] * price + amount1[i], where:
                1. amount0[i] = l[i] * (sqrtRatioBX96 - sqrtRatioX96) / (sqrtRatioBX96 * sqrtRatioX96)
                2. amount1[i] = l[i] * (sqrtRatioX96 - sqrtRatioAX96), so:
                    capital[i] = l[i] * (sqrtRatioBX96 - sqrtRatioX96) / (sqrtRatioBX96 * sqrtRatioX96) * price + 
                        l[i] * (sqrtRatioX96 - sqrtRatioAX96)
                    capital[i] = l[i] * (
                        (sqrtRatioBX96 - sqrtRatioX96) / (sqrtRatioBX96 * sqrtRatioX96) * price +
                        (sqrtRatioX96 - sqrtRatioAX96)
                    ) = l[i] * (
                        (sqrtRatioBX96 - sqrtRatioX96) * sqrtRatioX96 / sqrtRatioBX96 +
                        (sqrtRatioX96 - sqrtRatioAX96)
                    ) = l[i] * Func(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96)
            7. in the same way: capitalQ96[i] = l[i] * Q96 / L * Func(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96)
            8. totalCapital := sum(capital[i]) = sum(l[i] * Func(sqrtRatioX96[i], sqrtRatioAX96[i], sqrtRatioBX96))
            9. totalCapitalQ96 := sum(capitalQ96[i])
                = sum(l[i] * Q96 / L * Func(sqrtRatioX96[i], sqrtRatioAX96[i], sqrtRatioBX96))
                = sum(l[i] * Func(sqrtRatioX96[i], sqrtRatioAX96[i], sqrtRatioBX96)) * Q96 / L
                = totalCapital * Q96 / L
            10. totalCapital = totalCapitalQ96 * L / Q96 => L / Q96 = totalCapital / totalCapitalQ96
            11. l[i] = lQ96[i] * L / Q96 = lQ96[i] * totalCapital / totalCapitalQ96
            12. minL[i] := l[i] * (D4 - slippageD4) / D4 - minimal allowed liquidity in the position after rebalance

        Next, for each Velodrome V2 NFT from tokenIds for the corresponding id, beforeBalance calls are made, and approval is given to the callback address.

    The contract also supports various auxiliary functions:
    To obtain information about user positions, Core.sol has three functions:

    function position(uint256 id) - returns the ICore.NftInfo structure by its id

    function positionCount() - returns the total number of positions

    function getUserIds(address user) - returns array uint256[] ids for given user, for which the user is the owner

    function setPositionParams(id, slippageD4, strategyParams, securityParams) function is used to update the position parameters. Only the owner of position id can call this function.

    function setOperatorFlag(bool flag) is necessary to set the operatorFlag. It can be called only on behalf of a user with ADMIN_ROLE rights in the Core.sol contract.

    function emptyRebalance(uint256 nftId) allows the owner of the specified position to call the beforeRebalance and afterRebalance functions for the purpose of collecting rewards or auto-compounding (the logic of these functions depends on the implementation of callbacks for each individual AMM).
    
VeloAmmModule:
    The contract implements interaction with the Velodrome V2 protocol, allowing for the retrieval of information about pools and positions, as well as implementing callbacks - beforeRebalance and afterRebalance.
    Functions:

    function beforeRebalance(address gauge, address synthetixFarm, uint256 tokenId): This function collects rewards from the gauge for the specified tokenId. The rewards are divided into two parts:
        amount * protocolFeeD9 / 1e9 - this portion of the rewards is sent to the protocolTreasury address.
        amount - amount * protocolFeeD9 / 1e9 - the remaining part of the rewards is sent to the synthetixFarm address.
        Afterwards, the tokenId is withdrawn from the gauge by calling ICLGauge(gauge).withdraw(tokenId).

    function afterRebalance(address gauge, address, uint256 tokenId): This function deposits the token into the gauge by calling ICLGauge(gauge).deposit(tokenId), after setting IERC721 approve on the gauge.

    function getPool(address token0, address token1, uint24 tickSpacing): Returns the pool address for the given parameters.

    function getPositionInfo(uint256 tokenId): Returns the IVeloAmmModule.Position structure, which contains the following parameters:
        address token0 - token0 of the corresponding pool position
        address token1 - token1 of the corresponding pool position
        uint24 property - tickSpacing of the corresponding pool position
        int24 tickLower - lower tick of the position corresponding to tokenId
        int24 tickUpper - upper tick of the position corresponding to tokenId
        uint128 liquidity - liquidity of the position corresponding to tokenId

    function getProperty(address pool): Returns uint24(tickSpacing) of the passed pool.

    function tvl(uint256 tokenId, uint160 sqrtRatioX96, address, address): Returns amount0 and amount1 - the number of tokens corresponding to the liquidity of the position at the given square root of spot price - sqrtRatioX96.

    function getAmountsForLiquidity(uint128 liquidity, uint160 sqrtPriceX96, int24 tickLower, int24 tickUpper): Returns amount0 and amount1 - the number of tokens corresponding to the specified liquidity at the given square root of spot price - sqrtRatioX96.

VeloAmmDepositWithdrawModule:
    This module implements the logic for deposits and withdrawals in the Velodrome V2 protocol.
    Functions:

    function deposit(uint256 tokenId, uint256 amount0, uint256 amount1, address from): This function increases the amount of liquidity in a Velodrome V2 NFT specified by tokenId. Tokens are transferred from the address from, with the maximum number of tokens added being equal to amount0 and amount1, respectively. The function returns the actual amount of tokens added to the Velodrome V2 position.

    function withdraw(uint256 tokenId, uint256 liquidity, address to): This function decreases the amount of liquidity by given value and transafers all tokens by calling INonfungiblePositionManager.collect to the address to.
    
VeloOracle:
    This is an oracle designed to check for price manipulation in the Velodrome V2 protocol pool and to obtain prices from the pool.
    Functions:

    function validateSecurityParams(bytes memory params): This function validates parameters to protect against MEV manipulations. The params is a bytes array that stores the structure IVeloOracle.SecurityParams, with parameters described as follows:
        uint16 lookback: The number of tick deltas of neighboring entries in the observations array, including the current spot tick.
        int24 maxAllowedDelta: The maximum permissible delta. If there is a delta larger than maxAllowedDelta, it is considered that there is price manipulation in the pool.

    function ensureNoMEV(address poolAddress, bytes memory params): If params.length == 0, the function does not check the pool for price manipulations. This function checks for MEV price manipulations in the specified Velodrome V2 protocol pool. The params are encoded SecurityParams. If, for the specified pool and securityParams, the maximum value in the delta array is greater than SecurityParams.maxAllowedDelta, the function reverts with a PriceManipulationDetected error. If the pool's observations array lacks sufficient observations, the function reverts with a NotEnoughObservations error.

    function getOraclePrice(address pool): This function returns information about the tick and sqrtPriceX96 in the pool. If there have been no swaps in the current block, it returns the spot price. Otherwise, it returns the last price stored in the observations array. In this case, if the number of observations equals 1, the function reverts with a NotEnoughObservations error.

PulseStrategyModule:
    Strategy module, that implements Pulse V1 modified strategy logic.
    Functions:

    function validateStrategyParams(bytes memory params): This function validates the strategy parameters for PulseStrategy. The params is a bytes array that stores the structure IPulseStrategyModule.StrategyParams, with parameters described as follows:
        StrategyType strategyType - defines the logic of the strategy - Original - Pulse V1 strategy, LazySyncing/LazyAscending/LazyDescending - these strategy types are described below.
        int24 tickNeighborhood - a value in ticks. This parameter is used only for StrategyType.Original.
        int24 tickSpacing - the tickSpacing of the pool that the strategy will work with.
        If tickSpacing == 0 || tickNeighborhood != 0 && strategyType != StrategyType.Original, then the function reverts with an InvalidParams error.

    function getTargets(ICore.NftsInfo memory info, IAmmModule ammModule, IOracle oracle): This function checks if a rebalance of the position is necessary, and if so, returns a description of the expected position after rebalance.
        Return values:
        bool isRebalanceRequired - a flag equal to true only if a rebalance of the position is necessary.
        ICore.TargetPositionInfo memory target - a structure with parameters described as follows:
            int24[] lowerTicks; - an array of lower ticks of all expected positions after rebalance
            int24[] upperTicks; - an array of upper ticks of all expected positions after rebalance
            uint256[] liquidityRatiosX96; - an array of liquidity ratios of the expected positions, multiplied by Q96
            uint256[] minLiquidities; - an array of the minimum amount of liquidity in the expected positions that should be present after the rebalance. This parameter is set in the ICore.rebalance function
            uint256 id - the id of the position that will be rebalanced. This parameter is set in the ICore.rebalance function
            PositionInfo info - information about the position that will be rebalanced. This parameter is set in the ICore.rebalance function
            @notice sum(ICore.TargetPositionInfoliquidityRatiosX96) == Q96.

        The function returns arrays lowerTicks, upperTicks, and liquidityRatiosX96 of length 1, the values for which are determined in the function: calculateTarget.

    function calculateTarget(int24 tick, int24 tickLower, int24 tickUpper, StrategyParams memory params): This function calculates the expected position after rebalance depending on StrategyParams.strategyType.

        If it is found that tick >= tickLower + params.tickNeighborhood && tick <= tickUpper - params.tickNeighborhood, it is considered that a new position is not needed, and the isRebalanceRequired flag returns false.

        In cases where the logic of the function subsequently requires a rebalance, the values of lowerTicks[0] and upperTicks[0] will be equal to the lower and upper ticks of the corresponding position. And the value of liquidityRatiosX96[0] will be equal to Q96 (all liquidity lies in one position).

        StrategyType.Original:
            This strategy type implements the Pulse V1 strategy. It finds the "most centered" position on the tick value with the same width, while both lowerTicks[0] and upperTicks[0] are divisible by tickSpacing without remainder. "Most centered" here means that there is no other valid position x of the same width that is closer to the x.tickLower or x.tickUpper. Formally: max(tick - lowerTicks[0], upperTicks[0] - tick) -> min AND lowerTicks[0] % tickSpacing == 0 && upperTicks[0] % tickSpacing == 0.

        StrategyType.LazySyncing:
            This strategy type implements a no-swap strategy, in which the position is moved as close as possible to the current tick value during rebalance. Formally, if for the current position [tickLower, tickUpper] it holds that tickLower > tick, then a position [lowerTicks[0], upperTicks[0]] of the same width is sought such that lowerTicks[0] - tick -> min AND lowerTicks[0] >= tick && lowerTicks[0] % tickSpacing == 0 && upperTicks[0] % tickSpacing == 0. If tick > tickUpper, then a position [lowerTicks[0], upperTicks[0]] of the same width is sought such that tick - upperTicks[0] -> min AND upperTicks[0] <= tick && lowerTicks[0] % tickSpacing == 0 && upperTicks[0] % tickSpacing == 0.

        StrategyType.LazyAscending:
            If tick < tickLower, then it is considered that a new position is not needed, and the isRebalanceRequired flag returns false. Otherwise, the function implements a no-swap strategy, in which the position is moved as close as possible to the current tick value during rebalance. Formally, if for the current position [tickLower, tickUpper] it holds that tick > tickUpper, then a position [lowerTicks[0], upperTicks[0]] of the same width is sought such that tick - upperTicks[0] -> min AND upperTicks[0] <= tick && lowerTicks[0] % tickSpacing == 0 && upperTicks[0] % tickSpacing == 0.

        StrategyType.LazyDescending:
            If tick > tickUpper, then it is considered that a new position is not needed, and the isRebalanceRequired flag returns false. Otherwise, the function implements a no-swap strategy, in which the position is moved as close as possible to the current tick value during rebalance. Formally, if for the current position [tickLower, tickUpper] it holds that tick < tickLower, then a position [lowerTicks[0], upperTicks[0]] of the same width is sought such that lowerTicks[0] - tick -> min AND lowerTicks[0] >= tick && lowerTicks[0] % tickSpacing == 0 && upperTicks[0] % tickSpacing == 0.

LpWrapper:
    A wrapper contract that implements the IERC20 token interface, allowing users to deposit into a common position, receiving LP tokens in return. The contract works with only one position in Core.sol. A user with the ADMIN_ROLE rights of this contract can update strategy parameters, and a user with OPERATOR or ADMIN_ROLE rights can call emptyRebalance.
    Functions:

    function deposit(uint256 amount0, uint256 amount1, uint256 minLpAmount, address to): This function deposits tokens into Velodrome V2 NFTs in proportion to their TVLs for the position in Core.sol corresponding to this LpWrapper. During the deposit process, delegatecall is used in VeloAmmDepositWithdrawModule. The number of LP tokens credited to address to is calculated as: lpAmount = min((positionLiquidityAfter[i] - positionLiquidityBefore[i]) * totalSupply / positionLiquidityBefore[i]). Empty positions are not considered in the calculation. If lpAmount < minLpAmount, the function reverts with an InsufficientLpAmount error.

    function withdraw(uint256 lpAmount, uint256 minAmount0, uint256 minAmount1, address to): This function burns lpAmount LP tokens from msg.sender and withdraws token0 and token1 to address to. If balanceOf(msg.sender) < lpAmount, then it is considered that lpAmount := balanceOf(msg.sender). A proportional amount of liquidity is withdrawn from each position, calculated as: liquidity = positionLiquidityBefore[i] * lpAmount / totalSupply(). Tokens from each position are transferred directly to address to.

    function setPositionParams(uint16 slippageD4, bytes memory strategyParams, bytes memory securityParams): This function sets parameters for the position in Core.sol corresponding to this LpWrapper.sol. It can only be called by a user with ADMIN_ROLE.

    function emptyRebalance(): This function calls ICore.emptyRebalance for the corresponding position for this LpWrapper.sol. It can only be called by a user with ADMIN_ROLE or OPERATOR rights.

    function initialize(uint256 id, uint256 initialTotalSupply): On subsequent calls, the function reverts with an AlreadyInitialized error. If initialTotalSupply == 0, the function reverts with an InsufficientLpAmount error. It sets tokenId equal to id, and mints an amount of liquidity equal to initialTotalSupply to the LpWrapper address.

VeloDeployFactory:
    This contract enables the creation of positions in Core.sol for given token0, token1, and tickSpacing parameters. The parameters of this position are determined by internal mappings of the contract, assuming that there can only be one position per pool.
    Functions:

    function createStrategy(address token0, address token1, int24 tickSpacing): Can only be called by a user with ADMIN_ROLE or OPERATOR rights. If no pool exists for the given (token0, token1, tickSpacing) parameters, the function reverts with a PoolNotFound error. If an LpWrapper address is already specified in the _poolToAddresses mapping for the pool, it reverts with an LpWrapperAlreadyCreated error. If StrategyParams are not set for the given tickSpacing, it reverts with an InvalidStrategyParams error. The function attempts to transfer the required amount of token0 and token1 from msg.sender, and if the balance or allowance is insufficient, it reverts. It creates a new position with the specified initialLiquidity, sets IERC721 approval for Core.sol, creates an LpWrapper and a SynthetixFarm, deposits into the chosen position, initializes the LpWrapper, and returns PoolAddresses containing information about the lpWrapper and synthetixFarm.

    function updateStrategyParams(int24 tickSpacing, StrategyParams memory params): Updates StrategyParams for the selected tickSpacing. Can only be called by a user with ADMIN_ROLE.

    function updateDepositParams(int24 tickSpacing, ICore.DepositParams memory params): Updates ICore.DepositParams for the selected tickSpacing. Can only be called by a user with ADMIN_ROLE.

    function updateMutableParams(MutableParams memory params): Updates MutableParams for the VeloDeployFactory. Can only be called by a user with ADMIN_ROLE.

    function removeAddressesForPool(address pool): Removes information about a pool from the _poolToAddresses mapping, allowing the createStrategy function to be called again for this pool. Can only be called by a user with ADMIN_ROLE.

    function poolToAddresses(address pool): Returns the PoolAddress structure for the specified pool.

    function tickSpacingToStrategyParams(int24 tickSpacing): Returns the StrategyParams structure for the specified tickSpacing.

    function tickSpacingToDepositParams(int24 tickSpacing): Returns the ICore.DepositParams structure for the specified tickSpacing.

VeloDeployFactoryHelper:
    This is a contract with auxiliary functions, that designed to reduce the size of VeloDeployFactory.sol.
    Functions:

    function createLpWrapper(ICore core, IAmmDepositWithdrawModule ammDepositWithdrawModule, string memory name, string memory symbol, address admin): This function creates an LpWrapper with the specified parameters.
        
StakingRewards:
    synthetix farm upgraded to Solidity version 0.8.0
    source version: https://github.com/Synthetixio/synthetix/blob/v2.98.2/contracts/StakingRewards.sol