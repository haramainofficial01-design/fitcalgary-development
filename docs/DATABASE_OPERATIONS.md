# Database operations

## Migration sequence

1. Provision an empty PostgreSQL database and a least-privilege application role.
2. Take a provider snapshot or `pg_dump` backup before schema changes.
3. From `services/api-go`, set `DATABASE_URL` and run `go run ./cmd/migrate`.
   The migrator applies ordered `services/api/migrations/0001` through `0008`,
   records checksums in `schema_migrations`, and serializes concurrent runs.
4. Start the API and verify `/health` and `/ready`.

The API repeats the migration check at startup. A changed checksum fails closed;
migrations are additive and must not be edited after application.

## Approved catalog import

Use a clean database (or an approved-content database with a verified backup),
then from `services/api-go` run:

```sh
CLIENT_DATA_IMPORT=true DATABASE_URL="$DATABASE_URL" go run ./cmd/client-data-import
```

The importer reads `data/client-approved`, preserves raw source payloads and
verification metadata, archives the prior published catalog transactionally,
and writes a `client_data_batch` marker. The supplied source counts are 273 gyms,
743 clubs, and 531 competitions. Repeating the import is safe for the same source
set; never use the development `dev-seed` command for production data.

## Backup and restore

Use the managed provider’s encrypted daily backups and point-in-time recovery.
For an operator-held export, use a restricted destination:

```sh
pg_dump --format=custom --file=fitcalgary-<timestamp>.dump "$DATABASE_URL"
pg_restore --clean --if-exists --dbname="$RESTORE_DATABASE_URL" fitcalgary-<timestamp>.dump
```

Restore into a separate database first, apply/verify migrations, run integrity
checks and only then switch the application connection. Keep backups encrypted,
access-controlled and outside the repository.

## Safe deployment order

Back up → apply migrations → import approved data if required → deploy the API →
verify readiness and protected routes → deploy web/mobile builds. Roll back the
application image first for code-only failures; use a database restore only for a
confirmed data incident and record the incident before destructive recovery.
