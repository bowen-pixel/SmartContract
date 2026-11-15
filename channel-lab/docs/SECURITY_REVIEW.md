# Payment-channel security self-review

Date: 2026-11-15. This is an implementation self-review, not an independent audit or a claim of production readiness.

## Scope and reproducibility

Scope is the source, tests, scripts, and configuration in the same repository revision as this report. [SOURCE_SHA256.txt](SOURCE_SHA256.txt) identifies their exact contents independently of a moving branch name. The original `legacy/` contract is historical reference, excluded from the modern build and this modern-contract assessment.

Toolchain: Foundry v1.9.0, Solidity 0.8.30, Cancun target, optimizer 200 runs, forge-std v1.9.7 (77041d2ce690e692d6e03cc812b57d1ddaa4d505), OpenZeppelin Contracts v5.4.0 (c64a1edb67b6e3f4a15cca8909c9482ad33a02b0), ethers 6.15.0, and Slither 0.11.3. Full commands and bounded results appear in [VALIDATION.md](VALIDATION.md).

## Architecture and threat model

A deployment fixes sender and recipient. Positive funding backs cumulative EIP-712 payment authorizations. Only the recipient redeems a signature; the sender alone tops up or starts long-lived closure. Timeout finalization is permissionless but always credits the sender. Settlement updates internal liabilities and permanently closes; separate withdrawals transfer ETH.

An attacker may call public functions, replay or alter observed messages, deploy receiving contracts with callbacks or reverts, and force unsolicited ETH into the channel. The sender may stop cooperating and initiate closing; the recipient may remain offline or refuse ETH. Signature forgery against ECDSA is assumed infeasible. Compiler, pinned libraries, and the underlying chain are trusted within their documented limitations.

The recipient is responsible for checking funded escrow, contract/chain identity, cumulative amounts, and closing status, then submitting claims before the deadline. There is no promise of transaction inclusion during a short response window. The design does not make an underfunded signature payable.

## Properties examined

- Typed-data signatures bind the amount, current chain, and verifying deployment. Fixed participants and one permanent lifetime prevent reuse across reopened channel epochs.
- An increasing cumulative total allocates only its unpaid difference. Settlement permits equality to close after an already allocated claim.
- Allocated credits survive timeout and closure. Refunds consume only unallocated escrow.
- Checks/effects precede payout calls. `nonReentrant` blocks nested payouts; failed calls revert credit clearing and the paid-out counter.
- Closure is permanent. Sender closing starts once and cannot reset its deadline.
- Before-deadline claims and at/after-deadline finalization are disjoint.
- Accounted deposits equal escrow, pending credits, and successful payouts. Actual ETH may be greater because of forced surplus.

## Demonstrated issue: injected reentrancy fixture

This finding concerns `test/helpers/Adversaries.sol:VulnerablePayout` only. It is intentionally introduced teaching code, never a production dependency of the channel contracts.

**Impact:** a credited attacker reenters before its credit is cleared, receiving the same liability twice and spending another depositor's backing funds.

**Preconditions:** the vulnerable vault holds additional funds, and the credited address is a contract whose receive callback calls withdrawal again.

**Reproduction:** `forge test --match-test test_ExploitVulnerableFixtureDrainsVictimFunds -vvvv`. The fixture receives 1 ETH attacker credit plus 2 ETH victim credit. The attacker receives 2 ETH; only 1 ETH remains against the victim's 2 ETH liability.

**Root cause:** credit is cleared after handing control to an untrusted receiver, with no reentrancy guard.

**Implemented protection:** `PaymentChannelBase.withdrawPayout` clears the credit, advances the paid-out counter, and emits its event before a checked call, with OpenZeppelin `nonReentrant`. If the call fails, the entire withdrawal reverts.

**Regression evidence:** `test_SecurePayoutRejectsNestedWithdrawal` observes one attempted callback, a failed nested withdrawal, and exactly one authorized payout. This is an exploit/fix comparison, not proof that all reentrancy scenarios have been exhausted.

## Static analyzer assessment

The [normalized Slither summary](slither-summary.json) contains six results from production sources with dependencies excluded. No detector results were silently converted into an “audit passed” claim.

| Detector | Count / reported impact | Assessment |
| --- | --- | --- |
| Timestamp comparisons | 4 / Low | Intentional deadline enforcement in both channel types. Boundary tests cover before, equal, and after. Monitoring, chain timing, and inclusion remain operational assumptions. Not used for randomness. |
| Low-level call | 1 / Informational | Intentional pull payout to the caller. Credit is zeroed before control transfer, call success is checked, and a guard blocks nested withdrawal. Rejecting receivers preserve their credit without blocking the other party. |
| Possible immutable state | 1 / Optimization | Suggests `totalDeposited` could be immutable from base-contract analysis. LongLivedPaymentChannel.deposit updates it on top-ups; making it immutable would break that implementation. The cumulative-claim/top-up test exercises the mutation. |

Forge's built-in lint also reports conservative warnings about the guarded low-level call, events across inherited/reentrant paths, timestamp comparisons, and Coin balance changes. Coin actually emits Minted/Sent, and the payout event precedes the external call. The test's saved pre-mutation chain ID intentionally restores the original chain after the replay experiment. These observations do not replace the executable checks.

## Accepted limitations and unresolved extensions

1. **ECDSA sender only:** ERC-1271 smart-wallet signatures are unsupported. Do not assume a contract deployer can sign as an EOA.
2. **Online monitoring:** an unresponsive recipient may lose unclaimed authorizations after the response window; previously allocated credits remain protected.
3. **Funding:** signatures do not create backing funds. Clients must verify current unallocated escrow and already claimed totals.
4. **Forced surplus:** ETH outside explicit deposits is not allocated or recoverable. There is no rescue authority.
5. **Rejecting receivers:** a recipient contract that permanently refuses ETH cannot withdraw its own credit. No alternative payout destination exists, though the sender's separate refund remains withdrawable.
6. **No production deployment:** no public testnet verification or real-funds deployment was performed. Local Anvil addresses are disposable.
7. **Coin scope:** Coin is not ERC-20 and grants the minter uncapped issuance authority. It is separate from ETH escrow.
8. **Finite validation:** tests, fuzzing, stateful sequences, and static analysis cannot establish absence of all vulnerabilities. Coverage has instrumentation caveats documented in the validation record.

## Review conclusion

The bounded checks passed for the documented behavior. The confirmed exploit is in the deliberately vulnerable fixture; the tested channel implementation rejects that nested payout. The listed design limitations remain. Independent review and deployment-specific assessment would be necessary before handling real funds.
