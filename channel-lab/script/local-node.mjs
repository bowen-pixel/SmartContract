import { spawn } from 'node:child_process';
import { createServer } from 'node:net';
import { setTimeout as delay } from 'node:timers/promises';
import { JsonRpcProvider } from 'ethers';

// Pick a free local port instead of attaching to an existing node.
export async function withLocalNode(callback) {
  const probe = createServer();
  await new Promise((resolve, reject) => {
    probe.once('error', reject);
    probe.listen(0, '127.0.0.1', resolve);
  });
  const port = probe.address().port;
  await new Promise((resolve, reject) => probe.close(error => error ? reject(error) : resolve()));
  const node = spawn(process.env.ANVIL_BIN || 'anvil', ['--host', '127.0.0.1', '--port', String(port), '--chain-id', '31337', '--silent']);
  let spawnError;
  let nodeLog = '';
  node.on('error', error => { spawnError = error; });
  node.stderr.on('data', chunk => { nodeLog += chunk; });
  const provider = new JsonRpcProvider(`http://127.0.0.1:${port}`, 31337, { staticNetwork: true });
  provider.pollingInterval = 50;
  try {
    let ready = false;
    for (let attempt = 0; attempt < 50; attempt++) {
      if (spawnError) throw spawnError;
      if (node.exitCode !== null) throw new Error(`Anvil exited: ${nodeLog}`);
      try {
        await provider.send('eth_chainId', []);
        ready = true;
        break;
      } catch { await delay(100); }
    }
    if (!ready) throw new Error('Local Anvil did not start.');
    return await callback(provider);
  } finally {
    provider.destroy();
    node.kill('SIGTERM');
  }
}
