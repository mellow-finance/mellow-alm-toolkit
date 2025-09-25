// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./Mock.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "src/interfaces/modules/IAmmModule.sol";

contract TransferFromMock is Mock {
    function transferFrom(address ammModule, address from, address to, uint256 tokenId) external {
        Address.functionDelegateCall(
            ammModule, abi.encodeWithSelector(IAmmModule.transferFrom.selector, from, to, tokenId)
        );
    }
}
