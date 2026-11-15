# Security testing takeaways

Evidence: [Security.t.sol](../test/Security.t.sol), [adversarial fixtures](../test/helpers/Adversaries.sol), [stateful invariants](../test/invariant/ChannelInvariant.t.sol).

## Demonstrated attack and fix

`VulnerablePayout` is intentionally unsafe, test-only code. Its withdrawal sends ETH before clearing credit. A credited attacker can enter withdrawal again through its receive callback and spend the same credit twice. The test funds the attacker with 1 ETH credit and a victim with 2 ETH credit. The attacker receives 2 ETH, leaving only 1 ETH backing the victim's 2 ETH liability.

This is an injected teaching bug, not a vulnerability discovered in the finished channels. The protected `withdrawPayout` clears credit before sending, checks the call result, and uses `nonReentrant`. The matching test verifies that a nested withdrawal fails while the legitimate first withdrawal succeeds exactly once.

## Other adversarial boundaries

A receiving contract can reject ETH. Failed withdrawal restores its credit; a separate sender refund still succeeds because settlement itself does not transfer control. There is no alternate payout address: a recipient that permanently refuses ETH leaves its own credit inaccessible. Supporting destination changes would need additional design and authorization.

Forced ETH can increase native balance without `deposit`. The ForceEther fixture deliberately uses a deprecated instruction to test this condition under Cancun. The modern production contracts do not use that instruction. Surplus is not accounted as escrow and cannot authorize a larger claim. It remains stranded by design.

Typed-data domain separation rejects signatures across contracts and chain IDs. The signer, amount, and malformed-signature tests cover distinct failure cases. A duplicated cumulative claim cannot allocate credit twice.

## Stateful testing

The handler chooses amounts within valid bounds and signs with a test-only sender key. It performs deposits, claims, withdrawals, sender closing, settlement, and time advancement. Expected inactive actions return without making an invalid call. Unexpected handler reverts fail the campaign.

Three invariant properties check conservation/backing; cumulative payment and payout consistency; and permanent closure/nonempty activity. The setup seeds a successful deposit, claim, and withdrawal. Counters distinguish successful actions from skipped ones. A separate deterministic handler test exercises closing, finalization, and both payout owners.

The configured campaign uses 128 runs with depth 64. Finite randomized sequences do not prove every reachable state safe. The unit tests separately cover malicious receivers and invalid calls rather than asking the valid-action handler to do everything.

## Static analysis

Slither's output is a review input, not a verdict. Its timestamp and low-level call warnings correspond to deliberate protocol behavior that must be checked. The shared-base immutable suggestion misses a derived-contract top-up mutation. Read the assessment in the [security report](../docs/SECURITY_REVIEW.md).

Question to ask of every external call: what state has already changed, what callback can occur, and what happens if the receiver rejects the transfer?
