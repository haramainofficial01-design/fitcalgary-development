#!/usr/bin/env node
// Export only an already-running, existing PostgreSQL service on Railway Free.
// Credentials and complete database contents remain outside the repository.
import { execFileSync } from 'node:child_process';
import { mkdirSync, realpathSync, writeFileSync, chmodSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const [service, destination] = process.argv.slice(2);
const approved = {
  Postgres: '33bdf5eb-eb18-428e-9903-ea67a43e9bd5',
  'Postgres-k1st': '2c818a6b-2e2d-4a3d-a9b4-dcf09908bca0',
};
if (!approved[service] || !destination || !path.isAbsolute(destination)) {
  throw new Error('Supply the approved source service and an absolute external backup directory.');
}
mkdirSync(destination, { recursive: true, mode: 0o700 });
const target = realpathSync(destination);
if (target === root || target.startsWith(`${root}${path.sep}`)) throw new Error('Backup destination must be outside source.');
chmodSync(target, 0o700);
const pg = process.env.FITCALGARY_PG_BIN_DIR;
if (!pg || !path.isAbsolute(pg)) throw new Error('Set compatible PostgreSQL binary directory.');
function railway(args) {
  return JSON.parse(execFileSync('npx', ['--yes', '@railway/cli', ...args], {
    cwd: root, timeout: 60000, maxBuffer: 16 * 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'],
  }));
}
let lastOperation = 'preflight', permitted = false, deploymentId;
try {
  const status = railway(['status', '--json']);
  if (status.name !== 'fitcalgary-production') throw new Error('Wrong project.');
  const environment = status.environments.edges.find(x => x.node.name === 'production').node;
  const instance = environment.serviceInstances.edges.find(x => x.node.serviceName === service)?.node;
  if (!instance?.activeDeployments.some(x => x.status === 'SUCCESS')) throw new Error('Source database is not running.');
  if (instance.source?.image !== 'ghcr.io/railwayapp-templates/postgres-ssl:18') throw new Error('Unexpected database image.');
  const volume = environment.volumeInstances.edges.find(x => x.node.volume.id === approved[service])?.node;
  if (!volume || volume.mountPath !== '/var/lib/postgresql/data' || volume.state !== 'READY' || volume.sizeMB > 500) {
    throw new Error('Original database volume validation failed.');
  }
  if (environment.serviceInstances.edges.some(x => x.node.serviceName !== service && x.node.activeDeployments.some(d => d.status === 'SUCCESS'))) {
    throw new Error('Other workloads must remain stopped.');
  }
  const workspace = railway(['api', 'query { workspace(workspaceId:"da554107-a29c-4592-9ec4-561a968dbeb0") { plan customer { remainingUsageCreditBalance defaultPaymentMethodId } } }', '--compact']).data.workspace;
  if (workspace.plan !== 'FREE' || workspace.customer.defaultPaymentMethodId !== null || workspace.customer.remainingUsageCreditBalance < 0.05) {
    throw new Error('Free-only recovery budget validation failed.');
  }
  permitted = true;
  deploymentId = instance.activeDeployments.find(x => x.status === 'SUCCESS').id;
  const variables = railway(['variable', 'list', '--service', service, '--json']);
  const proxy = railway(['tcp-proxy', 'list', '--service', service, '--json']).proxies[0];
  if (!proxy?.domain || !proxy.proxyPort) throw new Error('Temporary database proxy is unavailable.');
  const env = { ...process.env, PGHOST: proxy.domain, PGPORT: String(proxy.proxyPort),
    PGUSER: variables.PGUSER ?? variables.POSTGRES_USER,
    PGPASSWORD: variables.PGPASSWORD ?? variables.POSTGRES_PASSWORD,
    PGSSLMODE: 'require', PGCONNECT_TIMEOUT: '15', PGDATABASE: 'postgres' };
  delete env.PGSERVICE;
  delete env.PGSERVICEFILE;
  function run(binary, args) {
    lastOperation = binary;
    return execFileSync(path.join(pg, binary), args, { env, timeout: 180000,
      maxBuffer: 16 * 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'] });
  }
  const databases = JSON.parse(run('psql', ['-X', '-At', '-v', 'ON_ERROR_STOP=1', '-c',
    "SELECT coalesce(json_agg(datname ORDER BY datname),'[]') FROM pg_database WHERE datallowconn AND NOT datistemplate"]));
  const manifest = { service, originalVolume: approved[service], retrievedAt: new Date().toISOString(),
    serverVersion: run('psql', ['-X', '-At', '-c', 'SHOW server_version']).toString().trim(), databases: [] };
  for (const [index, database] of databases.entries()) {
    const filename = `database-${index}.dump`;
    const file = path.join(target, filename);
    writeFileSync(file, Buffer.alloc(0), { flag: 'wx', mode: 0o600 });
    run('pg_dump', ['--format=custom', '--dbname', database, '--file', file]);
    env.PGDATABASE = database;
    const inventory = JSON.parse(run('psql', ['-X', '-At', '-v', 'ON_ERROR_STOP=1', '-c',
      "SELECT json_build_object('bytes',pg_database_size(current_database()),'tables',(SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'))"]));
    manifest.databases.push({ database, filename, ...inventory });
  }
  env.PGDATABASE = 'postgres';
  const globals = run('pg_dumpall', ['--globals-only']);
  writeFileSync(path.join(target, 'globals.sql'), globals, { flag: 'wx', mode: 0o600 });
  writeFileSync(path.join(target, 'export-manifest.json'), JSON.stringify(manifest, null, 2), { flag: 'wx', mode: 0o600 });
  console.log(JSON.stringify({ status: 'EXPORTED — RESTORE VERIFICATION STILL REQUIRED', ...manifest }, null, 2));
} catch {
  console.error(`Database recovery failed at ${lastOperation}. Raw credentials/data/errors withheld.`);
  process.exitCode = 1;
} finally {
  if (permitted) {
    try {
      const removed = railway(['api', `mutation { deploymentRemove(id:"${deploymentId}") }`, '--compact']);
      if (!removed.data?.deploymentRemove) throw new Error('Stop not acknowledged.');
      console.log('Source PostgreSQL stop acknowledged; existing volume retained. Confirm zero active deployments.');
    } catch {
      console.error('Source stop could not be confirmed; stop this PostgreSQL deployment immediately.');
      process.exitCode = 1;
    }
  }
}
