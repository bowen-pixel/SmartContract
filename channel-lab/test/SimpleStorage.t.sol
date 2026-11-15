// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {SimpleStorage} from "../src/SimpleStorage.sol";

contract SimpleStorageTest is Test {
    SimpleStorage internal store;

    function setUp() public {
        store = new SimpleStorage();
    }

    function test_InitialValueIsZero() public view {
        assertEq(store.get(), 0);
    }

    function test_SetUpdatesValue() public {
        store.set(42);
        assertEq(store.get(), 42);
    }

    function test_LatestCallerOverwritesValue() public {
        store.set(7);
        vm.prank(makeAddr("bob"));
        store.set(9);
        assertEq(store.get(), 9);
    }

    function testFuzz_SetRoundTrip(uint256 value) public {
        store.set(value);
        assertEq(store.get(), value);
    }
}
