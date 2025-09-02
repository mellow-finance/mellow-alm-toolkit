// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Mock.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "src/interfaces/modules/IAmmModule.sol";

contract VeloAmmModuleMock is Mock {
    using SafeERC20 for IERC20;

    bool private state_;
    uint256 public immutable specificValueRevert = 1234e5;
    IAmmModule public immutable ammModule;
    address private immutable __SELF = address(this);

    constructor(IAmmModule ammModule_) {
        assert(address(ammModule_) != address(0));
        ammModule = ammModule_;
    }

    /// @dev Fallback function to handle incoming calls
    fallback() external {
        address amm = address(ammModule);
        bool isDelegate = (address(this) != __SELF);

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := 0

            switch isDelegate
            case 1 { result := delegatecall(gas(), amm, 0, calldatasize(), 0, 0) }
            default { result := call(gas(), amm, 0, 0, calldatasize(), 0, 0) }

            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function deposit(uint256, uint256 amount0, uint256, address, address, address)
        external
        returns (uint256 actualAmount0, uint256 actualAmount1)
    {
        bytes memory data = Address.functionDelegateCall(address(ammModule), msg.data);
        (actualAmount0, actualAmount1) = abi.decode(data, (uint256, uint256));
        _revert(amount0);
    }

    function withdraw(uint256, uint256 liquidity, address)
        external
        returns (uint256 actualAmount0, uint256 actualAmount1)
    {
        bytes memory data = Address.functionDelegateCall(address(ammModule), msg.data);
        (actualAmount0, actualAmount1) = abi.decode(data, (uint256, uint256));
        _revert(liquidity);
    }

    function _revert(uint256 specificValue) internal {
        if (specificValue == specificValueRevert) {
            state_ = true;
        } else {
            state_ = false;
        }
        assembly {
            let data := 42 // Set a value in memory, here we're using 42 as an example
            let resultPtr := mload(0x40) // Load the free memory pointer
            mstore(resultPtr, data) // Store the data at resultPtr

            let flagValue := sload(0)
            switch flagValue
            case 0 {
                // If flag is true, return 64 bytes
                return(resultPtr, 0x40)
            }
            default {
                // If flag is false, return 32 bytes
                return(resultPtr, 0x20)
            }
        }
    }
}
