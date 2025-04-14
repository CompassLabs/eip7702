// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BatchExecute is ReentrancyGuard {
    using ECDSA for bytes32;

    /// @notice Represents a single call within a batch.
    struct Call {
        address to;
        uint256 value;
        bytes data;
    }

    /// @notice Emitted for every individual call executed.
    event CallExecuted(address indexed sender, address indexed to, uint256 value, bytes data);
    /// @notice Emitted when a full batch is executed.
    event BatchExecuted(Call[] calls);

    /**
     * @notice Executes a batch of calls directly.
     * @dev This function is intended for use when the smart account itself (i.e. address(this))
     * calls the contract. It checks that msg.sender is the contract itself.
     * @param calls An array of Call structs containing destination, ETH value, and calldata.
     */
    function execute(Call[] calldata calls) external payable nonReentrant {
        require(msg.sender == address(this), "Invalid authority");
        
        uint256 totalValue = 0;
        for (uint256 i = 0; i < calls.length; i++) {
            totalValue += calls[i].value;
        }
        require(msg.value == totalValue, "Incorrect value sent");

        _executeBatch(calls);
    }

    /**
     * @dev Internal function that handles batch execution and nonce incrementation.
     * @param calls An array of Call structs.
     */
    function _executeBatch(Call[] calldata calls) internal {

        for (uint256 i = 0; i < calls.length; i++) {
            _executeCall(calls[i]);
        }

        emit BatchExecuted(calls);
    }

    /**
     * @dev Internal function to execute a single call.
     * @param callItem The Call struct containing destination, value, and calldata.
     */
    function _executeCall(Call calldata callItem) internal {
        (bool success,) = callItem.to.call{value: callItem.value}(callItem.data);
        require(success, "Call reverted");
        emit CallExecuted(msg.sender, callItem.to, callItem.value, callItem.data);
    }

    // Allow the contract to receive ETH (e.g. from DEX swaps or other transfers).
    fallback() external payable {}
    receive() external payable {}
}
