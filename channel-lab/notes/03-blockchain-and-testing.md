# Blockchain, EVM, and test takeaways

Executable examples: [intro demo](../script/intro-demo.mjs). Design: [channel specification](../docs/SPEC.md).

## Transactions and blocks

Deploying a contract creates an instance at an address. An on-chain call that changes state is a transaction. Calls are executed against an ordered state; Alice setting 42 and Bob later setting 99 leave 99 as the current number. Earlier transactions remain in chain history. Reorganizations can change recently observed ordering, so seeing a transaction once is not identical to finality.

A revert undoes the reverting call's state changes, but does not make already spent transaction gas free. An off-chain read can execute a view function without submitting a transaction. A view call inside a transaction still consumes gas. Transactions need inclusion; contracts do not wake themselves up when a deadline passes.

## Accounts and units

Addresses identify accounts. Contracts have code and state; externally owned accounts authorize transactions with keys. A contract account can call another contract, so `msg.sender` means the immediate caller rather than necessarily the human who originally started the transaction. Authorization in this project uses the caller or an explicitly recovered signer, not `tx.origin`.

ETH is the native currency; one ETH equals 10^18 wei. Coin balances are separate integers inside `Coin`. Holding 100 Coin units does not imply holding 100 wei or ETH. Signing an off-chain payment authorization does not itself move either asset.

## Execution and data locations

| Concept | Takeaway and connection to this project |
| --- | --- |
| EVM | Executes compiled bytecode; contracts cannot fetch a web page or read a local file directly |
| Storage | Persistent state such as `escrow`, `balances`, and `payouts` |
| Memory | Temporary call-local data, such as a signature assembled in a test |
| Calldata | Read-only external input; production signature arguments use `bytes calldata` |
| Stack | Holds small execution values; it is not persistent account storage |
| Transient storage | Temporary state lasting within one transaction; these contracts do not use it |
| Returndata | ABI-encoded values returned by a call, such as `get()` |
| Code | Deployed instructions, including embedded immutable values |
| Calls | Pass control to another contract; payout callbacks are therefore adversarial boundaries |
| Delegatecall | Runs another contract's code in the caller's context; deliberately unnecessary here |
| Events/logs | Receipt data for external observers, not a replacement for state or access checks |
| Contract creation | `new` in tests deploys a fresh instance; constructors initialize it |
| Precompiles | Protocol-provided operations; ECDSA recovery relies on `ecrecover` through OpenZeppelin |
| Deactivation | Explicit Closed state disables new actions; it does not rely on deleting code |

## Testing expressions

`setUp` creates fresh test state. `assertEq` checks equality. `vm.prank` changes the caller for a test call; it does not forge a real user's transaction. `vm.deal` supplies fake test ETH. `vm.warp` moves test time. `vm.sign` signs a digest using a test-only key. `expectRevert` checks that an invalid operation fails.

Tests beginning with `testFuzz_` accept generated inputs. Invariants generate sequences of actions and check accounting properties after them. Their usefulness depends on reachable operations and meaningful assertions, not just a large trial count.

Source: [Solidity introduction and EVM overview](https://docs.soliditylang.org/en/v0.8.30/introduction-to-smart-contracts.html), [Foundry](https://www.getfoundry.sh/).
