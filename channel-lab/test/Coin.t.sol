// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";
import {Coin} from "../src/Coin.sol";

contract CoinTest is Test {
    Coin internal coin;
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        coin = new Coin();
    }

    function test_ConstructorAndDefaultBalance() public view {
        assertEq(coin.minter(), address(this));
        assertEq(coin.balances(alice), 0);
    }

    function test_MintAndSendEmitEvents() public {
        vm.expectEmit(true, false, false, true);
        emit Coin.Minted(alice, 100);
        coin.mint(alice, 100);
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Coin.Sent(alice, bob, 30);
        coin.send(bob, 30);
        assertEq(coin.balances(alice), 70);
        assertEq(coin.balances(bob), 30);
    }

    function test_OnlyMinterCanMint() public {
        vm.prank(alice);
        vm.expectRevert(Coin.UnauthorizedMinter.selector);
        coin.mint(alice, 100);
    }

    function test_InsufficientFundsLeavesBalancesUnchanged() public {
        coin.mint(alice, 20);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Coin.InsufficientBalance.selector, 50, 20));
        coin.send(bob, 50);
        assertEq(coin.balances(alice), 20);
        assertEq(coin.balances(bob), 0);
    }

    function test_ZeroAddressRejected() public {
        vm.expectRevert(Coin.InvalidReceiver.selector);
        coin.mint(address(0), 1);
        vm.expectRevert(Coin.InvalidReceiver.selector);
        coin.send(address(0), 0);
    }

    function test_CheckedOverflow() public {
        coin.mint(alice, type(uint256).max);
        vm.expectRevert(stdError.arithmeticError);
        coin.mint(alice, 1);
    }

    function testFuzz_TransferPreservesBalances(uint128 initial, uint128 rawAmount) public {
        uint256 amount = bound(uint256(rawAmount), 0, initial);
        coin.mint(alice, initial);
        vm.prank(alice);
        coin.send(bob, amount);
        assertEq(coin.balances(alice) + coin.balances(bob), initial);
    }

    function test_SelfTransferAndZeroTransfer() public {
        coin.mint(alice, 100);
        vm.startPrank(alice);
        coin.send(alice, 30);
        coin.send(bob, 0);
        vm.stopPrank();
        assertEq(coin.balances(alice), 100);
        assertEq(coin.balances(bob), 0);
    }
}
