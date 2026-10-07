#!/usr/bin/env node
// Fresh local container, random temporary credentials and loopback-only exposure.
import { execFileSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const temporary = mkdtempSync(path.join(homedir(), 'Library', 'Application Support', 'FitCalgary', 'storage-rehearsal-'));
const name = `fitcalgary-storage-${randomBytes(5).toString('hex')}`;
const access = randomBytes(16).toString('hex'), secret = randomBytes(32).toString('hex');
const envFile = path.join(temporary, 'storage.env');
const bucket = 'fitcalgary-cors-rehearsal';
writeFileSync(envFile, `AWS_ACCESS_KEY_ID=${access}\nAWS_SECRET_ACCESS_KEY=${secret}\nS3_BUCKET=${bucket}\n`, { mode: 0o600 });
function docker(args) {
  return execFileSync('docker', ['--context', 'colima-fitcalgary', ...args], {
    timeout: 60000, stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 8 * 1024 * 1024,
  }).toString().trim();
}
let created = false;
try {
  docker(['run', '-d', '--name', name, '--env-file', envFile, '-p', '127.0.0.1::8333',
    'chrislusf/seaweedfs:4.45', 'mini', '-dir=/data', '-ip=127.0.0.1', '-ip.bind=0.0.0.0',
    '-s3.port=8333', '-admin.ui=false', '-webdav=false', '-s3.port.iceberg=0',
    '-s3.port.lance=0', '-master.telemetry=false']);
  created = true;
  const bound = docker(['port', name, '8333/tcp']);
  if (!/^127\.0\.0\.1:\d+$/.test(bound)) throw new Error('Storage was not restricted to loopback.');
  const endpoint = `http://${bound}`;
  let ready = false;
  for (let attempt = 0; attempt < 100; attempt++) {
    try {
      const response = await fetch(endpoint, { signal: AbortSignal.timeout(1000) });
      if (response.status === 403) { ready = true; break; }
      if (response.ok) throw new Error('Unauthenticated storage access is enabled.');
    } catch (error) {
      if (error.message === 'Unauthenticated storage access is enabled.') throw error;
    }
    await new Promise(resolve => setTimeout(resolve, 250));
  }
  if (!ready) throw new Error('Authenticated storage readiness failed.');
  const env = { ...process.env, STORAGE_TEST_ENDPOINT: endpoint, STORAGE_TEST_ACCESS_KEY: access,
    STORAGE_TEST_SECRET_KEY: secret, STORAGE_TEST_USE_PATH_STYLE: 'true',
    S3_ENDPOINT: endpoint, S3_REGION: 'us-east-1', S3_BUCKET: bucket,
    S3_ACCESS_KEY_ID: access, S3_SECRET_ACCESS_KEY: secret, S3_USE_PATH_STYLE: 'true',
    STORAGE_CORS_ORIGIN: 'https://fitcalgary-web.fitcalgary.workers.dev' };
  const go = path.join(root, '.tooling', 'go', 'bin', 'go');
  const cwd = path.join(root, 'services', 'api-go');
  for (const args of [['test', './internal/storage', '-run', '^TestPrivateMultipartStorage$', '-count=1', '-v'],
    ['run', './cmd/storage-configure']]) {
    const output = execFileSync(go, args, { cwd, env, timeout: 120000,
      stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 8 * 1024 * 1024 });
    writeFileSync(path.join(temporary, args[0] === 'test' ? 'transport.log' : 'cors.log'), output, { mode: 0o600 });
  }
  console.log(JSON.stringify({ localContainerStorage: 'PASS', productionVerified: false,
    unsignedAccessRejected: true, twoPart7MiBUpload: 'PASS', exactBytes: 'PASS',
    tamperedSignatureRejected: true, rangePlayback: 'PASS', deletion: 'PASS',
    pathStyleBrowserCorsReadBack: 'PASS' }, null, 2));
} catch (error) {
  writeFileSync(path.join(temporary, 'private-failure.log'), Buffer.from(error.stderr ?? error.message ?? ''), { mode: 0o600 });
  console.error('Local storage rehearsal failed; raw errors/temporary credentials withheld.');
  process.exitCode = 1;
} finally {
  if (created) { try { docker(['rm', '-f', name]); } catch { console.error('Local storage container cleanup requires attention.'); process.exitCode = 1; } }
}
