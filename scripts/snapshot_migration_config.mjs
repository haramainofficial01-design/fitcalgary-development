#!/usr/bin/env node
// Read-only Railway inspection. Secret values are encrypted outside the project.
import { execFileSync } from 'node:child_process';
import { createCipheriv, createDecipheriv, randomBytes, createHash } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync, existsSync, realpathSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const base = path.join(homedir(), 'Library', 'Application Support', 'FitCalgary');
const destination = process.argv[2];
if (!destination || !path.isAbsolute(destination)) throw new Error('Provide an absolute backup directory outside the repository.');
mkdirSync(destination, { recursive: true, mode: 0o700 });
const target = realpathSync(destination);
if (target === root || target.startsWith(`${root}${path.sep}`)) throw new Error('Backups must not be placed in the source repository.');
function railway(args) {
  try {
    return JSON.parse(execFileSync('npx', ['--yes', '@railway/cli', ...args], {
      cwd: root, maxBuffer: 32 * 1024 * 1024, timeout: 60000,
      stdio: ['ignore', 'pipe', 'pipe'],
    }).toString());
  } catch { throw new Error(`Railway read failed: ${args[0]}; raw output withheld.`); }
}
const status = railway(['status', '--json']);
if (status.name !== 'fitcalgary-production') throw new Error('Refusing to snapshot an unrelated project.');
const environment = status.environments.edges.find(({ node }) => node.name === 'production')?.node;
if (!environment) throw new Error('Production environment not found.');
const variables = {};
for (const { node } of status.services.edges) {
  variables[node.name] = railway(['variable', 'list', '--project', status.id,
    '--environment', environment.id, '--service', node.id, '--json']);
}
mkdirSync(path.join(base, 'config'), { recursive: true, mode: 0o700 });
const keyPath = path.join(base, 'config', 'migration-backup.key');
if (!existsSync(keyPath)) writeFileSync(keyPath, randomBytes(32), { mode: 0o600, flag: 'wx' });
if ((statSync(keyPath).mode & 0o077) !== 0) throw new Error('Backup key permissions must be 0600.');
const key = readFileSync(keyPath);
if (key.length !== 32) throw new Error('Invalid encryption key length.');
const plaintext = Buffer.from(JSON.stringify({ status, variables }));
const iv = randomBytes(12);
const cipher = createCipheriv('aes-256-gcm', key, iv);
const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
const envelope = { format: 'aes-256-gcm-v1', iv: iv.toString('base64'),
  tag: cipher.getAuthTag().toString('base64'), ciphertext: ciphertext.toString('base64') };
const output = path.join(target, 'railway-config.enc.json');
writeFileSync(output, JSON.stringify(envelope), { mode: 0o600, flag: 'wx' });
const reread = JSON.parse(readFileSync(output, 'utf8'));
const decoder = createDecipheriv('aes-256-gcm', key, Buffer.from(reread.iv, 'base64'));
decoder.setAuthTag(Buffer.from(reread.tag, 'base64'));
const restored = Buffer.concat([decoder.update(Buffer.from(reread.ciphertext, 'base64')), decoder.final()]);
if (!restored.equals(plaintext)) throw new Error('Encrypted configuration verification failed.');
const report = {
  project: status.name, configurationBackup: 'ENCRYPTED + DECRYPTION VERIFIED',
  databaseBackup: 'NOT YET VERIFIED', keyLocation: 'FitCalgary protected local configuration directory',
  sha256: createHash('sha256').update(readFileSync(output)).digest('hex'),
  services: environment.serviceInstances.edges.map(({ node }) => ({
    name: node.serviceName, activeDeployments: node.activeDeployments.length,
    status: node.latestDeployment?.status ?? 'NONE',
    variableNames: Object.keys(variables[node.serviceName] ?? {}).sort(),
  })),
  volumes: environment.volumeInstances.edges.map(({ node }) => ({
    name: node.volume.name, usedMB: node.currentSizeMB, allocatedMB: node.sizeMB, state: node.state,
  })),
};
writeFileSync(path.join(target, 'inventory.json'), JSON.stringify(report, null, 2), { mode: 0o600, flag: 'wx' });
console.log(JSON.stringify(report, null, 2));
