# SmartContract

Completed reference implementations and study notes for Solidity's smart-contract introduction, followed by simple and long-lived ETH payment channels. Code, tests, demos, and a self-review are included so each concept can be read alongside executable examples.

## Notes and matching code

| Part | Takeaways and explanations | Implementation / evidence |
| --- | --- | --- |
| Environment | [Toolchain and project layout](channel-lab/notes/00-toolchain.md) | [Foundry configuration](channel-lab/foundry.toml) |
| Storage | [Persistent state, getters, and callers](channel-lab/notes/01-storage.md) | [SimpleStorage.sol](channel-lab/src/SimpleStorage.sol), [tests](channel-lab/test/SimpleStorage.t.sol) |
| Coins | [Mappings, minting, transfers, events, errors](channel-lab/notes/02-coin.md) | [Coin.sol](channel-lab/src/Coin.sol), [tests](channel-lab/test/Coin.t.sol) |
| Blockchain and EVM | [Transactions, gas, memory, calls, and testing](channel-lab/notes/03-blockchain-and-testing.md) | [Intro demo](channel-lab/script/intro-demo.mjs), [specification](channel-lab/docs/SPEC.md) |
| Simple channel | [Escrow, typed signatures, and fixed expiration](channel-lab/notes/04-simple-channel.md) | [Contract](channel-lab/src/SimplePaymentChannel.sol), [tests](channel-lab/test/SimplePaymentChannel.t.sol) |
| Long-lived channel | [Cumulative claims and delayed closing](channel-lab/notes/05-long-lived-channel.md) | [Contract](channel-lab/src/LongLivedPaymentChannel.sol), [tests](channel-lab/test/LongLivedPaymentChannel.t.sol) |
| Security tests | [Replay, reentrancy, forced ETH, invariants](channel-lab/notes/06-security-testing.md) | [Attack tests](channel-lab/test/Security.t.sol), [invariants](channel-lab/test/invariant/ChannelInvariant.t.sol) |
| Integration | [Signing demo, deployment, and CI](channel-lab/notes/07-integration.md) | [Channel demo](channel-lab/script/demo.mjs), [workflow](.github/workflows/contracts.yml) |
| Review | [What the results demonstrate](channel-lab/notes/08-review.md) | [Security self-review](channel-lab/docs/SECURITY_REVIEW.md), [validation](channel-lab/docs/VALIDATION.md) |

## Run locally

Install [Foundry](https://www.getfoundry.sh/introduction/installation) and Node.js 22 or newer. This project was validated with Foundry **v1.9.0** and Solidity **0.8.30**, targeting Cancun. To select the same Foundry release: `foundryup --install v1.9.0`.

```bash
git clone --recurse-submodules https://github.com/bowen-pixel/SmartContract.git
cd SmartContract/channel-lab
forge fmt --check
forge build
forge test -vv
forge coverage
npm ci --ignore-scripts
npm run demo:intro
npm run demo
```

Already have a clone? Save your local changes, pull the update, then initialize the pinned libraries:

```bash
git pull --ff-only
git submodule update --init --recursive
cd channel-lab
```

Both Node demos create a disposable localhost Anvil chain and stop it afterward. They use unlocked local accounts, require no wallet secrets, and make no testnet or mainnet transactions. See [demo details](channel-lab/docs/DEMO.md) for expected output and the separate deployment script.

For static analysis, activate a Python virtual environment, install `channel-lab/requirements-security.txt`, and run the command in the [validation report](channel-lab/docs/VALIDATION.md). Analyzer warnings are assessed in the self-review.

## Design at a glance

The sender funds escrow and signs cumulative EIP-712 authorizations. The recipient claims the unpaid difference. Claims create payout credits; withdrawals transfer ETH separately. Closing permanently disables new claims while keeping existing credits withdrawable. [Full rules and assumptions](channel-lab/docs/SPEC.md).

The coin ledger is an educational example, not ERC-20. The payment channels are educational reference implementations, not independently audited production systems. They support ECDSA sender signatures, require recipients to monitor deadlines, and deliberately leave forced-ETH surplus outside accounted funds.

The original Solidity 0.4.x contract is retained under [legacy/](legacy/README.md) for comparison and excluded from the modern build.

## Sources

- [Solidity introduction](https://docs.soliditylang.org/en/v0.8.30/introduction-to-smart-contracts.html)
- [Writing a Simple Payment Channel — Steve Marx](https://programtheblockchain.com/posts/2018/02/23/writing-a-simple-payment-channel/)
- [Building Long-Lived Payment Channels — Steve Marx](https://programtheblockchain.com/posts/2018/03/02/building-long-lived-payment-channels/)
- [OpenZeppelin cryptography](https://docs.openzeppelin.com/contracts/5.x/api/utils/cryptography)
- [Foundry documentation](https://www.getfoundry.sh/)

For questions, name the note, contract, and function, and include the relevant snippet or command output. We can work through one expression at a time.
