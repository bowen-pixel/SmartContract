# Long-lived channel: cumulative claims and closing windows

Code: [LongLivedPaymentChannel.sol](../src/LongLivedPaymentChannel.sol). Evidence: [tests](../test/LongLivedPaymentChannel.t.sol).

## Takeaways

The channel can receive top-ups and honor multiple authorizations. A cumulative amount expresses the total authorized over the channel's lifetime, not the next payment. The sender can start closing once, giving the recipient a response window before timeout.

## Function-by-function reading

| Function | Execution and reason |
| --- | --- |
| Constructor | Initializes base escrow/participants and immutable positive `closeDuration` |
| `deposit` | Checks sender and Open state, rejects zero, adds `msg.value` to escrow and cumulative deposits |
| `claim` | Checks active state, validates signature and solvency, requires an increasing total, allocates the difference |
| `startSenderClose` | Checks sender and Open state, switches to Closing, sets deadline, emits event |
| `settle` | Checks active state and authorization, allocates any remaining signed difference, credits sender refund, closes |
| `finalizeTimeout` | Requires Closing and timestamp at/after deadline, then closes with a refund of unallocated escrow |
| `_requireActive` | Rejects Closed and rejects Closing at/after the deadline |

The inherited `withdrawPayout` is independent of channel state. Allocated credit is already owed even if its owner has not withdrawn it. Finalization cannot turn that credit back into a sender refund.

## Worked example

| Action | Unallocated escrow | Recipient credit | Recipient already paid |
| --- | ---: | ---: | ---: |
| Deposit 1 ETH | 1.0 | 0 | 0 |
| Claim total 0.2 | 0.8 | 0.2 | 0 |
| Withdraw payout | 0.8 | 0 | 0.2 |
| Top up 0.5 | 1.3 | 0 | 0.2 |
| Claim total 0.5 | 1.0 | 0.3 | 0.2 |
| Timeout closes | 0 | 0.3 | 0.2 |

Timeout credits 1 ETH to the sender. Recipient credit remains 0.3 ETH, so the recipient ultimately receives 0.5 ETH in total. A duplicate 0.5 claim fails; a 0.2 claim after 0.5 also fails. Settlement with a total exactly equal to already claimed is allowed because no further payment is necessary to close.

## Deadline and monitoring

The sender cannot reset the deadline by calling `startSenderClose` again: Closing is no longer Open. Claims and recipient settlement require time strictly before the deadline; finalization requires time at or after it. Tests exercise both sides and exact equality.

The recipient must inspect funding and monitor the closing event. This version offers no watchtower and no guaranteed transaction inclusion. It rejects new deposits while Closing, making the response period and final refund easier to reason about. No old signature may be used to reopen a Closed deployment.

Source: [Steve Marx's long-lived payment-channel design](https://programtheblockchain.com/posts/2018/03/02/building-long-lived-payment-channels/). Payout-credit accounting and exact state/deadline rules are explicit choices in this implementation.
