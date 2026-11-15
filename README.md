# SmartContract

A hands-on learning project: build an ETH payment channel, then test it like an attacker. The goal is to produce work you can explain in a smart contract engineering or security interview.

**Start at Lesson 0. Complete one numbered step at a time. You do not need to understand the whole roadmap today.**

## Current status

- `SmartContract.sol` is a historical Solidity 0.4.x implementation based on Steve Marx's simple payment-channel tutorial. It is a reference for reading, not the modern project or a production contract.
- This README is the manual build plan. The `channel-lab/` files described below are files you will create as you work.
- The historical contract's earlier compilation and tests do not verify a modern implementation. Each new lesson needs its own checks.
- Start locally with fake ETH. Testnet deployment is an optional final milestone.

## How to use this guide

1. Read the current lesson's goal.
2. Type each command separately. Commands belong in your terminal; Solidity belongs in the named `.sol` file.
3. Make one small code change and run the relevant test.
4. Explain what happened in your own words before continuing.
5. Commit a completed checkpoint. Ask for help whenever an instruction or result is unclear.

When stuck, paste this into our chat:

```text
I'm at Lesson __, step __.
File/function: __
Command I ran: __
I expected: __
Actual output (including the first error): __
My current explanation: __
Please give me one hint first, then explain the relevant lines.
```

Share the smallest relevant code snippet. Never paste a private key, seed phrase, or secret RPC URL. For line-by-line questions, include the file name and function because line numbers change.

## Learning map

| Lesson | What you will build | Checkpoint |
| --- | --- | --- |
| 0 | Local development environment | Forge works and the template tests pass |
| 1 | SimpleStorage | Explain every line and change state |
| 2 | Your first Solidity tests | Make a test fail, then fix it |
| 3 | A written payment-channel specification | Explain the actors, money, and closing rules |
| 4 | A modern simple payment channel | Signed settlement and timeout tests pass |
| 5 | A long-lived payment channel | Deposits, partial claims, and delayed closure work |
| 6 | Attack tests and fuzzing | Demonstrate failures against intentionally broken code |
| 7 | A reproducible demo and CI | Another person can clone and run the project |
| 8 | A portfolio security report | Explain the design, limitations, and findings |

## Lesson 0 — Set up your workspace

**Goal:** get a working toolchain before writing your own contract. These commands assume macOS or Linux. Windows users should use WSL or Git Bash and the official installation instructions.

1. Install Git and a code editor if needed. Check Git:

```bash
git --version
```

2. Follow the [official Foundry installation guide](https://www.getfoundry.sh/introduction/installation). Its standard installation commands are:

```bash
curl -L https://foundry.paradigm.xyz | bash
```

Open a new terminal, then run:

```bash
foundryup
forge --version
cast --version
anvil --version
```

`forge` builds and tests contracts. `cast` interacts with Ethereum. `anvil` runs a local blockchain. Record the version output in your notes.

3. Choose a parent directory for your coding projects. If you have not cloned this repository, run:

```bash
git clone --recurse-submodules https://github.com/bowen-pixel/SmartContract.git
cd SmartContract
```

If you already have a local clone, open that clone instead. Check `git status` and preserve any existing work before continuing.

4. From the repository root, create a separate modern workspace. Run this initialization once:

```bash
forge init channel-lab --no-git
cd channel-lab
forge build
forge test
```

`--no-git` keeps this workspace inside the existing repository rather than creating another Git repository. The generated Counter example is just a toolchain check. If the command fails, stop here and ask about that error.

5. In your editor, remove only the generated example files `src/Counter.sol`, `test/Counter.t.sol`, and `script/Counter.s.sol` if present. Keep `lib/forge-std/` and the project configuration.
6. Replace `channel-lab/foundry.toml` with:

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc_version = "0.8.30"
evm_version = "cancun"
optimizer = true
optimizer_runs = 200

[profile.default.fuzz]
runs = 256

[profile.default.invariant]
runs = 128
depth = 64
fail_on_revert = false
```

We pin a released compiler for consistent lessons; 0.8.30 is a deliberate baseline, not a claim that it is the newest release. `cancun` selects modern EVM semantics. Do not copy the old `^0.4.20` pragma into new files.

7. Create `channel-lab/notes/progress.md`. Record your OS, tool versions, and current lesson. Make sure `out/`, `cache/`, and `.env` files are ignored by Git before committing.

**Done when:** the template tests passed before removal, you can locate `foundry.toml`, and you understand which directory contains the modern code. Run all following `forge` commands from `channel-lab/`.

## Lesson 1 — Understand a contract line by line

**Read:** the [Solidity storage example](https://docs.soliditylang.org/en/v0.8.30/introduction-to-smart-contracts.html#storage-example).

1. Create `channel-lab/src/SimpleStorage.sol`.
2. Type this small learning implementation:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract SimpleStorage {
    uint256 private storedData;

    function set(uint256 newValue) external {
        storedData = newValue;
    }

    function get() external view returns (uint256) {
        return storedData;
    }
}
```

3. Read it in this order:

| Line/expression | Meaning |
| --- | --- |
| `SPDX-License-Identifier` | States the license for this new example |
| `pragma solidity 0.8.30` | Requires this exact compiler version |
| `contract SimpleStorage` | Defines a contract type |
| `uint256 private storedData` | Stores an unsigned integer persistently; it starts at zero |
| `set(uint256 newValue)` | Receives an integer argument |
| `external` | Exposes the function to external calls |
| `storedData = newValue` | Changes persistent contract state |
| `view` | Declares that this function does not modify state |
| `returns (uint256)` | Declares the return type |
| `return storedData` | Returns the current value |

`private` restricts Solidity-level access; it does not make blockchain data secret. A state-changing on-chain transaction costs gas. Reading through an off-chain call does not require paying transaction fees, although calling a view function inside a transaction still consumes gas.

4. Run `forge build`. Expected: compilation succeeds.
5. Write answers in your notes: Who can call `set`? What value exists before the first `set`? What would happen if two users call `set` in separate transactions?

**Done when:** you can explain each expression without reading this table. It is fine to ask about one expression at a time.

## Lesson 2 — Write and break your first tests

1. Create `channel-lab/test/SimpleStorage.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {SimpleStorage} from "../src/SimpleStorage.sol";

contract SimpleStorageTest is Test {
    SimpleStorage internal store;

    function setUp() public {
        store = new SimpleStorage();
    }

    function test_InitialValueIsZero() public {
        assertEq(store.get(), 0);
    }

    function test_SetUpdatesValue() public {
        store.set(42);
        assertEq(store.get(), 42);
    }
}
```

2. Understand each new part: `import` loads definitions; `is Test` inherits test helpers; `new` deploys a contract; `setUp` runs before each test; functions beginning with `test` are tests; `assertEq` checks equality.
3. Run:

```bash
forge test --match-contract SimpleStorageTest -vv
```

Expected: both tests pass.

4. Change only the second assertion's expected value to `43`. Run the same command. Expected: that test fails. Read the expected and actual values.
5. Restore `42`, then add `test_SetTwiceKeepsLatestValue`: set `7`, set `9`, assert that `get()` returns `9`.
6. Add a fuzz test `testFuzz_SetRoundTrip(uint256 value)`: set `value`, then assert that reading it returns `value`. Forge supplies many inputs.
7. Run `forge fmt`, then `forge test`. Commit your working code and notes.

**Done when:** three normal tests and the fuzz test pass, and you can explain why deliberately expecting `43` failed. Do not continue if the test syntax still feels mysterious.

## Lesson 3 — Specify the channel before coding

**Read in order:** [simple payment channel](https://programtheblockchain.com/posts/2018/02/23/writing-a-simple-payment-channel/), then [long-lived payment channel](https://programtheblockchain.com/posts/2018/03/02/building-long-lived-payment-channels/). Read the explanation before the full source.

1. Create `channel-lab/docs/SPEC.md` and describe the sender, recipient, and escrow contract.
2. Write this worked example: sender deposits 1 ETH; authorizes 0.2 ETH; recipient claims 0.2 ETH; sender later authorizes 0.5 ETH total; recipient can claim another 0.3 ETH.
3. Define amounts in wei. Distinguish a signature from a transaction: signing an authorization does not itself transfer ETH.
4. Describe the first implementation: fixed participants, ETH only, one channel per deployment, no reopening, no proxy, EOA sender signatures initially.
5. Describe the eventual long-lived states: `Open -> Closing -> Closed`. The recipient may also settle directly from `Open` to `Closed`.
6. Choose precise rules for the long-lived version:

| Operation | Rule to implement |
| --- | --- |
| Deposit | Sender only, positive value, only while Open |
| Recipient claim | Valid sender signature, cumulative total greater than already credited, sufficient unallocated escrow |
| Start sender close | Sender only, Open only; set the deadline once |
| Claim during Closing | Allowed strictly before the deadline |
| Recipient settlement | Allowed while Open or Closing before the deadline; settle the unpaid authorized amount and refund the rest |
| Finalize timeout | Allowed at or after the deadline; refund remaining unallocated escrow to sender |
| Closed | No new deposits or claims; previously credited payouts remain withdrawable |

For this project, use separate withdrawable payout credits. A claim allocates ETH to the recipient; a payout withdrawal transfers that credit. A sender refund also becomes a credit. Neither participant's reverting receive function should prevent the other participant's settlement.

7. Record the assumptions: the recipient checks funding before accepting an authorization and monitors the closing deadline. A signature for an unfunded amount does not create ETH. A closing window cannot guarantee transaction inclusion.

**Done when:** you can calculate the remaining escrow and both participants' credits on paper. Commit the specification before implementation.

## Lesson 4 — Build a modern simple payment channel

**Goal:** implement the fixed-expiration version first. Use the old `SmartContract.sol` to understand intent, not as code to paste into Solidity 0.8.x.

1. Install a pinned dependency from `channel-lab/`:

```bash
forge install OpenZeppelin/openzeppelin-contracts@v5.4.0 --no-git
```

With `--no-git`, dependencies are ordinary files. Commit the vendored libraries and record their release versions so another clone gets the same code. Later you can learn submodule-based dependency management.

2. Create `src/SimplePaymentChannel.sol` and `test/SimplePaymentChannel.t.sol`. Implement each following item separately, with a test immediately after it.
3. Add immutable sender, recipient, and expiration. Use `constructor`, `block.timestamp`, explicit visibility, and Solidity 0.8.30. Reject a zero recipient, a recipient equal to the sender, and zero duration. Test initial funding and invalid construction.
4. Add explicit closed state. Closure is permanent; do not use `selfdestruct`. [EIP-6780](https://eips.ethereum.org/EIPS/eip-6780) explains why contract deletion is no longer a reliable closing mechanism.
5. Add OpenZeppelin `EIP712` and `ECDSA`. Imports use paths such as `openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol`. Start with one signed structure: `Payment(uint256 cumulativeAmount)`.
6. Build its typed-data hash using the domain name, version, `block.chainid`, and this contract's address. Hash the encoded Payment structure, then use EIP712's `_hashTypedDataV4`. Recover the signer with ECDSA and require that it is the sender. The amount is cumulative wei, not an individual transfer amount.
7. Expose a view helper returning the payment digest. In tests, use `vm.addr` and `vm.sign` with a test-only key. Encode the signature as `abi.encodePacked(r, s, v)`. A raw `vm.sign` of this digest must not receive an extra personal-sign prefix.
8. Implement recipient-only settlement before expiration. Verify the signature and escrow, mark the channel closed, credit the authorized amount to the recipient, and credit the remainder to the sender. Add events.
9. Implement timeout settlement at or after expiration: mark closed and credit remaining escrow to the sender. Previously allocated credits must not be reallocated.
10. Implement `withdrawPayout`: read the caller's credit, reject zero, clear the credit before sending ETH with checked `call`, and use a reentrancy guard. A failed transfer must revert so the credit is preserved. Use OpenZeppelin `ReentrancyGuard` from `openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol`.
11. Test a valid payout, wrong caller, wrong signer, modified amount, malformed signature, insufficient escrow, repeated settlement, and a signature presented to another deployment.
12. Test one second before expiration, exactly at expiration, and after it using `vm.warp`.

A cumulative total plus one permanent channel lifecycle provides replay protection within this design; EIP-712 alone does not. If you later allow reopening, you need a new channel identity or epoch and corresponding tests.

**Done when:** all the above cases have tests, credits cannot be claimed twice, and you can explain why settlement and payout withdrawal are separate. Use [OpenZeppelin cryptography documentation](https://docs.openzeppelin.com/contracts/5.x/api/utils/cryptography) and [Solidity security considerations](https://docs.soliditylang.org/en/v0.8.30/security-considerations.html) when stuck.

## Lesson 5 — Extend it into a long-lived channel

1. Create `src/LongLivedPaymentChannel.sol` and a separate test file. Keep the simple implementation working.
2. Replace fixed expiration with the state machine from Lesson 3. Require a positive closing duration. Store the deadline only when closure begins.
3. Add sender-only deposits while Open. Track unallocated escrow separately from pending payout credits.
4. Add `totalClaimed`, meaning cumulative payment already allocated to the recipient, including pending credits. It must never decrease.
5. Implement recipient claims: verify the signature; require `cumulativeAmount > totalClaimed`; compute the difference; check it against unallocated escrow; advance `totalClaimed`; reduce escrow; increase recipient credit. No ETH is sent in this step.
6. Add `startSenderClose`. It changes Open to Closing once and emits the deadline. Reject repeated calls rather than letting them reset the deadline.
7. Permit authorized claims in Closing strictly before the deadline. Reject deposits in Closing.
8. Implement recipient settlement with an authorized total at least `totalClaimed`. Allocate any unpaid difference, credit the remaining escrow as a sender refund, and close permanently. A total equal to `totalClaimed` must permit closure without another payment.
9. Implement timeout finalization at or after the deadline. Refund only unallocated escrow. Pending recipient credits survive closure.
10. Test the worked example from Lesson 3, a top-up, an old authorization after a newer claim, repeated signatures, repeated closing requests, and every deadline boundary.

**Done when:** the recipient gets 0.2 ETH and then 0.3 ETH from totals of 0.2 and 0.5 ETH, and a timeout never takes previously credited payments away.

## Lesson 6 — Test it like an attacker

Create test helpers in `test/helpers/`. Keep deliberately vulnerable experiments in test fixtures, clearly labeled. Test each case against your implementation before claiming it is handled.

| Exercise | What to demonstrate |
| --- | --- |
| Replay | Reusing an authorization cannot increase total credits twice |
| Cross-contract / cross-chain replay | The same signature fails with a different verifying contract or chain ID |
| Tampering | Changing the amount or signer invalidates authorization |
| Reentrancy | A malicious receive callback cannot withdraw the same credit twice or corrupt closure |
| Reverting receiver | One party rejecting ETH cannot block the other party's credit or payout |
| Deadline | Before, at, and after the deadline have the specified results |
| Forced ETH | Unexpected ETH does not create claims or break accounting |
| Access control | Unrelated accounts cannot authorize payments or initiate sender closure |

1. For one exercise, intentionally introduce a bug in a local test fixture, show the exploit test succeeding, then show the secure implementation rejecting the attack.
2. Add fuzz tests for cumulative totals, deposits, and amounts around zero and the escrow limit.
3. Add stateful invariant tests with a handler that generates valid sequences of deposits, claims, withdrawals, and closure. Track successful transitions so the campaign cannot appear successful merely because every call reverted.
4. Express these properties in assertions: `totalClaimed` never decreases; Closed never reopens; pending credits are backed; successful payouts cannot exceed funded assets; another signature cannot allocate an already claimed amount again.
5. Account for forced ETH explicitly: contract balance must be **at least** unallocated escrow plus pending credits. Do not require exact equality when unsolicited ETH can arrive. Document whether surplus ETH remains outside the accounted protocol funds.

Run:

```bash
forge fmt --check
forge test -vv
forge coverage
forge test --match-path 'test/invariant/*' -vv
```

The final command applies after you create invariant tests in that directory. Coverage helps find missing paths; passing tests and high coverage do not prove security.

**Done when:** you have at least one reproducible exploit/fix comparison and meaningful invariant tests, including evidence of successful exercised operations.

## Lesson 7 — Make the project reproducible

1. Add a local deployment script and a demo that deposits ETH, creates a typed payment, claims it, starts closure, advances local time, finalizes, and withdraws payouts.
2. Start `anvil` in a separate terminal. Use its disposable keys only for the local chain. Record the exact deployment and interaction commands in `docs/DEMO.md` after you have run them successfully.
3. Cross-check a payment created by an off-chain signing script against the contract's digest helper. The wallet's domain and structure must match the contract exactly.
4. Add GitHub Actions with working directory `channel-lab`: install the recorded Foundry version, then run formatting, build, and tests. Keep all checks local; CI does not need signing secrets for these tests.
5. Add a static-analysis pass, for example Slither. Record its version, command, findings, and your assessment; do not label every detector warning a vulnerability.
6. Verify a fresh clone can reproduce the build. Optional: deploy to a supported testnet, verify source, and link the verified address. Use a separate testnet account.

**Done when:** someone else can reproduce your local demo and CI is green on a named commit.

## Lesson 8 — Turn your work into a portfolio

Create `docs/SECURITY_REVIEW.md` with:

- Scope: exact commit, compiler, dependency versions, and reviewed files.
- Architecture: actors, states, accounting, authorization format, and closing sequence.
- Threat model: trusted assumptions and attacker capabilities.
- Findings: preconditions, impact, reproduction command, root cause, fix, and regression test for each demonstrated issue.
- Limitations: recipient monitoring, underfunded signatures, EOA-only sender support initially, and any unhandled forced-ETH surplus.
- Validation: actual commands and results, plus what they do not prove.

Use “self-review” for your own report. Separate original tutorial observations from deliberately introduced bugs and from vulnerabilities you actually found in your implementation. Give the tutorials credit.

For an engineering application, highlight the contract design, API, signing integration, tests, and demo. For a security application, highlight exploit reproduction, invariants, accounting analysis, and clear findings. Only claim work and results you can explain and reproduce.

## Saving progress

After a completed lesson, from `channel-lab/`:

```bash
forge fmt
forge test
git status
```

Review the diff, stage only the relevant source, tests, documentation, configuration, and intended dependencies, then commit and push your lesson. Do not commit build output or secrets. Update `notes/progress.md` with: completed step, test command/result, one thing learned, and one open question.

## References

- [Solidity introduction, pinned to the lesson compiler](https://docs.soliditylang.org/en/v0.8.30/introduction-to-smart-contracts.html)
- [Your original Solidity introduction link](https://docs.soliditylang.org/en/v0.8.38/introduction-to-smart-contracts.html#simple-smart-contract) — check whether the selected version is a released or development version.
- [Writing a Simple Payment Channel — Steve Marx](https://programtheblockchain.com/posts/2018/02/23/writing-a-simple-payment-channel/)
- [Building Long-Lived Payment Channels — Steve Marx](https://programtheblockchain.com/posts/2018/03/02/building-long-lived-payment-channels/)
- [Foundry documentation](https://www.getfoundry.sh/)
- [OpenZeppelin Contracts v5.4.0 release](https://github.com/OpenZeppelin/openzeppelin-contracts/releases/tag/v5.4.0)
- [Solidity 0.8.30 release](https://github.com/argotorg/solidity/releases/tag/v0.8.30)
- [EIP-6780: changed SELFDESTRUCT behavior](https://eips.ethereum.org/EIPS/eip-6780)

**Your next action: Lesson 0, step 1. Stop at the first unclear command and ask about that exact step.**
