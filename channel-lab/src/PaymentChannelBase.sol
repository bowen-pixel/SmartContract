// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice Shared authorization and pull-payment accounting for one channel lifetime.
/// @dev ETH only. Sender signing is ECDSA/EOA only, without ERC-1271 support.
abstract contract PaymentChannelBase is EIP712, ReentrancyGuard {
    enum State {
        Open,
        Closing,
        Closed
    }

    bytes32 public constant PAYMENT_TYPEHASH = keccak256("Payment(uint256 cumulativeAmount)");
    address public immutable sender;
    address public immutable recipient;
    State public state;
    uint256 public escrow;
    uint256 public totalDeposited;
    uint256 public totalClaimed;
    uint256 public totalPaidOut;
    mapping(address => uint256) public payouts;

    event Deposited(uint256 amount);
    event PaymentClaimed(uint256 cumulativeAmount, uint256 newlyCredited);
    event ChannelClosed(uint256 senderRefund);
    event PayoutWithdrawn(address indexed account, uint256 amount);

    error Unauthorized();
    error InvalidRecipient();
    error InvalidAmount();
    error InvalidDuration();
    error InvalidState();
    error InvalidSignature();
    error StalePayment();
    error InsufficientEscrow();
    error DeadlineReached();
    error TooEarly();
    error TransferFailed();

    constructor(address recipient_) payable EIP712("PaymentChannel", "1") {
        if (recipient_ == address(0) || recipient_ == msg.sender) revert InvalidRecipient();
        if (msg.value == 0) revert InvalidAmount();
        sender = msg.sender;
        recipient = recipient_;
        escrow = msg.value;
        totalDeposited = msg.value;
        emit Deposited(msg.value);
    }

    modifier onlySender() {
        if (msg.sender != sender) revert Unauthorized();
        _;
    }

    modifier onlyRecipient() {
        if (msg.sender != recipient) revert Unauthorized();
        _;
    }

    modifier onlyOpen() {
        if (state != State.Open) revert InvalidState();
        _;
    }

    /// @notice Domain includes chain ID and this deployment's address.
    function paymentDigest(uint256 cumulativeAmount) public view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(PAYMENT_TYPEHASH, cumulativeAmount)));
    }

    /// @notice Credits stay withdrawable even after the channel closes.
    function withdrawPayout() external nonReentrant {
        uint256 amount = payouts[msg.sender];
        if (amount == 0) revert InvalidAmount();
        // Effects happen before transferring control to the recipient.
        payouts[msg.sender] = 0;
        totalPaidOut += amount;
        emit PayoutWithdrawn(msg.sender, amount);
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    function _authorize(uint256 cumulativeAmount, bytes calldata signature) internal view {
        if (ECDSA.recover(paymentDigest(cumulativeAmount), signature) != sender) revert InvalidSignature();
        if (cumulativeAmount < totalClaimed) revert StalePayment();
        if (cumulativeAmount - totalClaimed > escrow) revert InsufficientEscrow();
    }

    function _allocate(uint256 cumulativeAmount) internal {
        uint256 difference = cumulativeAmount - totalClaimed;
        totalClaimed = cumulativeAmount;
        escrow -= difference;
        payouts[recipient] += difference;
        emit PaymentClaimed(cumulativeAmount, difference);
    }

    function _close() internal {
        state = State.Closed;
        uint256 refund = escrow;
        escrow = 0;
        payouts[sender] += refund;
        emit ChannelClosed(refund);
    }
}
