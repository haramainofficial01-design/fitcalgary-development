#!/usr/bin/env node
// Local ARM container rehearsal only. No provider or production database writes.
import { execFileSync } from 'node:child_process';
import { randomBytes, createHash } from 'node:crypto';
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync, realpathSync, chmodSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const [applicationDump, identityDump, destination] = process.argv.slice(2);
if ([applicationDump, identityDump, destination].some(p => !p || !path.isAbsolute(p))) {
  throw new Error('Supply two absolute current dump paths and an external evidence directory.');
}
const sourceRoot = realpathSync(path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..'));
mkdirSync(destination, { mode: 0o700, recursive: true });
const output = realpathSync(destination);
if (output === sourceRoot || output.startsWith(`${sourceRoot}${path.sep}`)) throw new Error('Evidence must remain outside source control.');
chmodSync(output, 0o700);
const dumps = [applicationDump, identityDump].map(p => readFileSync(p));
const expected = ['32843b0e5d10902806234db4cf2d4625df98cc930857a621736664ecd00be57b',
  'f719a4b15c2b7a938c3a465257339dc8152a5f8f2c231cbee4ddfc025f3928f4'];
if (dumps.some((b, i) => createHash('sha256').update(b).digest('hex') !== expected[i])) {
  throw new Error('Dump does not match the current verified recovery source.');
}
const prefix = `fitcalgary-rehearsal-${randomBytes(5).toString('hex')}`;
const network = `${prefix}-network`, database = `${prefix}-db`, keycloak = `${prefix}-keycloak`;
const volume = `${prefix}-data`;
// Colima shares the operator home, not macOS's /var/folders temporary directory.
const temporary = mkdtempSync(path.join(output, 'private-runtime-'));
const envFile = path.join(temporary, 'database.env');
writeFileSync(envFile, `POSTGRES_USER=postgres\nPOSTGRES_PASSWORD=${randomBytes(32).toString('hex')}\nPOSTGRES_DB=railway\n`, { mode: 0o600, flag: 'wx' });
let operation, dbStarted = false, kcStarted = false, networkCreated = false, volumeCreated = false;
function docker(args, input) {
  operation = args.slice(0, 2).join(' ');
  return execFileSync('docker', ['--context', 'colima-fitcalgary', ...args], {
    input, timeout: 180000, maxBuffer: 32 * 1024 * 1024, stdio: ['pipe', 'pipe', 'pipe'],
  }).toString();
}
async function ready() {
  for (let attempt = 0; attempt < 30; attempt++) {
    try { docker(['exec', database, 'pg_isready', '-U', 'postgres', '-d', 'railway']); return; }
    catch { await new Promise(resolve => setTimeout(resolve, 500)); }
  }
  throw new Error('Local PostgreSQL did not become ready.');
}
function sql(query, db = 'railway') {
  return docker(['exec', database, 'psql', '-X', '-At', '-U', 'postgres', '-d', db,
    '-v', 'ON_ERROR_STOP=1', '-c', query]).trim();
}
try {
  const arch = docker(['info', '--format', '{{.Architecture}}']).trim();
  if (arch !== 'aarch64' && arch !== 'arm64') throw new Error('Expected isolated local ARM Docker context.');
  docker(['network', 'create', '--internal', network]); networkCreated = true;
  docker(['volume', 'create', volume]); volumeCreated = true;
  docker(['run', '-d', '--name', database, '--network', network, '--env-file', envFile,
    '--mount', `type=volume,src=${volume},dst=/var/lib/postgresql`, 'postgres:18-alpine']);
  dbStarted = true;
  await ready();
  docker(['exec', database, 'createdb', '-U', 'postgres', 'identity']);
  for (const [i, db] of ['railway', 'identity'].entries()) {
    docker(['exec', '-i', database, 'pg_restore', '-U', 'postgres', '--exit-on-error',
      '--no-owner', '--no-acl', '--dbname', db], dumps[i]);
  }
  const catalog = JSON.parse(sql("SELECT json_build_object('gyms',(SELECT count(*) FROM gyms),'clubs',(SELECT count(*) FROM clubs),'events',(SELECT count(*) FROM events),'profiles',(SELECT count(*) FROM profiles),'results',(SELECT count(*) FROM results),'submissions',(SELECT count(*) FROM submissions),'unvalidatedConstraints',(SELECT count(*) FROM pg_constraint WHERE NOT convalidated))"));
  if (catalog.gyms !== 273 || catalog.clubs !== 743 || catalog.events !== 531 || catalog.profiles !== 1 || catalog.unvalidatedConstraints !== 0) {
    throw new Error('Recovered catalog/constraint counts differ.');
  }
  const identities = JSON.parse(sql("SELECT json_build_object('users',(SELECT count(*) FROM user_entity),'credentials',(SELECT count(*) FROM credential),'realms',(SELECT count(*) FROM realm),'clients',(SELECT count(*) FROM client),'unvalidatedConstraints',(SELECT count(*) FROM pg_constraint WHERE NOT convalidated))", 'identity'));
  if (identities.users !== 4 || identities.credentials !== 4 || identities.realms !== 2 || identities.unvalidatedConstraints !== 0) throw new Error('Recovered identity counts differ.');
  const kcEnv = path.join(temporary, 'keycloak.env');
  const password = readFileSync(envFile, 'utf8').split('\n').find(x => x.startsWith('POSTGRES_PASSWORD=')).slice(18);
  writeFileSync(kcEnv, `KC_DB=postgres\nKC_DB_URL=jdbc:postgresql://${database}:5432/identity\nKC_DB_USERNAME=postgres\nKC_DB_PASSWORD=${password}\n`, { mode: 0o600, flag: 'wx' });
  docker(['run', '-d', '--name', keycloak, '--network', network, '--env-file', kcEnv,
    'quay.io/keycloak/keycloak:26.3', 'export', '--realm', 'fitcalgary', '--file', '/tmp/fitcalgary-realm.json']);
  kcStarted = true;
  const exit = docker(['wait', keycloak]).trim();
  if (exit !== '0') throw new Error('Recovered realm could not be exported by Keycloak.');
  const realmFile = path.join(output, 'fitcalgary-realm.private.json');
  docker(['cp', `${keycloak}:/tmp/fitcalgary-realm.json`, realmFile]);
  chmodSync(realmFile, 0o600);
  const realm = JSON.parse(readFileSync(realmFile, 'utf8'));
  const mobile = realm.clients.find(c => c.clientId === 'fitcalgary-mobile');
  if (!mobile?.publicClient || !mobile.redirectUris.includes('ca.fitcalgary.index:/oauthredirect') || mobile.attributes?.['pkce.code.challenge.method'] !== 'S256') {
    throw new Error('Recovered mobile OIDC client/PKCE/redirect does not match expectations.');
  }
  const report = { status: 'LOCAL ARM RESTORE + KEYCLOAK REALM EXPORT VERIFIED', liveProduction: false,
    architecture: arch, catalog, identities, realm: realm.realm, verifyEmail: realm.verifyEmail,
    smtpConfigured: Boolean(realm.smtpServer?.host && realm.smtpServer?.from),
    mobileClient: { id: mobile.clientId, public: mobile.publicClient, pkce: mobile.attributes['pkce.code.challenge.method'], mobileRedirectPreserved: true },
    providers: realm.identityProviders.map(p => ({ alias: p.alias, provider: p.providerId, enabled: p.enabled,
      clientIdPresent: Boolean(p.config?.clientId), clientSecretPresent: Boolean(p.config?.clientSecret) })),
    privateRealmExport: 'Protected operator evidence directory; not source control' };
  writeFileSync(path.join(output, 'rehearsal-verification.json'), JSON.stringify(report, null, 2), { mode: 0o600, flag: 'wx' });
  console.log(JSON.stringify(report, null, 2));
} catch (error) {
  writeFileSync(path.join(output, 'private-failure.log'), Buffer.from(error.stderr ?? error.message ?? ''), { mode: 0o600 });
  for (const [created, name] of [[dbStarted, database], [kcStarted, keycloak]]) {
    if (created) { try { writeFileSync(path.join(output, `${name}-private.log`), docker(['logs', name]), { mode: 0o600 }); } catch {} }
  }
  console.error(`Local container rehearsal failed during ${operation}; raw logs/credentials withheld.`);
  process.exitCode = 1;
} finally {
  // Only the exact fresh rehearsal containers/network are removed. Source volumes are untouched.
  for (const [created, name] of [[kcStarted, keycloak], [dbStarted, database]]) {
    if (created) { try { docker(['rm', '-f', name]); } catch { console.error('Local rehearsal container cleanup requires attention.'); process.exitCode = 1; } }
  }
  if (networkCreated) { try { docker(['network', 'rm', network]); } catch { console.error('Local rehearsal network cleanup requires attention.'); process.exitCode = 1; } }
  if (volumeCreated) { try { docker(['volume', 'rm', volume]); } catch { console.error('Isolated rehearsal volume cleanup requires attention.'); process.exitCode = 1; } }
}
