# Validation record

Date: 2026-11-15. Commands below assume the recorded tools are on PATH and are run from `channel-lab/`. Execution in the authoring workspace used absolute paths to the same Foundry binaries. No user wallet or real funds were used.

## Versions

- Foundry v1.9.0, commit 6056c5845d34205a83cf7108042adb137325c9df.
- Official macOS ARM64 archive SHA-256: 38f9af72b266c38ce2e4dfc659ae9cbd1f78c01b34738a76b6c4cb9610579426, checked against GitHub release metadata.
- Solidity 0.8.30; EVM target Cancun; optimizer 200 runs.
- forge-std v1.9.7; OpenZeppelin Contracts v5.4.0, exact submodule revisions in the parent repository.
- Node 24.18.1 in the local checks; CI selects Node 22. ethers 6.15.0 and transitive dependencies are in package-lock.json.
- Slither 0.11.3 in a local Python virtual environment.

## Build and tests

```bash
forge fmt --check
forge build
forge test -vv
forge coverage
```

Formatting and compilation passed. Foundry v1.9.0 reports **42 checks passed, zero failed, zero skipped** across six suites. This consists of 41 test functions (including four fuzz tests) plus one grouped invariant campaign containing three invariant assertions. Each fuzz test uses 256 runs. The stateful campaign used 128 runs x 64 calls = 8,192 calls, with zero handler reverts.

| Suite | Reported checks |
| --- | ---: |
| SimpleStorageTest | 4 |
| CoinTest | 8 |
| SimplePaymentChannelTest | 13 |
| LongLivedPaymentChannelTest | 11 |
| SecurityTest | 4 |
| ChannelInvariantTest | 2: grouped invariants plus deterministic handler scenario |

The invariant selector report exercises deposit, claim, withdraw, startClose, settle, and tick. A handler may intentionally skip actions that are inapplicable in the current state. Seeded successful operations and counters prevent an entirely empty campaign from being mistaken for coverage.

## Coverage and warnings

Reported line coverage in each of the five production source files is 100%. Reported branches are Coin 100%, LongLivedPaymentChannel 100%, PaymentChannelBase 90%, SimplePaymentChannel 66.67%, and SimpleStorage not applicable. These figures are instrumentation output, not proof of complete path exploration.

Coverage disables optimization for instrumentation and emitted source-anchor warnings. The combined report, which also includes scripts/test helpers, is 96.84% lines, 96.21% statements, 86.96% branches, and 97.78% functions. Constructors/source anchoring affect interpretation. The deliberately forced-ETH test fixture emits the expected selfdestruct deprecation warning; modern production contracts contain no selfdestruct.

A restricted-environment warning prevented saving Foundry's global signature cache after local runs. It did not fail compilation or tests and is not a contract issue. Build lint observations and static-analysis results are assessed in SECURITY_REVIEW.md.

## Integration and deployment

```bash
npm ci --ignore-scripts
npm run demo:intro
npm run demo
```

Both demos passed against temporary localhost Anvil instances. The intro demo verifies initial and overwritten storage, Coin balances 70/30, a decoded transfer event, and rejected mint/overspend attempts. The channel demo independently compares ethers and Solidity EIP-712 digests, then verifies 1.5 ETH total funding, 0.5 ETH recipient allocation, 1 ETH sender refund, Closed state, and zero remaining credits after withdrawals.

The separate Forge deployment command in DEMO.md was also executed successfully against a temporary chain-31337 Anvil instance on port 18546. The documented port 8545 is interchangeable. No public network deployment was performed.

## Static analysis

Activate an isolated Python environment, then:

```bash
pip install -r requirements-security.txt
slither . --filter-paths 'lib/' --exclude-dependencies --fail-none
```

Slither analyzed 17 contracts using 100 detectors and returned six findings: four timestamp, one low-level-call, one immutable-state suggestion. The normalized checked-in summary omits machine-specific absolute paths. `--fail-none` permits reporting reviewed warnings; it does not imply no findings exist. CI includes the analyzer command as well as the tests.

## Scope hashes and CI

SOURCE_SHA256.txt hashes production code, tests, scripts, build/dependency configuration, and the workflow. Documentation is outside that content manifest. GitHub Actions runs these checks on a fresh recursive checkout; consult the repository Actions page for the result of a particular pushed commit. Local results above are distinct from the remote run.
