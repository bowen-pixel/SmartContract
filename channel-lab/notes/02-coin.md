# Coin example: mappings, permissions, and logs

Code: [Coin.sol](../src/Coin.sol). Evidence: [Coin.t.sol](../test/Coin.t.sol), [intro-demo.mjs](../script/intro-demo.mjs).

## Takeaways

A mapping is a ledger indexed by address. Minting adds new units; sending moves existing units. This ledger does not transfer ETH and does not implement ERC-20. The minter retains uncapped minting authority.

## Read the declarations

| Expression | Explanation |
| --- | --- |
| `address public immutable minter` | Records the authorized minter at deployment; public adds a read getter, immutable prevents later assignment |
| `mapping(address => uint256) public balances` | Maps each address to a balance; absent entries read as zero; getter takes an address |
| `event Sent(...)` | Declares the transfer log; indexed addresses make filtering easier |
| `event Minted(...)` | Adds an explicit mint log in this version |
| Custom `error` declarations | Define structured failure types; declarations alone do not reject calls |
| `constructor()` | Runs once at deployment |
| `minter = msg.sender` | Assigns the immediate deploying caller as minter |

`public` does not create a setter. A mapping does not automatically enumerate all holders. The front end must use logs or maintain its own index if it needs a holder list.

## Read `mint` in execution order

1. Receive `receiver` and `amount` from the caller.
2. Reject callers whose address differs from the stored minter.
3. Reject the zero address as receiver.
4. Add the amount to that receiver's balance; checked arithmetic reverts on overflow.
5. Emit `Minted` after the state change.

## Read `send` in execution order

1. Reject the zero receiver.
2. Require `amount <= balances[msg.sender]`, returning `InsufficientBalance(requested, available)` otherwise.
3. Subtract the amount from the caller's balance.
4. Add it to the receiver's balance.
5. Emit `Sent`; the event records the transfer, while the preceding assignments perform it.

`+=` adds and assigns; `-=` subtracts and assigns; `==` compares, while `=` assigns. `msg.sender` is the immediate caller, possibly another contract. Zero transfers and self-transfers are permitted; the tests show they do not create units. A failed transfer preserves both balances.

## Trace

Alice deploys and mints herself 100 units. Alice sends Bob 30: balances become 70 and 30. Bob cannot mint. Bob cannot send 50 because he holds only 30. The demo reads the emitted event from the transaction receipt.

## Differences from the documentation example

The compiler is pinned to 0.8.30; minter is immutable; calls are external; zero receivers are rejected; minting emits a log; transfer addresses are indexed. The SPDX license remains GPL-3.0 for this adaptation.

The original “only compile via IR” comment applies to using custom errors inside `require` on compiler 0.8.26. Compiler 0.8.27 added legacy-pipeline support, so this syntax works without enabling IR on our 0.8.30 baseline. IR means intermediate representation, a compiler processing stage.

Sources: [Coin example](https://docs.soliditylang.org/en/v0.8.30/introduction-to-smart-contracts.html#subcurrency-example), [0.8.27 release](https://www.soliditylang.org/blog/2024/09/04/solidity-0.8.27-release-announcement/).
