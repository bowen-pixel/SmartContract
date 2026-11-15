import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { ContractFactory, TypedDataEncoder, parseEther } from 'ethers';

import { withLocalNode } from './local-node.mjs';

await withLocalNode(async provider => {
  const sender = await provider.getSigner(0);
  const recipient = await provider.getSigner(1);
  const artifact = JSON.parse(await readFile(new URL('../out/LongLivedPaymentChannel.sol/LongLivedPaymentChannel.json', import.meta.url), 'utf8'));
  const channel = await new ContractFactory(artifact.abi, artifact.bytecode.object, sender)
    .deploy(await recipient.getAddress(), 3600, { value: parseEther('1') });
  await channel.waitForDeployment();
  const domain = { name: 'PaymentChannel', version: '1', chainId: 31337, verifyingContract: await channel.getAddress() };
  const types = { Payment: [{ name: 'cumulativeAmount', type: 'uint256' }] };
  async function claim(total) {
    const value = { cumulativeAmount: total };
    const digest = TypedDataEncoder.hash(domain, types, value);
    assert.equal(digest, await channel.paymentDigest(total));
    const signature = await sender.signTypedData(domain, types, value);
    await (await channel.connect(recipient).claim(total, signature)).wait();
  }
  await claim(parseEther('0.2'));
  await (await channel.connect(recipient).withdrawPayout()).wait();
  await (await channel.deposit({ value: parseEther('0.5') })).wait();
  await claim(parseEther('0.5'));
  assert.equal(await channel.payouts(await recipient.getAddress()), parseEther('0.3'));
  await (await channel.startSenderClose()).wait();
  await provider.send('evm_increaseTime', [3600]);
  await provider.send('evm_mine', []);
  await (await channel.finalizeTimeout()).wait();
  await (await channel.withdrawPayout()).wait();
  await (await channel.connect(recipient).withdrawPayout()).wait();
  assert.equal(await channel.state(), 2n);
  assert.equal(await channel.totalClaimed(), parseEther('0.5'));
  assert.equal(await channel.totalPaidOut(), parseEther('1.5'));
  assert.equal(await channel.payouts(await recipient.getAddress()), 0n);
  assert.equal(await channel.payouts(await sender.getAddress()), 0n);
  console.log(JSON.stringify({ result: 'PASS', chainId: 31337, channel: await channel.getAddress(),
    depositsETH: '1.5', recipientTotalETH: '0.5', senderRefundETH: '1.0', finalState: 'Closed',
    digestCrossCheck: 'ethers EIP-712 hash matches Solidity' }, null, 2));
});
