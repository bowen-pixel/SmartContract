# Signing, demo, and CI takeaways

Files: [intro demo](../script/intro-demo.mjs), [channel demo](../script/demo.mjs), [local node helper](../script/local-node.mjs), [deployment script](../script/DeployLocal.s.sol), [workflow](../../.github/workflows/contracts.yml).

## Intro demo

The helper starts disposable Anvil on an available localhost port and always stops it in `finally`. The script obtains two unlocked local signers, deploys Storage and Coin from Forge artifacts, sends real local transactions, waits for receipts, and verifies final state. It also decodes `Sent` from a receipt and confirms unauthorized minting and overspending fail through simulated calls.

`ContractFactory` deploys compiled bytecode. `waitForDeployment` waits for the deployment. `transaction.wait()` waits for execution. Solidity uint256 values are returned as JavaScript `bigint`, hence comparisons such as `99n`. These are not floating-point ETH values.

## Channel demo

`parseEther` converts a decimal ETH string to integer wei. The EIP-712 domain and Payment type match the Solidity implementation exactly. `TypedDataEncoder.hash` is compared to `paymentDigest` before the sender signs with `signTypedData`. No extra personal-sign prefix is added. The recipient submits the resulting signature in a transaction.

The sequence deposits 1 ETH, claims/withdraws 0.2 ETH, adds 0.5 ETH, claims cumulative 0.5 ETH, starts closing, advances local time, finalizes, and withdraws credits. The assertions require Closed state, 0.5 ETH cumulative recipient allocation, 1.5 ETH total payouts, and zero pending credits.

## Deployment and automation

`DeployLocal.s.sol` demonstrates Forge broadcasting without putting a private key in the source. It requires chain ID 31337 and reads a recipient address from `LOCAL_RECIPIENT`. See [DEMO.md](../docs/DEMO.md) for the exact unlocked-Anvil command.

GitHub Actions checks a fresh submodule checkout, formatting, build, tests/invariants, coverage, npm lockfile installation, both demos, and Slither. Foundry is pinned to v1.9.0; compiler and library revisions are pinned separately. Expected analyzer findings are reviewed rather than making every informational detector warning fail the workflow.

## What to remember

A passing Solidity signature test can still hide a front-end encoding mismatch. The independently implemented ethers hash comparison verifies the same domain, type, and amount across the boundary. CI is evidence only after its particular run finishes successfully; the workflow file alone is not a green build.
