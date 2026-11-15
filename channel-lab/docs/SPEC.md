# Payment-channel specification

This document describes the implemented educational design. ETH only; fixed participants; one lifetime per deployment; no proxy, reopening, ERC-20, or ERC-1271 signature support. The sender must be able to produce an ECDSA signature. Constructors require positive initial funding, a nonzero distinct recipient, and a positive duration.

## Actors and authorization

The deployer is the sender. The designated recipient alone can redeem signed cumulative authorizations. Anyone may trigger an expired timeout, but refunds are always credited to the sender. Each EIP-712 signature commits to `Payment(uint256 cumulativeAmount)` within domain `PaymentChannel`, version `1`, current chain ID, and the verifying contract address. An authorization is denominated in wei. Signing it is not a payment transaction.

## Accounting

- `escrow`: deposited ETH not yet allocated to either participant.
- `totalDeposited`: initial funding plus explicit successful top-ups.
- `totalClaimed`: all payment credits allocated to the recipient, including already withdrawn amounts; it never decreases.
- `payouts[account]`: pending, withdrawable credit.
- `totalPaidOut`: successfully transferred recipient payments and sender refunds.

A claim for cumulative total T allocates only `T - totalClaimed`. A claim requires T to increase; settlement permits equality so an already-paid recipient can close without a new payment. Both require a valid sender signature and enough unallocated escrow. Effects happen before any external payout call. Failed payout transfers revert and restore the credit.

For accounted funds:

```text
totalDeposited = escrow + pendingSender + pendingRecipient + totalPaidOut
contract ETH balance >= escrow + pendingSender + pendingRecipient
```

Forced ETH is excluded from deposited escrow and remains stranded surplus. It does not expand signed claim capacity or refund credits. No rescue operation is provided.

## State transitions

| Contract | Operation | Allowed transition / timing |
| --- | --- | --- |
| Simple | recipient `settle` | Open -> Closed, strictly before fixed expiration |
| Simple | anyone `claimTimeout` | Open -> Closed, at or after expiration |
| Long-lived | sender `deposit` | Open only; positive value |
| Long-lived | recipient `claim` | Open, or Closing strictly before deadline |
| Long-lived | sender `startSenderClose` | Open -> Closing; deadline set once |
| Long-lived | recipient `settle` | Open -> Closed, or Closing -> Closed strictly before deadline |
| Long-lived | anyone `finalizeTimeout` | Closing -> Closed, at or after deadline |
| Both | account `withdrawPayout` | Any state, if its credit is positive |

Closed channels never reopen. Settlement allocates the recipient's unpaid authorized difference, then credits all remaining escrow as sender refund. Timeout credits only remaining escrow to the sender; existing recipient credits survive.

## Worked example

Deposit 1 ETH. Claim cumulative 0.2 ETH, then withdraw it: escrow is 0.8 ETH. Top up 0.5 ETH: escrow is 1.3 ETH and total deposits 1.5 ETH. Claim cumulative 0.5 ETH: allocate another 0.3 ETH, leaving 1 ETH escrow. After timeout the sender receives a 1 ETH refund credit; the recipient still has the 0.3 ETH credit. Successful withdrawals total 1.5 ETH.

## Operational assumptions

The recipient verifies contract, chain, signature, cumulative amount, escrow, and closing status before accepting service payments, and monitors the closing window. There is no transaction-inclusion guarantee. A signed but underfunded authorization reverts; the contract cannot enforce money it does not hold. Very short time windows are unsuitable for real users. Timestamp boundaries are part of the protocol, not a randomness source.
