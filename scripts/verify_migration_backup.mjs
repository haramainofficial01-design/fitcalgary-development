#!/usr/bin/env node
// Restore an existing dump into a temporary socket-only PostgreSQL cluster.
// The production database and the input backup are never modified.
import { execFileSync } from 'node:child_process';
import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto';
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync, realpathSync, statSync, chmodSync } from 'node:fs';
import { tmpdir, homedir, userInfo } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const [input, destination, verificationScope = 'historical'] = process.argv.slice(2);
if (!['historical', 'current'].includes(verificationScope)) throw new Error('Verification scope must be historical or current.');
if (!input || !destination || !path.isAbsolute(input) || !path.isAbsolute(destination)) {
  throw new Error('Usage: verify_migration_backup.mjs /absolute/source.dump /absolute/backup-directory');
}
const source = realpathSync(input);
const pg = process.env.FITCALGARY_PG_BIN_DIR;
if (!pg || !path.isAbsolute(pg)) throw new Error('Set FITCALGARY_PG_BIN_DIR to compatible PostgreSQL binaries.');
const keyPath = path.join(homedir(), 'Library', 'Application Support', 'FitCalgary', 'config', 'migration-backup.key');
const key = readFileSync(keyPath);
if (key.length !== 32 || (statSync(keyPath).mode & 0o077)) throw new Error('Invalid backup key or permissions.');
mkdirSync(destination, { recursive: true, mode: 0o700 });
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const actualDestination = realpathSync(destination);
if (actualDestination === root || actualDestination.startsWith(`${root}${path.sep}`)) {
  throw new Error('Backup verification must remain outside the repository.');
}
chmodSync(actualDestination, 0o700);
const raw = readFileSync(source);
const iv = randomBytes(12), cipher = createCipheriv('aes-256-gcm', key, iv);
const ciphertext = Buffer.concat([cipher.update(raw), cipher.final()]);
const output = path.join(destination, `${verificationScope}-database.enc.json`);
writeFileSync(output, JSON.stringify({ format: 'aes-256-gcm-v1', iv: iv.toString('base64'),
  tag: cipher.getAuthTag().toString('base64'), ciphertext: ciphertext.toString('base64') }), { mode: 0o600, flag: 'wx' });
const saved = JSON.parse(readFileSync(output, 'utf8'));
const decoder = createDecipheriv('aes-256-gcm', key, Buffer.from(saved.iv, 'base64'));
decoder.setAuthTag(Buffer.from(saved.tag, 'base64'));
const decrypted = Buffer.concat([decoder.update(Buffer.from(saved.ciphertext, 'base64')), decoder.final()]);
if (!decrypted.equals(raw)) throw new Error('Encrypted dump round-trip mismatch.');
const temporary = mkdtempSync(path.join(tmpdir(), 'fitcalgary-restore-check-'));
const dump = path.join(temporary, 'restore.dump');
writeFileSync(dump, decrypted, { mode: 0o600, flag: 'wx' });
const data = path.join(temporary, 'pgdata');
const env = { ...process.env, PGHOST: temporary, PGPORT: '55473', PGUSER: userInfo().username, PGDATABASE: 'verification' };
delete env.PGPASSWORD;
delete env.PGSERVICE;
let lastCommand;
function command(name, args, extra = {}) {
  lastCommand = name;
  return execFileSync(path.join(pg, name), args, { env, timeout: 120000,
    stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 16 * 1024 * 1024, ...extra }).toString();
}
let started = false;
try {
  command('initdb', ['-D', data, '--auth-local=peer', '--auth-host=scram-sha-256', '--encoding=UTF8']);
  command('pg_ctl', ['-D', data, '-l', path.join(temporary, 'server.log'), '-o', `-k '${temporary}' -p 55473 -c listen_addresses=''`, '-w', 'start']);
  started = true;
  command('createdb', ['verification']);
  command('pg_restore', ['--exit-on-error', '--no-owner', '--no-acl', '--dbname=verification', dump]);
  const counts = JSON.parse(command('psql', ['-X', '-At', '-v', 'ON_ERROR_STOP=1', '-c',
    `SELECT json_build_object('bytes',pg_database_size(current_database()),'tables',(SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'),'identityRealmTable',to_regclass('public.realm') IS NOT NULL);`]));
  for (const table of ['gyms', 'clubs', 'events', 'profiles', 'results', 'submissions', 'submission_reviews',
    'audit_logs', 'notifications', 'saved_gyms', 'user_roles', 'realm', 'user_entity', 'credential',
    'federated_identity', 'client', 'identity_provider', 'user_session', 'offline_user_session']) {
    const exists = command('psql', ['-X', '-At', '-c', `SELECT to_regclass('public.${table}') IS NOT NULL`]).trim() === 't';
    if (exists) counts[table] = Number(command('psql', ['-X', '-At', '-v', 'ON_ERROR_STOP=1', '-c', `SELECT count(*) FROM public.${table}`]).trim());
  }
  const report = { sourceBackupName: path.basename(source), sourceModified: statSync(source).mtime.toISOString(),
    status: `${verificationScope.toUpperCase()} DATABASE BACKUP RESTORED + ENCRYPTION VERIFIED`,
    verificationScope, sourceSha256: createHash('sha256').update(raw).digest('hex'),
    keycloakDatabasePresent: counts.identityRealmTable,
    encryptedSha256: createHash('sha256').update(readFileSync(output)).digest('hex'), counts,
    temporaryCluster: temporary };
  writeFileSync(path.join(destination, `${verificationScope}-restore-verification.json`), JSON.stringify(report, null, 2), { mode: 0o600, flag: 'wx' });
  console.log(JSON.stringify(report, null, 2));
} catch {
  console.error(`Backup verification failed at ${lastCommand}; no production changes. Raw data/errors withheld.`);
  process.exitCode = 1;
} finally {
  if (started) command('pg_ctl', ['-D', data, '-m', 'fast', '-w', 'stop']);
  // Preserve the isolated, restricted evidence until operator cleanup.
}
