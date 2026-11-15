// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PaymentChannelBase} from "./PaymentChannelBase.sol";

/// @notice Fixed-expiration channel with one signed settlement or timeout.
contract SimplePaymentChannel is PaymentChannelBase {
    uint256 public immutable expiration;

    constructor(address recipient_, uint256 duration) payable PaymentChannelBase(recipient_) {
        if (duration == 0) revert InvalidDuration();
        expiration = block.timestamp + duration;
    }

    function settle(uint256 cumulativeAmount, bytes calldata signature) external onlyRecipient onlyOpen {
        if (block.timestamp >= expiration) revert DeadlineReached();
        _authorize(cumulativeAmount, signature);
        _allocate(cumulativeAmount);
        _close();
    }

    /// @notice Anyone may trigger the timeout, but only the sender gets the refund.
    function claimTimeout() external onlyOpen {
        if (block.timestamp < expiration) revert TooEarly();
        _close();
    }
}
