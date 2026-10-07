# Zero-cost production migration

## Current result

**Database recovery verified. Production migration not complete.**
No paid subscription, payment method, upgrade or purchased resource was used.
The Client repository was not modified. Existing mobile and public web endpoints
were not changed to an unverified replacement.

### Local deployment rehearsal

- Installed a free local Colima/Docker runtime in a dedicated `fitcalgary` ARM
  profile; no cloud resource or paid service was created.
- Restored the two current verified dumps into fresh, private PostgreSQL 18
  containers. Catalog/profile/user/credential counts match; no unvalidated
  constraints were found. Source databases/volumes were not accessed or changed.
- Keycloak 26.3 successfully exported the restored `fitcalgary` realm. The full
  export contains sensitive identity/configuration data and is mode-0600 in
  protected operator storage outside Git. Mobile public client, S256 PKCE and
  `ca.fitcalgary.index:/oauthredirect` are preserved. Verification remains enabled.
- Recovered realm confirms **empty SMTP**, **Google disabled without client ID
  or secret**, and **no Apple broker**. These are actual recovered configuration
  findings, not completed live authentication tests.
- Corrected a migration template mismatch: the recovered identity database is
  named `railway`, not `keycloak`. Compose now requires its name explicitly.
  Raw service env files preserve existing `$`/quoted secrets without interpolation.
- Actual Compose configuration validates private ports, raw env files and the
  recovered DB binding. Caddy 2.10.2 configuration validates; no public TLS
  certificate/DNS deployment is claimed from that local syntax check.
- Go production container and optimized Keycloak container build successfully
  for ARM. Added a restricted `.dockerignore`: build context is about 557 KB,
  excluding private Git history, local tooling, credentials and platform caches.
- SeaweedFS 4.45 ARM container verifies a real 7 MiB multipart upload, exact
  bytes, unsigned/tampered rejection, range playback and deletion. Fixed the
  bucket CORS command to respect path-style addressing; actual configured CORS
  is read back successfully. Production storage is not yet deployed.
- Website production bindings now require explicit HTTPS endpoints, API version,
  preserved realm and client. Missing configuration fails instead of silently
  embedding old Railway URLs. Five new deployment tests, ten auth tests, lint,
  TypeScript and full web build pass. No live bindings were changed.
- Fresh headless Chrome checks: eight live mobile-width routes return 200 without
  horizontal overflow or raw developer errors. Catalog routes show safe outage
  states while the backend is stopped; this is not working live catalog proof.
  Anonymous admin shows the sign-in-required screen, not admin authorization PASS.
  Anonymous protected web admin/profile API requests return 401. Public gym API
  proxy currently returns 404 with the source backend stopped.
- Rehearsal containers/networks and their newly created temporary DB volume were
  removed after verification. The original dumps/encrypted copies remain intact.
  Initial local bind-mount attempts failed; named-volume rehearsal resolved it.
  A browser check first lacked its local Playwright dependency; rerunning with
  the installed workspace runtime completed the checks above.

Railway initially reported HOBBY with no active subscription, no payment method,
zero purchased credit and an unused Free allowance. Its explicit Free-only
subscription operation succeeded. The workspace now reports **FREE**, an active
Free subscription, no payment method and approximately **$0.99987 included usage
remaining** at the post-export check. This is included service credit, not cash
paid. Railway documents Free at $0/month with $1/month included usage.

Only the existing PostgreSQL services were deliberately deployed, sequentially,
using their existing PostgreSQL 18 image, PGDATA and attached volumes. Free
activation briefly showed an automatically resumed API deployment; stop was
requested immediately and subsequent checks found no active application workload.
No migrations, seeders, imports, account deletions or volume replacement occurred.
All four Railway services now have zero active deployments. Temporary database
TCP proxies created solely for export were removed afterward. Both original
volume IDs remain attached, READY, not pending deletion, with deletedAt null.

## Recovered source and verification

| Source | Physical used / allocation | Current logical DB size | Restore evidence |
|---|---:|---:|---|
| Application PostgreSQL | 124.05 MB / 500 MB | 16,004,799 bytes | 35 tables; 273 gyms, 743 clubs, 531 competitions; 1 profile; 0 results, submissions or submission reviews |
| Identity PostgreSQL | 121.94 MB / 500 MB | 13,661,887 bytes | 88 tables; 2 realms, 4 users, 4 credentials, 16 clients, 1 identity provider; 0 federated identities |

Both sources report PostgreSQL **18.6**. Every non-template database and cluster
globals was exported. The default postgres database has no public tables in
either service. Both nonempty dumps were restored into new, socket-only local
PostgreSQL 18 clusters using pg_restore with exit-on-error. Those temporary
clusters were stopped afterward. Restores use no-owner/no-acl for isolated
verification; preserved globals/configuration are needed for production roles.

Dump SHA-256:

- Application: `32843b0e5d10902806234db4cf2d4625df98cc930857a621736664ecd00be57b`
- Identity: `f719a4b15c2b7a938c3a465257339dc8152a5f8f2c231cbee4ddfc025f3928f4`

Backups, globals, configuration and encryption keys are outside Git, in protected
operator storage. Each database export has two AES-256-GCM encrypted local copies;
decryption equals the original and encrypted copy checksums match. The key is
stored separately from the backup directory, mode 0600. **Both copies are on the
same Mac, not an off-device disaster-recovery backup.** Move a verified encrypted
copy and independently protected recovery key to an approved free destination.
An encrypted configuration snapshot exists before and after recovery.

Before recovery, the newest existing application dump was September 24. It
restored all 1,547 catalog records and one profile, but contained no Keycloak
identity data. The September 23 local stabilization clone has matching aggregate
catalog/profile counts and no results/submissions; it is historical, not the
authority for later writes. Migration-test databases are disposable fixtures.
The newly recovered databases, not those test copies, are the migration source.

### Reproducible versus production-only data

- Approved catalog: reproducible from `data/client-approved`; count alone does
  not certify the current accuracy of every price, event date or link.
- Application state: current recovered profile and all other tables are retained
  in the current application dump. Results/submissions/reviews were empty at export.
- Identity state: users, credentials, realm signing/configuration, clients and
  provider configuration must come from the recovered identity DB, not a fresh
  realm import. Secret values must never appear in logs or Git.
- Private evidence: Railway's actual bucket inventory reported zero objects and
  zero bytes. Recheck immediately before final cutover in case new writes resume.
- No known production-only database data remains unexported in these two services.
  This does not verify SMTP, social login, real-device sessions or unseen services.

## Free provider assessment

| Candidate | Documented allowance / constraint | FitCalgary decision |
|---|---|---|
| Cloudflare Workers Free | 100,000 dynamic requests/day; 10 ms CPU/request; 128 MB memory; static assets free | Retain current SSR/auth-capable Worker if account billing and runtime fit are confirmed. A static Pages export would remove server authentication/admin behavior. Pages Functions share Workers limits. |
| Cloudflare Pages Free | 500 builds/month; functions subject to Workers limits | Static hosting alone is insufficient for the existing web application. Do not rewrite working auth merely to switch product names. |
| Neon Free | Current pricing docs: 1 GB/project, 100 CU-hours/project/month, 5 GB transfer; suspend after inactivity | Storage fits easily, but existing 5-second notification-worker DB polling prevents normal suspension. At 0.25 CU continuously, 30 days uses 180 CU-hours, above 100. Do not disable product notifications to meet a free quota. Confirm console quotas if reconsidered. |
| Oracle Always Free | Current published A1 allowance: 2 OCPUs / 12 GB, 200 GB combined boot/block, 5 volume backups; home-region capacity; possible idle reclamation | Candidate for Go, Keycloak, both PostgreSQL DBs and authenticated private S3-compatible storage. Account and available Always Free capacity still unverified. No PAYG, trial-only resources or paid fallback. |

The Oracle candidate retains the real Go/Keycloak/PostgreSQL architecture.
Private SeaweedFS provides the current S3/multipart interface behind HTTPS rather
than introducing a potentially billable object-storage account. See
`infrastructure/free-vm/README.md`. Individual ARM containers and configuration
have passed the local checks above; the combined stack has **not** been deployed
to Oracle, exercised through public HTTPS or production-auth verified.

Historical Railway RAM measurements: Keycloak approximately 880 MB, Go 22 MB,
application DB 54 MB, identity DB 48 MB. These sampled historical figures do not
establish peak load, request volume, production performance or future free-tier fit.
They demonstrate why Keycloak does not fit Railway Free's 512 MB per-service limit.

Cloudflare currently serves the public website. Its billing API rejected the
available token's subscription query. The Worker's usage_model `standard` is not
proof of a Free account. Confirm the dashboard plan and dynamic request/CPU metrics
before claiming the complete hosting bill is $0. Do not activate Workers Paid/R2.

## Cost, retention and cutover gates

- Railway recovery cash cost: **$0**; Free and no card confirmed; exports finished.
  Both 500 MB volumes fit the published per-volume 0.5 GB limit. A 30-minute
  maximum-resource single-DB export would consume roughly $0.0174 compute plus
  small transfer/storage, inside the included $1; actual recorded credit use was
  substantially lower. Persisted volumes continue consuming included usage.
- Replacement expected cash cost: **$0 only if actual accounts/resources stay
  inside confirmed Free/Always Free limits**. No capacity/reliability guarantee.
- Oracle signup requires identity/card verification and may place a temporary
  authorization hold; the user approved verification, not paid upgrades/charges.
- Railway documents Free/Trial volume removal 30 days after expiry, versus Hobby
  60 days after cancellation. No exact expiry/deletion date was returned for these
  volumes; now Free is active and neither is pending deletion. Do not invent a
  calendar deadline from the earlier inconsistent trial-days counter.
- Keep Railway project/volumes intact. They were already stopped before recovery;
  only export workloads were stopped again. No replacement cutover has occurred.

Required external actions:

1. Complete Oracle Free account sign-in/verification; inspect home-region capacity
   and existing tenancy usage before any resource is created.
2. Confirm approved FitCalgary API/auth/evidence DNS hostnames and DNS access.
   Do not alter HBIC or guess a sending domain.
3. Confirm Cloudflare Free plan/metrics using account access that can read billing.
4. Authorize/verify a FitCalgary email sending domain, dedicated Google OAuth
   project/configuration and Apple Services ID/return URL/key. Real inbox receipt
   and real iPhone Apple login remain mandatory acceptance evidence.
5. Approve the existing genuine native iOS glass preview before publication;
   complete physical-device, final authenticated regression and store update gates.

The final Client domain need not block staging: after an actual eligible VM IP
exists, temporary IP-based hostnames from nip.io/sslip.io can be evaluated with
Caddy HTTP-01 TLS. The service documents IP resolution and individual HTTPS
certificates. No such hostname has been assigned or tested for FitCalgary yet.
This is a third-party DNS dependency, not a domain owned by the Client, and does
not establish sending-domain ownership or satisfy provider domain verification.
Do not invent a final production domain or bypass Google/Apple verification.

Then provision only confirmed Always Free resources, restore both current DBs in
isolation, preserve encryption keys, configure HTTPS/storage/OIDC callbacks and
web sessions, and test the actual product before updating endpoints. Preserve
`ca.fitcalgary.index`, `ca.fitcalgary.index.watchkitapp`, `fitcalgary-mobile` and
`ca.fitcalgary.index:/oauthredirect`. Changing baked-in API/issuer addresses will
require replacement mobile builds. Existing Railway-address binaries cannot be
called migrated merely because another server is online.

## Current URLs and rollback

- Web: `https://fitcalgary-web.fitcalgary.workers.dev` responds HTTP 200.
- Old API health: `https://fitcalgary-api-production.up.railway.app/health`
  responds HTTP 404.
- Old issuer discovery:
  `https://fitcalgary-auth-production.up.railway.app/realms/fitcalgary/.well-known/openid-configuration`
  responds HTTP 404.
- Replacement URLs: **not provisioned**. Live registration, password reset,
  social login, admin sessions and end-to-end browsing remain unverified/unavailable
  while API/auth are stopped. A web HTTP 200 is not complete-product availability.

Original volumes/configuration and verified dumps provide the rollback source.
Free Railway cannot run the full original Keycloak stack reliably within its RAM
allowance; restarting the entire source stack is not an authorized $0 rollback.
Before new production writes, restore the verified copies to eligible free
infrastructure. After cutover writes, rollback needs a verified reverse sync or
fresh dump/restore, not an older snapshot that would discard those writes.

## Sources and operational tools

Executed checks for this increment:

- Both current database restore verifications: PASS; aggregate counts above.
- Two encrypted-copy round trips/checksum comparisons per export: PASS.
- Configuration snapshot encryption/decryption before and after recovery: PASS.
- All four operational script syntax checks and invalid-input preflight rejection:
  PASS. Negative preflight checks do not access or mutate the source provider.
- VM YAML/private-port/persistent-volume/staged-profile assertions: PASS.
  Local ARM image pulls/builds, restore/realm export and private storage: PASS in
  the later rehearsal above. Public HTTPS and replacement deployment: NOT TESTED.
- Final Railway status: zero active deployments, original volumes READY;
  temporary TCP proxy lists empty. No account or user deletion performed.
- Recovery itself changed no application source. The later rehearsal changes
  web deployment configuration and the Go operational storage-CORS command;
  their affected checks were rerun. Unchanged Flutter suites were not repeated.
  Earlier application evidence is not live authenticated verification.

- [Railway plans](https://docs.railway.com/pricing/plans)
- [Railway trial](https://docs.railway.com/pricing/free-trial)
- [Railway volumes](https://docs.railway.com/volumes)
- [Cloudflare Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/)
- [Cloudflare Pages limits](https://developers.cloudflare.com/pages/platform/limits/)
- [Neon plans](https://neon.com/docs/introduction/plans)
- [Oracle Always Free](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
- [Temporary IP-based DNS and HTTPS](https://nip.io/)

`snapshot_migration_config.mjs` reads and encrypts configuration outside Git.
`export_railway_database.mjs` requires an already-running original Free-only
PostgreSQL service and stops only that source deployment after export; it does
not activate paid plans or restore into production.
`verify_migration_backup.mjs` restores only to an isolated socket-only local
cluster. `protect_migration_backup.mjs` verifies two encrypted local copies.
