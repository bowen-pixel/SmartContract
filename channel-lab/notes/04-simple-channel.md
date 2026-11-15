# Simple payment channel: escrow and signed settlement

Code: [SimplePaymentChannel.sol](../src/SimplePaymentChannel.sol), [shared base](../src/PaymentChannelBase.sol). Evidence: [tests](../test/SimplePaymentChannel.t.sol).

## Takeaways

The sender deposits real ETH into escrow at deployment. Off-chain signatures authorize cumulative payment amounts. The recipient can settle before a fixed expiration; otherwise a timeout refunds the sender. Settlement allocates credits and closes the channel; separate withdrawals deliver the ETH. Only escrow funding, redemption, and payouts require transactions.

## Shared base, expression by expression

| Code / symbol | Explanation |
| --- | --- |
| `is EIP712, ReentrancyGuard` | Inherits maintained hashing and reentrancy protections |
| `State` enum | Represents Open, Closing, Closed as distinct protocol states |
| `PAYMENT_TYPEHASH` | Hashes the exact signed structure `Payment(uint256 cumulativeAmount)` |
| Immutable sender / recipient | Participants cannot be replaced after deployment |
| Constructor funding | `msg.value` supplies initial escrow; positive value is required |
| `escrow` | Holds unallocated funding, excluding pending credits |
| `payouts` | Tracks amounts allocated to accounts but not yet transferred |
| `onlySender` / `onlyRecipient` | Reject the wrong immediate caller; `_` executes the function body |
| `paymentDigest` | Hashes ABI-encoded typed data and the EIP-712 domain |
| `_authorize` | Recovers the sender, rejects a decreasing total, and checks available escrow |
| `_allocate` | Credits only the unpaid difference and advances the cumulative total |
| `_close` | Permanently closes, zeroes escrow, and credits the sender's refund |
| `withdrawPayout` | Clears a credit before checked ETH transfer; failed transfers revert all effects |

The domain includes name, version, chain ID, and verifying contract address. A signature from a different deployment or chain fails. Within one channel, permanent closure or monotonic cumulative accounting prevents repeat payment. EIP-712 does not independently invalidate a reused message.

## Simple channel execution order

The constructor calls the base constructor, rejects zero duration, and sets `expiration = block.timestamp + duration`. `settle` requires the recipient and Open state, then a timestamp strictly before expiration, a valid authorization, and enough escrow. It allocates the payment and refunds the remainder as a credit.

`claimTimeout` requires Open state and a timestamp at or after expiration. Anyone can call it, but `_close` credits the sender rather than the caller. Payout withdrawal remains available after Closed. This contract does not support top-ups or repeated partial claims.

## What changed from 2018

Modern Solidity syntax, OpenZeppelin signature handling, EIP-712 domains, explicit permanent closure, and pull payouts replace the old constructor style, manual prefix/assembly handling, and `selfdestruct` closure. The legacy file remains available for comparison. Runtime EVM rules, not merely compiler flags, determine `selfdestruct` behavior.

Tests cover valid and invalid signatures, amount tampering, cross-contract/chain replay, access checks, repeat settlement, conservation, and before/at/after expiration. A zero-total signed settlement is permitted and returns all escrow to the sender.

Sources: [original design](https://programtheblockchain.com/posts/2018/02/23/writing-a-simple-payment-channel/), [EIP-712](https://eips.ethereum.org/EIPS/eip-712), [EIP-6780](https://eips.ethereum.org/EIPS/eip-6780).
