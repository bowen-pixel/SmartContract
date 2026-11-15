// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.30;

/// @notice Adapted from Solidity's introductory Coin example; not ERC-20.
/// @dev https://docs.soliditylang.org/en/v0.8.30/introduction-to-smart-contracts.html
contract Coin {
    address public immutable minter;
    mapping(address => uint256) public balances;

    event Sent(address indexed from, address indexed to, uint256 amount);
    event Minted(address indexed receiver, uint256 amount);

    error UnauthorizedMinter();
    error InvalidReceiver();
    error InsufficientBalance(uint256 requested, uint256 available);

    constructor() {
        minter = msg.sender;
    }

    function mint(address receiver, uint256 amount) external {
        if (msg.sender != minter) revert UnauthorizedMinter();
        if (receiver == address(0)) revert InvalidReceiver();
        balances[receiver] += amount;
        emit Minted(receiver, amount);
    }

    function send(address receiver, uint256 amount) external {
        if (receiver == address(0)) revert InvalidReceiver();
        require(amount <= balances[msg.sender], InsufficientBalance(amount, balances[msg.sender]));
        balances[msg.sender] -= amount;
        balances[receiver] += amount;
        emit Sent(msg.sender, receiver, amount);
    }
}
