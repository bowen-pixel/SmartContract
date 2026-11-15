// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PaymentChannelBase} from "./PaymentChannelBase.sol";

/// @notice Cumulative claims, top-ups, and a single sender-initiated closing window.
contract LongLivedPaymentChannel is PaymentChannelBase {
    uint256 public immutable closeDuration;
    uint256 public deadline;

    event SenderCloseStarted(uint256 deadline);

    constructor(address recipient_, uint256 closeDuration_) payable PaymentChannelBase(recipient_) {
        if (closeDuration_ == 0) revert InvalidDuration();
        closeDuration = closeDuration_;
    }

    function deposit() external payable onlySender onlyOpen {
        if (msg.value == 0) revert InvalidAmount();
        escrow += msg.value;
        totalDeposited += msg.value;
        emit Deposited(msg.value);
    }

    function claim(uint256 cumulativeAmount, bytes calldata signature) external onlyRecipient {
        _requireActive();
        _authorize(cumulativeAmount, signature);
        if (cumulativeAmount == totalClaimed) revert StalePayment();
        _allocate(cumulativeAmount);
    }

    function startSenderClose() external onlySender onlyOpen {
        state = State.Closing;
        deadline = block.timestamp + closeDuration;
        emit SenderCloseStarted(deadline);
    }

    function settle(uint256 cumulativeAmount, bytes calldata signature) external onlyRecipient {
        _requireActive();
        _authorize(cumulativeAmount, signature);
        _allocate(cumulativeAmount);
        _close();
    }

    function finalizeTimeout() external {
        if (state != State.Closing) revert InvalidState();
        if (block.timestamp < deadline) revert TooEarly();
        _close();
    }

    function _requireActive() internal view {
        if (state == State.Closed) revert InvalidState();
        if (state == State.Closing && block.timestamp >= deadline) revert DeadlineReached();
    }
}
