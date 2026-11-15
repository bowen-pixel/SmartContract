// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {PaymentChannelBase} from "../../src/PaymentChannelBase.sol";
import {LongLivedPaymentChannel} from "../../src/LongLivedPaymentChannel.sol";

contract ChannelHandler is Test {
    LongLivedPaymentChannel public immutable channel;
    address public immutable sender;
    address public immutable recipient;
    uint256 internal constant KEY = 0xA11CE;
    uint256 public ghostDeposited;
    uint256 public ghostClaimed;
    uint256 public recipientPaid;
    uint256 public senderPaid;
    uint256 public successfulDeposits;
    uint256 public successfulClaims;
    uint256 public successfulWithdrawals;
    bool public sawClosed;

    constructor(LongLivedPaymentChannel channel_) {
        channel = channel_;
        sender = channel_.sender();
        recipient = channel_.recipient();
        ghostDeposited = channel_.totalDeposited();
    }

    function deposit(uint96 rawAmount) external {
        if (channel.state() != PaymentChannelBase.State.Open) return;
        uint256 amount = bound(uint256(rawAmount), 1, 10 ether);
        vm.deal(sender, amount);
        vm.prank(sender);
        channel.deposit{value: amount}();
        ghostDeposited += amount;
        successfulDeposits++;
    }

    function claim(uint96 rawAmount) external {
        if (!_active() || channel.escrow() == 0) return;
        uint256 delta = bound(uint256(rawAmount), 1, channel.escrow());
        uint256 total = ghostClaimed + delta;
        bytes memory signature = _sign(total);
        vm.prank(recipient);
        channel.claim(total, signature);
        ghostClaimed = total;
        successfulClaims++;
    }

    function withdraw(bool recipientSide) external {
        address account = recipientSide ? recipient : sender;
        uint256 amount = channel.payouts(account);
        if (amount == 0) return;
        vm.prank(account);
        channel.withdrawPayout();
        if (recipientSide) recipientPaid += amount;
        else senderPaid += amount;
        successfulWithdrawals++;
    }

    function startClose() external {
        if (channel.state() != PaymentChannelBase.State.Open) return;
        vm.prank(sender);
        channel.startSenderClose();
    }

    function settle(uint96 rawAmount) external {
        if (!_active()) return;
        uint256 delta = bound(uint256(rawAmount), 0, channel.escrow());
        uint256 total = ghostClaimed + delta;
        bytes memory signature = _sign(total);
        vm.prank(recipient);
        channel.settle(total, signature);
        ghostClaimed = total;
        sawClosed = true;
    }

    function tick(uint32 rawSeconds) external {
        vm.warp(vm.getBlockTimestamp() + bound(uint256(rawSeconds), 0, 2 days));
        if (channel.state() == PaymentChannelBase.State.Closing && block.timestamp >= channel.deadline()) {
            channel.finalizeTimeout();
            sawClosed = true;
        }
    }

    function _active() internal view returns (bool) {
        return channel.state() == PaymentChannelBase.State.Open
            || (channel.state() == PaymentChannelBase.State.Closing && block.timestamp < channel.deadline());
    }

    function _sign(uint256 total) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(KEY, channel.paymentDigest(total));
        return abi.encodePacked(r, s, v);
    }
}

contract ChannelInvariantTest is StdInvariant, Test {
    LongLivedPaymentChannel internal channel;
    ChannelHandler internal handler;
    address internal sender;
    address internal recipient = makeAddr("recipient");

    function setUp() public {
        sender = vm.addr(0xA11CE);
        vm.deal(sender, 10 ether);
        vm.prank(sender);
        channel = new LongLivedPaymentChannel{value: 10 ether}(recipient, 1 days);
        handler = new ChannelHandler(channel);
        // Seed successful actions so campaigns cannot be entirely empty/reverting.
        handler.deposit(1 ether);
        handler.claim(0.2 ether);
        handler.withdraw(true);
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = ChannelHandler.deposit.selector;
        selectors[1] = ChannelHandler.claim.selector;
        selectors[2] = ChannelHandler.withdraw.selector;
        selectors[3] = ChannelHandler.startClose.selector;
        selectors[4] = ChannelHandler.settle.selector;
        selectors[5] = ChannelHandler.tick.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_FundsAreConserved() public view {
        assertEq(
            handler.ghostDeposited(),
            channel.escrow() + channel.payouts(sender) + channel.payouts(recipient) + channel.totalPaidOut()
        );
        assertGe(address(channel).balance, channel.escrow() + channel.payouts(sender) + channel.payouts(recipient));
        assertEq(channel.totalDeposited(), handler.ghostDeposited());
    }

    function invariant_NoDoublePayment() public view {
        assertEq(channel.totalClaimed(), handler.ghostClaimed());
        assertEq(channel.totalClaimed(), handler.recipientPaid() + channel.payouts(recipient));
        assertEq(channel.totalPaidOut(), handler.recipientPaid() + handler.senderPaid());
        assertLe(channel.totalPaidOut(), channel.totalDeposited());
    }

    function invariant_ClosureIsPermanentAndCampaignIsNonempty() public view {
        if (handler.sawClosed()) assertEq(uint256(channel.state()), uint256(PaymentChannelBase.State.Closed));
        assertGt(handler.successfulDeposits(), 0);
        assertGt(handler.successfulClaims(), 0);
        assertGt(handler.successfulWithdrawals(), 0);
    }

    function test_HandlerExercisesClosingAndBothWithdrawals() public {
        handler.startClose();
        handler.claim(0.3 ether);
        handler.tick(uint32(2 days));
        handler.withdraw(false);
        handler.withdraw(true);
        assertTrue(handler.sawClosed());
        assertEq(channel.totalPaidOut(), channel.totalDeposited());
    }
}
