// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PaymentChannelBase} from "../../src/PaymentChannelBase.sol";

/// @dev TEST FIXTURE ONLY: vulnerable payout ordering and no reentrancy guard.
contract VulnerablePayout {
    mapping(address => uint256) public credits;

    function depositFor(address account) external payable {
        credits[account] += msg.value;
    }

    function withdraw() external {
        uint256 amount = credits[msg.sender];
        require(amount > 0);
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok);
        credits[msg.sender] = 0; // BUG: written after the external call.
    }
}

interface IWithdraw {
    function withdraw() external;
}

contract ReentrantReceiver {
    address public target;
    bool public secure;
    uint256 public attempts;
    bool public nestedSucceeded;

    function attack(address target_, bool secure_) external {
        target = target_;
        secure = secure_;
        if (secure_) PaymentChannelBase(target).withdrawPayout();
        else IWithdraw(target).withdraw();
    }

    receive() external payable {
        if (attempts == 0) {
            attempts++;
            bytes memory callData = secure
                ? abi.encodeWithSelector(PaymentChannelBase.withdrawPayout.selector)
                : abi.encodeWithSelector(IWithdraw.withdraw.selector);
            (nestedSucceeded,) = target.call(callData);
        }
    }
}

contract RejectingReceiver {
    function withdraw(PaymentChannelBase channel) external {
        channel.withdrawPayout();
    }

    receive() external payable {
        revert("reject ETH");
    }
}

contract ForceEther {
    constructor() payable {}

    function force(address payable target) external {
        // Intentional test use: demonstrate unsolicited ETH under modern EVM rules.
        selfdestruct(target);
    }
}
