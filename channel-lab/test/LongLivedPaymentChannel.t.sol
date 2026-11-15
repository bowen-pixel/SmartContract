// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ChannelTestBase} from "./helpers/ChannelTestBase.sol";
import {PaymentChannelBase} from "../src/PaymentChannelBase.sol";
import {LongLivedPaymentChannel} from "../src/LongLivedPaymentChannel.sol";

contract LongLivedPaymentChannelTest is ChannelTestBase {
    LongLivedPaymentChannel internal channel;

    function setUp() public override {
        super.setUp();
        vm.prank(sender);
        channel = new LongLivedPaymentChannel{value: 1 ether}(recipient, 1 days);
    }

    function claim(uint256 amount) internal {
        bytes memory signature = sign(channel, amount);
        vm.prank(recipient);
        channel.claim(amount, signature);
    }

    function startClose() internal {
        vm.prank(sender);
        channel.startSenderClose();
    }

    function test_CumulativeClaimsAndTopUp() public {
        claim(0.2 ether);
        vm.prank(recipient);
        channel.withdrawPayout();
        vm.prank(sender);
        channel.deposit{value: 0.5 ether}();
        claim(0.5 ether);
        assertEq(channel.payouts(recipient), 0.3 ether);
        assertEq(channel.totalClaimed(), 0.5 ether);
        assertEq(channel.escrow(), 1 ether);
        assertEq(channel.totalDeposited(), 1.5 ether);
        vm.prank(recipient);
        channel.withdrawPayout();
        assertEq(recipient.balance, 0.5 ether);
    }

    function test_StaleAndRepeatedAuthorizationRejected() public {
        bytes memory oldSignature = sign(channel, 0.2 ether);
        bytes memory currentSignature = sign(channel, 0.5 ether);
        claim(0.5 ether);
        vm.startPrank(recipient);
        vm.expectRevert(PaymentChannelBase.StalePayment.selector);
        channel.claim(0.2 ether, oldSignature);
        vm.expectRevert(PaymentChannelBase.StalePayment.selector);
        channel.claim(0.5 ether, currentSignature);
        vm.stopPrank();
    }

    function test_CloseCannotResetDeadline() public {
        startClose();
        uint256 deadline = channel.deadline();
        vm.warp(block.timestamp + 100);
        vm.prank(sender);
        vm.expectRevert(PaymentChannelBase.InvalidState.selector);
        channel.startSenderClose();
        assertEq(channel.deadline(), deadline);
    }

    function test_AccessAndDepositChecks() public {
        vm.startPrank(outsider);
        vm.expectRevert(PaymentChannelBase.Unauthorized.selector);
        channel.startSenderClose();
        vm.expectRevert(PaymentChannelBase.Unauthorized.selector);
        channel.deposit();
        vm.stopPrank();
        vm.prank(sender);
        vm.expectRevert(PaymentChannelBase.InvalidAmount.selector);
        channel.deposit();
        bytes memory signature = sign(channel, 1);
        vm.prank(outsider);
        vm.expectRevert(PaymentChannelBase.Unauthorized.selector);
        channel.claim(1, signature);
        vm.prank(outsider);
        vm.expectRevert(PaymentChannelBase.Unauthorized.selector);
        channel.settle(1, signature);
        startClose();
        vm.prank(sender);
        vm.expectRevert(PaymentChannelBase.InvalidState.selector);
        channel.deposit{value: 1}();
    }

    function test_InvalidConstruction() public {
        vm.prank(sender);
        vm.expectRevert(PaymentChannelBase.InvalidDuration.selector);
        new LongLivedPaymentChannel{value: 1}(recipient, 0);
    }

    function test_SettleSameTotalAfterClaim() public {
        claim(0.5 ether);
        bytes memory signature = sign(channel, 0.5 ether);
        vm.prank(recipient);
        channel.settle(0.5 ether, signature);
        assertEq(channel.payouts(recipient), 0.5 ether);
        assertEq(channel.payouts(sender), 0.5 ether);
        assertEq(uint256(channel.state()), uint256(PaymentChannelBase.State.Closed));
    }

    function test_SettleAllocatesOnlyUnpaidDifference() public {
        claim(0.2 ether);
        startClose();
        vm.warp(channel.deadline() - 1);
        bytes memory signature = sign(channel, 0.6 ether);
        vm.prank(recipient);
        channel.settle(0.6 ether, signature);
        assertEq(channel.payouts(recipient), 0.6 ether);
        assertEq(channel.payouts(sender), 0.4 ether);
    }

    function test_TimeoutCannotTakeExistingCredits() public {
        claim(0.4 ether);
        startClose();
        uint256 deadline = channel.deadline();
        vm.warp(deadline - 1);
        claim(0.5 ether);
        vm.expectRevert(PaymentChannelBase.TooEarly.selector);
        channel.finalizeTimeout();
        vm.warp(deadline);
        bytes memory signature = sign(channel, 0.6 ether);
        vm.startPrank(recipient);
        vm.expectRevert(PaymentChannelBase.DeadlineReached.selector);
        channel.claim(0.6 ether, signature);
        vm.expectRevert(PaymentChannelBase.DeadlineReached.selector);
        channel.settle(0.6 ether, signature);
        vm.stopPrank();
        vm.prank(outsider);
        channel.finalizeTimeout();
        assertEq(channel.payouts(recipient), 0.5 ether);
        assertEq(channel.payouts(sender), 0.5 ether);
        vm.prank(recipient);
        channel.withdrawPayout();
        assertEq(recipient.balance, 0.5 ether);
    }

    function test_TimeoutRequiresClosingAndCanFinalizeAfterDeadline() public {
        vm.expectRevert(PaymentChannelBase.InvalidState.selector);
        channel.finalizeTimeout();
        startClose();
        vm.warp(channel.deadline() + 1);
        channel.finalizeTimeout();
        vm.expectRevert(PaymentChannelBase.InvalidState.selector);
        channel.finalizeTimeout();
    }

    function test_ClosedIsPermanent() public {
        bytes memory signature = sign(channel, 0);
        vm.prank(recipient);
        channel.settle(0, signature);
        vm.startPrank(sender);
        vm.expectRevert(PaymentChannelBase.InvalidState.selector);
        channel.deposit{value: 1}();
        vm.expectRevert(PaymentChannelBase.InvalidState.selector);
        channel.startSenderClose();
        vm.stopPrank();
        vm.startPrank(recipient);
        vm.expectRevert(PaymentChannelBase.InvalidState.selector);
        channel.claim(0, signature);
        vm.expectRevert(PaymentChannelBase.InvalidState.selector);
        channel.settle(0, signature);
        vm.stopPrank();
    }

    function testFuzz_PartialClaimAccounting(uint96 rawFirst, uint96 rawNext) public {
        uint256 first = bound(uint256(rawFirst), 1, 1 ether);
        uint256 next = bound(uint256(rawNext), first, 1 ether);
        claim(first);
        if (next > first) claim(next);
        assertEq(channel.payouts(recipient), next);
        assertEq(channel.escrow(), 1 ether - next);
    }
}
