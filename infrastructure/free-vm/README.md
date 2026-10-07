# Zero-cost VM deployment candidate

This is a migration candidate, **not a deployed or release-verified stack**.
Use only an eligible Oracle Always Free tenancy/resource in its home region.
No paid upgrade, PAYG account, trial-only machine or paid add-on is permitted.
See `docs/ZERO_COST_MIGRATION.md` for current evidence and cutover gates.

The existing Go/Keycloak/PostgreSQL architecture is retained. PostgreSQL runs
on the VM because continuous notification-worker polling exceeds Neon Free's
monthly compute allowance. Two private database services keep identity and
application data separate. SeaweedFS retains authenticated S3-compatible
multipart evidence storage; its internal ports are not published.

## Before starting

1. Verify the actual account limits and availability; allow at most 2 OCPUs,
   12 GB RAM and 200 GB total home-region boot/block volumes. Existing tenancy
   resources count against those limits. Do not use paid capacity as a fallback.
2. Verify current backups of **both** production databases, a realm export and
   storage inventory. Restore them in isolation first. A catalog import or old
   application dump is not a replacement for current users/Keycloak credentials.
3. Provision an eligible Ubuntu ARM VM with firewall rules limited to SSH from
   the operator's approved IP and public HTTP/HTTPS. Do not expose database,
   storage administration or Keycloak management ports. Install Docker/Compose.
4. Set explicit approved API/auth/evidence/web DNS hostnames pointing to the
   replacement. Supply them to Compose outside Git. Do not guess Client domains.
5. Place mode-0600 configuration files in `/etc/fitcalgary`, directory mode 0700:
   `application-db.env`, `identity-db.env`, `storage.env`, `keycloak.env`, `api.env`.
   Database files contain POSTGRES_USER/PASSWORD/DB. Keycloak contains its DB
   credentials. API contains the new private DATABASE_URL, existing device-token
   encryption key, audience and storage credentials. Storage contains matching
   AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY. Preserve existing encryption keys.

## Restore before serving traffic

From the repository root, validate with approved host configuration:

```sh
docker compose --env-file /etc/fitcalgary/hosts.env \
  -f infrastructure/free-vm/compose.yml config --quiet
docker compose --env-file /etc/fitcalgary/hosts.env \
  -f infrastructure/free-vm/compose.yml up -d application-db identity-db storage
```

Restore verified dumps into these **new isolated** databases using compatible
PostgreSQL 18 tools. The templates do not import a fresh realm or create users
in place of the original identity data. Never run a clean/restore against Railway.
Railway's recorded database images are PostgreSQL 18; verify server versions and
extensions from current exports before choosing a different major version.

Create the private bucket using `services/api-go/cmd/storage-configure` with the
new configuration. For existing objects, copy and compare key, size and checksum
before proceeding. Keep source copies intact. Do not run `dev-seed`.

Only after restore and configuration checks, start the application profile:

```sh
docker compose --env-file /etc/fitcalgary/hosts.env \
  -f infrastructure/free-vm/compose.yml --profile application up -d --build
```

Build and pin immutable image digests after staging verification. The tags here
are candidates, not claims that they have been pulled/tested on an ARM VM.

## HTTPS and startup order

Caddy obtains certificates only after correct public DNS/firewall configuration.
Keycloak must expose valid discovery before the API's startup verification can
pass. Storage initialization must complete too. Check `/health`, `/ready` and
OIDC discovery, then authenticated workflows; restart only the replacement API
if necessary. Keep host credentials/secrets out of terminal output.

## Backups and rollback

Keep encrypted logical exports on a separate operator-controlled destination,
not solely on the same VM. Oracle allows five volume backups within the free
allocation; these do not replace verified database restores. Budget all retained
evidence and logs against disk limits. Free-tier failure must stop operations,
not trigger automatic purchases. Do not artificially generate traffic to evade
Oracle's idle-reclamation policy.

Before cutover, Railway remains the source of truth. Use a maintenance window
to quiesce writes, take final dumps, restore and compare all counts/constraints,
then update endpoints. After new writes, rolling back needs a verified reverse
data sync or a fresh export/restore; restoring an old backup would lose data.
Never use `docker compose down -v` on production volumes.
