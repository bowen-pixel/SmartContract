# Review and portfolio takeaways

Read the [self-review](../docs/SECURITY_REVIEW.md), [validation record](../docs/VALIDATION.md), and [specification](../docs/SPEC.md) together.

## What this project demonstrates

Storage and Coin illustrate state, visibility, access checks, mappings, events, and custom errors. The channels add funded liabilities, typed signatures, cumulative accounting, permanent closure, and callback-resistant payouts. Tests include invalid inputs, exact deadline boundaries, adversarial receivers, fuzzed amounts, and stateful sequences. Demos demonstrate the off-chain/on-chain interface.

The progression from a fixed expiration to a sender-initiated closing window is an architectural change, not just adding a deposit method. Already allocated credit must survive closure, and a repeated close request must not reset the recipient's response period.

## Reading the evidence honestly

The attack fixture is a deliberate vulnerability used to demonstrate exploit mechanics. A static analyzer result is not automatically a confirmed exploit. Coverage measures exercised code and has instrumentation limitations. Passing randomized tests does not prove an invariant mathematically. A self-review is not an independent audit.

## Assumptions worth discussing in an interview

Recipients must monitor deadlines and verify funding before accepting authorizations. Sender signatures are ECDSA only, not ERC-1271 smart-wallet signatures. There is no rescue mechanism for forced surplus and no alternate destination for a recipient that rejects ETH. The Coin minter can create unlimited units, and Coin is not ERC-20. The contracts are educational and have not been deployed with real funds.

## Explain the work accurately

A useful project description is: “Implemented typed-signature ETH payment channels with cumulative claims, pull payouts, replay and deadline tests, a local signing demo, stateful accounting checks, and a documented self-review.” Attribute the introductory examples and payment-channel design sources. This implementation was completed with AI assistance; review and run it yourself before presenting the reasoning as your own understanding.

If you get stuck, name the file and function, explain your predicted state change, then compare it with the test. The notes replace assignment instructions; they do not establish that you have personally mastered every concept yet.
