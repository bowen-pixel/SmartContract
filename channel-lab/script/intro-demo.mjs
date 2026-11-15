import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { ContractFactory } from 'ethers';
import { withLocalNode } from './local-node.mjs';

await withLocalNode(async provider => {
  const alice = await provider.getSigner(0);
  const bob = await provider.getSigner(1);
  const aliceAddress = await alice.getAddress();
  const bobAddress = await bob.getAddress();
  async function deploy(name) {
    const artifact = JSON.parse(await readFile(new URL(`../out/${name}.sol/${name}.json`, import.meta.url), 'utf8'));
    const contract = await new ContractFactory(artifact.abi, artifact.bytecode.object, alice).deploy();
    await contract.waitForDeployment();
    return contract;
  }
  const storage = await deploy('SimpleStorage');
  assert.equal(await storage.get(), 0n);
  await (await storage.set(42)).wait();
  assert.equal(await storage.get(), 42n);
  await (await storage.connect(bob).set(99)).wait();
  assert.equal(await storage.get(), 99n);

  const coin = await deploy('Coin');
  assert.equal(await coin.minter(), aliceAddress);
  await (await coin.mint(aliceAddress, 100)).wait();
  const receipt = await (await coin.send(bobAddress, 30)).wait();
  assert.equal(await coin.balances(aliceAddress), 70n);
  assert.equal(await coin.balances(bobAddress), 30n);
  const sent = receipt.logs.map(log => coin.interface.parseLog(log)).find(log => log?.name === 'Sent');
  assert.equal(sent.args.from, aliceAddress);
  assert.equal(sent.args.to, bobAddress);
  assert.equal(sent.args.amount, 30n);
  await assert.rejects(coin.connect(bob).mint.staticCall(bobAddress, 100));
  await assert.rejects(coin.connect(bob).send.staticCall(aliceAddress, 50));
  console.log(JSON.stringify({ result: 'PASS', storage: { initial: 0, aliceSet: 42, bobOverwrites: 99 },
    coin: { alice: 70, bob: 30, event: 'Sent', unauthorizedMint: 'rejected', overspend: 'rejected' } }, null, 2));
});
