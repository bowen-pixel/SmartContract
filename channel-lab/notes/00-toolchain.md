# Toolchain and repository layout

## Takeaways

Solidity source is compiled into EVM bytecode. Forge builds and tests that source; Anvil provides a local blockchain; Cast is a command-line client. None of these is VS Code itself. `forge: command not found` means the shell cannot locate the executable, even when the repository is correctly cloned.

Use the [official installer](https://www.getfoundry.sh/introduction/installation), reopen the terminal, run `foundryup --install v1.9.0`, and check `forge --version` and `anvil --version`. On Windows, use WSL or Git Bash. The automated implementation here used workspace-local official binaries; it did not configure your VS Code terminal.

## Read the configuration

| Setting in `foundry.toml` | Meaning |
| --- | --- |
| `src`, `test`, `script` | Directories for contracts, tests, and deployment scripts |
| `solc_version = "0.8.30"` | Exact compiler baseline, independent of the newest release |
| `evm_version = "cancun"` | Compiler target; runtime chain rules still matter |
| `optimizer_runs = 200` | Optimization tradeoff setting, not a test count |
| `remappings` | Translates import prefixes into the pinned library directories |
| `fuzz.runs = 256` | Input trials for each fuzz test |
| `invariant.runs = 128`, `depth = 64` | Generated stateful sequences and their maximum length |
| `fail_on_revert = true` | Unexpected handler reverts fail the invariant campaign |

The dependency submodules record exact commits: forge-std v1.9.7 and OpenZeppelin Contracts v5.4.0. `git submodule update --init --recursive` installs the recorded revisions. Do not replace them by copying random versions into `lib/`.

## Files and commands

`src/` is executable contract code. `test/` checks behavior. `notes/` explains the implementation. `docs/` specifies the design and records evidence. `out/`, `cache/`, `node_modules/`, and local broadcast artifacts are generated and ignored.

Run `forge build` and `forge test` from `channel-lab/`. From the root, use `cd channel-lab` first. `npm ci --ignore-scripts` installs the versions in the lockfile. Both demos need `anvil` on PATH; `ANVIL_BIN` may point to a workspace-local binary.

## What to remember

A successful build checks syntax and compilation. Passing tests check selected behavior. Neither proves a contract is secure, and neither updates a deployed contract automatically.
