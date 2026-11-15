// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {LongLivedPaymentChannel} from "../src/LongLivedPaymentChannel.sol";

/// @dev Local-only deployment; caller selects an unlocked Anvil sender on the CLI.
contract DeployLocal is Script {
    function run() external returns (LongLivedPaymentChannel channel) {
        require(block.chainid == 31337, "local chain only");
        address recipient = vm.envAddress("LOCAL_RECIPIENT");
        vm.startBroadcast();
        channel = new LongLivedPaymentChannel{value: 1 ether}(recipient, 1 days);
        vm.stopBroadcast();
    }
}
