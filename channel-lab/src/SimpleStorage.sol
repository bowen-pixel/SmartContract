// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice An intentionally unrestricted example of persistent state.
contract SimpleStorage {
    uint256 private storedData;

    /// @dev Anyone may overwrite the number; private does not mean secret.
    function set(uint256 newValue) external {
        storedData = newValue;
    }

    function get() external view returns (uint256) {
        return storedData;
    }
}
