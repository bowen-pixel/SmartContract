# Reproduce the demos

From `channel-lab/`, with Foundry v1.9.0, Node 22 or newer, and the pinned submodules installed:

```bash
forge build
npm ci --ignore-scripts
npm run demo:intro
npm run demo
```

`demo:intro` should report PASS, stored values 0 -> 42 -> 99, Coin balances Alice 70 / Bob 30, a decoded Sent event, and rejected unauthorized mint/overspend calls.

`demo` should report PASS on chain 31337, depositsETH 1.5, recipientTotalETH 0.5, senderRefundETH 1.0, Closed state, and a matching ethers/Solidity EIP-712 digest. Each demo launches and stops its own disposable local node on a free port. An `anvil` executable must be on PATH; alternatively set `ANVIL_BIN` to its absolute path. No `.env` or wallet key is required.

## Inspect a separate deployment manually

Start Anvil in one terminal (local fake funds only):

```bash
anvil --host 127.0.0.1 --port 8545 --chain-id 31337
```

In another terminal, from `channel-lab/`, select Anvil's default second account as recipient and default first account as the unlocked sender:

```bash
export LOCAL_RECIPIENT=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
forge script script/DeployLocal.s.sol:DeployLocal --rpc-url http://127.0.0.1:8545 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --unlocked --broadcast
```

These publicly known addresses are only useful with a disposable default Anvil instance. The deployment script itself requires chain ID 31337. Stop Anvil with Ctrl-C afterward. Local addresses printed by the automated demos are not public testnet deployments or verified explorer addresses.
