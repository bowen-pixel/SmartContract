// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ChannelTestBase} from "./helpers/ChannelTestBase.sol";
import {PaymentChannelBase} from "../src/PaymentChannelBase.sol";
import {SimplePaymentChannel} from "../src/SimplePaymentChannel.sol";

contract SimplePaymentChannelTest is ChannelTestBase {
    SimplePaymentChannel internal channel;

    function setUp() public override {
        super.setUp();
        vm.prank(sender);
        channel = new SimplePaymentChannel{value: 1 ether}(recipient, 1 days);
    }

    function test_InitialState() public view {
        assertEq(channel.sender(), sender);
        assertEq(channel.recipient(), recipient);
        assertEq(channel.escrow(), 1 ether);
        assertEq(channel.totalDeposited(), 1 ether);
        assertEq(uint256(channel.state()), uint256(PaymentChannelBase.State.Open));
    }

    function test_InvalidConstruction() public {
        vm.startPrank(sender);
        vm.expectRevert(PaymentChannelBase.InvalidRecipient.selector);
        new SimplePaymentChannel{value: 1}(address(0), 1);
        vm.expectRevert(PaymentChannelBase.InvalidRecipient.selector);
        new SimplePaymentChannel{value: 1}(sender, 1);
        vm.expectRevert(PaymentChannelBase.InvalidDuration.selector);
        new SimplePaymentChannel{value: 1}(recipient, 0);
        vm.expectRevert(PaymentChannelBase.InvalidAmount.selector);
        new SimplePaymentChannel(recipient, 1);
        vm.stopPrank();
    }

    function test_SettlementCreditsThenPaysBothParties() public {
        bytes memory signature = sign(channel, 0.4 ether);
        vm.prank(recipient);
        channel.settle(0.4 ether, signature);
        assertEq(channel.payouts(recipient), 0.4 ether);
        assertEq(channel.payouts(sender), 0.6 ether);
        assertEq(channel.escrow(), 0);
        uint256 senderBefore = sender.balance;
        vm.prank(sender);
        channel.withdrawPayout();
        vm.prank(recipient);
        channel.withdrawPayout();
        assertEq(recipient.balance, 0.4 ether);
        assertEq(sender.balance, senderBefore + 0.6 ether);
        assertEq(channel.totalPaidOut(), 1 ether);
        assertEq(address(channel).balance, 0);
    }

    function test_OnlyRecipientCanSettle() public {
        bytes memory signature = sign(channel, 0.4 ether);
        vm.prank(outsider);
        vm.expectRevert(PaymentChannelBase.Unauthorized.selector);
        channel.settle(0.4 ether, signature);
    }

    function test_WrongSignerAndChangedAmountRejected() public {
        bytes memory wrong = signWithKey(channel, 0.4 ether, 123);
        bytes memory valid = sign(channel, 0.4 ether);
        vm.startPrank(recipient);
        vm.expectRevert(PaymentChannelBase.InvalidSignature.selector);
        channel.settle(0.4 ether, wrong);
        vm.expectRevert(PaymentChannelBase.InvalidSignature.selector);
        channel.settle(0.5 ether, valid);
        vm.expectRevert();
        channel.settle(0.4 ether, hex"1234");
        vm.stopPrank();
    }

    function test_InsufficientEscrow() public {
        bytes memory signature = sign(channel, 2 ether);
        vm.prank(recipient);
        vm.expectRevert(PaymentChannelBase.InsufficientEscrow.selector);
        channel.settle(2 ether, signature);
    }

    function test_ContractAndChainReplayRejected() public {
        bytes memory signature = sign(channel, 0.4 ether);
        vm.prank(sender);
        SimplePaymentChannel other = new SimplePaymentChannel{value: 1 ether}(recipient, 1 days);
        vm.prank(recipient);
        vm.expectRevert(PaymentChannelBase.InvalidSignature.selector);
        other.settle(0.4 ether, signature);
        uint256 oldChain = block.chainid;
        vm.chainId(oldChain + 1);
        vm.prank(recipient);
        vm.expectRevert(PaymentChannelBase.InvalidSignature.selector);
        channel.settle(0.4 ether, signature);
        vm.chainId(oldChain);
    }

    function test_ClosedChannelAndPayoutCannotReplay() public {
        bytes memory signature = sign(channel, 0.4 ether);
        vm.startPrank(recipient);
        channel.settle(0.4 ether, signature);
        vm.expectRevert(PaymentChannelBase.InvalidState.selector);
        channel.settle(0.4 ether, signature);
        channel.withdrawPayout();
        vm.expectRevert(PaymentChannelBase.InvalidAmount.selector);
        channel.withdrawPayout();
        vm.stopPrank();
        vm.expectRevert(PaymentChannelBase.InvalidState.selector);
        channel.claimTimeout();
    }

    function test_SettlementJustBeforeExpiration() public {
        bytes memory signature = sign(channel, 0.4 ether);
        vm.warp(channel.expiration() - 1);
        vm.prank(recipient);
        channel.settle(0.4 ether, signature);
        assertEq(channel.totalClaimed(), 0.4 ether);
    }

    function test_TimeoutBoundary() public {
        uint256 expiration = channel.expiration();
        vm.warp(expiration - 1);
        vm.expectRevert(PaymentChannelBase.TooEarly.selector);
        channel.claimTimeout();
        vm.warp(expiration);
        bytes memory signature = sign(channel, 0.4 ether);
        vm.prank(recipient);
        vm.expectRevert(PaymentChannelBase.DeadlineReached.selector);
        channel.settle(0.4 ether, signature);
        vm.prank(outsider);
        channel.claimTimeout();
        assertEq(channel.payouts(sender), 1 ether);
        assertEq(channel.payouts(outsider), 0);
    }

    function test_TimeoutAfterExpiration() public {
        vm.warp(channel.expiration() + 1);
        channel.claimTimeout();
        assertEq(channel.payouts(sender), 1 ether);
    }

    function test_ZeroAuthorizedSettlement() public {
        bytes memory signature = sign(channel, 0);
        vm.prank(recipient);
        channel.settle(0, signature);
        assertEq(channel.payouts(sender), 1 ether);
    }

    function testFuzz_SettlementConservesFunds(uint96 rawAmount) public {
        uint256 amount = bound(uint256(rawAmount), 0, 1 ether);
        bytes memory signature = sign(channel, amount);
        vm.prank(recipient);
        channel.settle(amount, signature);
        assertEq(channel.payouts(sender) + channel.payouts(recipient), 1 ether);
    }
}
