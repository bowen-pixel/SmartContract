// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {PaymentChannelBase} from "../../src/PaymentChannelBase.sol";

abstract contract ChannelTestBase is Test {
    uint256 internal constant SENDER_KEY = 0xA11CE;
    address internal sender;
    address internal recipient = makeAddr("recipient");
    address internal outsider = makeAddr("outsider");

    function setUp() public virtual {
        sender = vm.addr(SENDER_KEY);
        vm.deal(sender, 100 ether);
    }

    function sign(PaymentChannelBase channel, uint256 total) internal view returns (bytes memory) {
        return signWithKey(channel, total, SENDER_KEY);
    }

    function signWithKey(PaymentChannelBase channel, uint256 total, uint256 key) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, channel.paymentDigest(total));
        return abi.encodePacked(r, s, v);
    }
}
