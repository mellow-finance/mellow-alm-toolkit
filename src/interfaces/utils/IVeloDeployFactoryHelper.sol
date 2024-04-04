// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "./ILpWrapper.sol";

interface IVeloDeployFactoryHelper {
    /**
     * @dev Creates a new LP wrapper contract.
     * @param core The address of the core contract.
     * @param ammDepositWithdrawModule The address of the AMM deposit/withdraw module contract.
     * @param name The name of the LP wrapper contract.
     * @param symbol The symbol of the LP wrapper contract.
     * @param admin The address of the admin for the LP wrapper contract.
     * @param manager The address of the manager contract for auto update of parameters.
     * @param operator The address of the operator for the LP wrapper contract.
     * @return The newly created LP wrapper contract.
     */
    function createLpWrapper(
        ICore core,
        IAmmDepositWithdrawModule ammDepositWithdrawModule,
        string memory name,
        string memory symbol,
        address admin,
        address manager,
        address operator
    ) external returns (ILpWrapper);

    /**
     * @dev Creates a new StakingReward contract.
     * @param owner The address of the owner for the StakingReward contract.
     * @param operator The address of the operator for the StakingReward contract.
     * @param reward The address of the reward token for the StakingReward contract.
     * @param token The address of the token for the StakingReward contract.
     * @return The address of the newly created StakingReward contract.
     */
    function createStakingRewards(
        address owner,
        address operator,
        address reward,
        address token
    ) external returns (address);
}
