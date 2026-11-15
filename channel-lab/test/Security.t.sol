// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ChannelTestBase} from "./helpers/ChannelTestBase.sol";
import {VulnerablePayout, ReentrantReceiver, RejectingReceiver, ForceEther} from "./helpers/Adversaries.sol";
import {PaymentChannelBase} from "../src/PaymentChannelBase.sol";
import {LongLivedPaymentChannel} from "../src/LongLivedPaymentChannel.sol";

contract SecurityTest is ChannelTestBase {
    function test_ExploitVulnerableFixtureDrainsVictimFunds() public {
        vm.deal(address(this), 3 ether);
        VulnerablePayout vulnerable = new VulnerablePayout();
        ReentrantReceiver attacker = new ReentrantReceiver();
        vulnerable.depositFor{value: 1 ether}(address(attacker));
        vulnerable.depositFor{value: 2 ether}(outsider);
        attacker.attack(address(vulnerable), false);
        assertTrue(attacker.nestedSucceeded());
        assertEq(address(attacker).balance, 2 ether);
        assertEq(address(vulnerable).balance, 1 ether);
        assertEq(vulnerable.credits(outsider), 2 ether); // Victim liability is now underfunded.
    }

    function test_SecurePayoutRejectsNestedWithdrawal() public {
        ReentrantReceiver attacker = new ReentrantReceiver();
        vm.prank(sender);
        LongLivedPaymentChannel channel = new LongLivedPaymentChannel{value: 3 ether}(address(attacker), 1 days);
        bytes memory signature = sign(channel, 1 ether);
        vm.prank(address(attacker));
        channel.claim(1 ether, signature);
        attacker.attack(address(channel), true);
        assertFalse(attacker.nestedSucceeded());
        assertEq(attacker.attempts(), 1);
        assertEq(address(attacker).balance, 1 ether);
        assertEq(channel.totalPaidOut(), 1 ether);
        assertEq(channel.escrow(), 2 ether);
    }

    function test_RejectingRecipientCannotBlockRefundAndCreditSurvives() public {
        RejectingReceiver rejector = new RejectingReceiver();
        vm.prank(sender);
        LongLivedPaymentChannel channel = new LongLivedPaymentChannel{value: 1 ether}(address(rejector), 1 days);
        bytes memory signature = sign(channel, 0.4 ether);
        vm.prank(address(rejector));
        channel.settle(0.4 ether, signature);
        vm.expectRevert(PaymentChannelBase.TransferFailed.selector);
        rejector.withdraw(channel);
        assertEq(channel.payouts(address(rejector)), 0.4 ether);
        assertEq(channel.totalPaidOut(), 0);
        vm.prank(sender);
        channel.withdrawPayout();
        assertEq(channel.totalPaidOut(), 0.6 ether);
        assertEq(address(channel).balance, 0.4 ether);
    }

    function test_ForcedEtherIsSurplusNotNewEscrow() public {
        vm.deal(address(this), 1 ether);
        vm.prank(sender);
        LongLivedPaymentChannel channel = new LongLivedPaymentChannel{value: 1 ether}(recipient, 1 days);
        ForceEther force = new ForceEther{value: 1 ether}();
        force.force(payable(address(channel)));
        assertEq(address(channel).balance, 2 ether);
        assertEq(channel.escrow(), 1 ether);
        bytes memory tooLarge = sign(channel, 1.5 ether);
        vm.prank(recipient);
        vm.expectRevert(PaymentChannelBase.InsufficientEscrow.selector);
        channel.claim(1.5 ether, tooLarge);
        bytes memory signature = sign(channel, 0.5 ether);
        vm.prank(recipient);
        channel.settle(0.5 ether, signature);
        assertEq(channel.payouts(sender) + channel.payouts(recipient), 1 ether);
        assertEq(address(channel).balance - channel.payouts(sender) - channel.payouts(recipient), 1 ether);
    }
}
