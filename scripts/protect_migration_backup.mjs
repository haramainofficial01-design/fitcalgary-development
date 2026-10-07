#!/usr/bin/env node
// Encrypt an external recovery directory and verify two independent local copies.
import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto';
import { readFileSync, writeFileSync, statSync, readdirSync, realpathSync, mkdirSync, chmodSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const [source, ...copies] = process.argv.slice(2);
if (!source || copies.length !== 2 || [source, ...copies].some(p => !path.isAbsolute(p))) {
  throw new Error('Supply absolute input directory and two distinct external destination directories.');
}
const actualSource = realpathSync(source);
const targets = copies.map(p => { mkdirSync(p, { recursive: true, mode: 0o700 }); return realpathSync(p); });
if (new Set([actualSource, ...targets]).size !== 3 || [actualSource, ...targets].some(p => p === root || p.startsWith(`${root}${path.sep}`))) {
  throw new Error('All directories must be distinct and outside source control.');
}
const keyPath = path.join(homedir(), 'Library', 'Application Support', 'FitCalgary', 'config', 'migration-backup.key');
const key = readFileSync(keyPath);
if (key.length !== 32 || (statSync(keyPath).mode & 0o077)) throw new Error('Invalid protected encryption key.');
const entries = readdirSync(actualSource, { withFileTypes: true }).filter(x => x.isFile() && /\.(dump|sql|json)$/.test(x.name));
if (!entries.some(x => x.name.endsWith('.dump'))) throw new Error('No database export found.');
const results = [];
for (const entry of entries) {
  const input = path.join(actualSource, entry.name);
  if ((statSync(input).mode & 0o077) !== 0) throw new Error('Input backup permissions are too broad.');
  const raw = readFileSync(input), iv = randomBytes(12), cipher = createCipheriv('aes-256-gcm', key, iv);
  const ciphertext = Buffer.concat([cipher.update(raw), cipher.final()]);
  const serialized = JSON.stringify({ format: 'aes-256-gcm-v1', iv: iv.toString('base64'),
    tag: cipher.getAuthTag().toString('base64'), ciphertext: ciphertext.toString('base64') });
  const checksums = [];
  for (const destination of targets) {
    chmodSync(destination, 0o700);
    const file = path.join(destination, `${entry.name}.enc.json`);
    writeFileSync(file, serialized, { mode: 0o600, flag: 'wx' });
    const saved = readFileSync(file), envelope = JSON.parse(saved);
    const decoder = createDecipheriv('aes-256-gcm', key, Buffer.from(envelope.iv, 'base64'));
    decoder.setAuthTag(Buffer.from(envelope.tag, 'base64'));
    const decrypted = Buffer.concat([decoder.update(Buffer.from(envelope.ciphertext, 'base64')), decoder.final()]);
    if (!decrypted.equals(raw)) throw new Error('Backup round-trip failed.');
    checksums.push(createHash('sha256').update(saved).digest('hex'));
  }
  if (checksums[0] !== checksums[1]) throw new Error('Backup copies differ.');
  results.push({ name: entry.name, bytes: raw.length, encryptedSha256: checksums[0] });
}
for (const destination of targets) writeFileSync(path.join(destination, 'copy-verification.json'),
  JSON.stringify({ encryption: 'AES-256-GCM', verifiedCopies: 2, offDeviceCopy: false, files: results }, null, 2),
  { mode: 0o600, flag: 'wx' });
console.log(JSON.stringify({ encryptedCopiesVerified: 2, files: results.length, offDeviceCopy: false }));
