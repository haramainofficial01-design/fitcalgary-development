# Development fixtures and Client data

Client-approved gym, club and competition source datasets are maintained under
`data/client-approved` and imported through the validated catalogue importer.
Development records remain isolated from approved content and never constitute
production verification.

## Enforced boundary

- Synthetic directory records live only in `services/api-go/cmd/dev-seed/fixtures`.
  They are embedded in the separate opt-in `dev-seed` executable, not `cmd/api`.
  The production image builds only `cmd/api` and copies schema migrations.
- Loading requires `APP_ENV=development` or `test`, `DEMO_DATA=true`, one literal
  loopback database address and a database name ending `_development` or `_test`.
  Use `sslmode=disable` only for this loopback-only development database.
- The loader refuses existing account/catalogue records. It records a batch marker
  in the same transaction as the records; repeat loading of that batch is a no-op.
- Production startup rejects an enabled/invalid `DEMO_DATA` value and any database
  with the `development_fixture_batch` marker. A failed origin check prevents startup.
  This is a deployment safeguard, not protection against a database owner removing
  markers. Never remove the marker to promote a development database.
- Fixture names explicitly say `Development Fixture`; descriptions identify synthetic
  records and source URLs use `.invalid`. No real businesses, athletes or verified
  results are invented. Current fixtures leave leaderboards empty.

## Real model, not a parallel placeholder implementation

Fixtures use the same schema, foreign keys, publication states, public handlers and
pricing normalizer as ordinary records. Missing prices remain unknown, not fabricated
zero-cost offers. APIs, admin operations, filters, comparisons and workflows must
continue to use persisted production-model records, with no fallback hard-coded lists
in application logic. New fixture scenarios belong in the gated fixture command or
test files, never production migrations or client presentation code.

The existing initial migration includes reference disciplines, divisions and evidence
checklists. These are provisional configuration, not Client-approved competition
rules. Preserve migration checksums; future configuration/import work must apply
approved rules through supported updates rather than rewriting migration history.

## Local use

Create a new, empty local database named, for example, `fitcalgary_development`.
From `services/api-go`, supply the connection through the environment:

```sh
APP_ENV=development DEMO_DATA=true go run ./cmd/dev-seed
```

`DATABASE_URL` is required; use a literal `127.0.0.1` or `::1` host. The command
applies the authoritative migrations before loading. `MIGRATIONS_DIR` may override
the default `../api/migrations`. Do not put credentials in source or shell history.

## Approved-data operation

Use a separate clean database for approved content, with normal schema migrations
and `DEMO_DATA=false`. Preserve source attribution, verification dates and approval
records. Import through validated administrative/service paths and publish only
approved records. The importer reads the approved JSON datasets without embedding
their records in application logic.

Do not migrate fixtures into the Client dataset or simply relabel them as approved.
Replacing development data must require no changes to product rendering or business
logic. Credentials and any outstanding ranking or verification decisions remain
external inputs until supplied and approved.

## Verification

`go test ./...`, `go vet ./...` and `go build ./cmd/api` cover the implementation.
The real PostgreSQL integration test requires a disposable empty local database:

```sh
FIXTURE_TEST_DATABASE_URL="$DATABASE_URL" go test ./cmd/dev-seed -v -count=1
```

Without that variable, the database integration test explicitly skips. Use a fresh
database on each test run. It tests migrations, existing-data refusal, batch
idempotency, the production guard, normalized/incomplete pricing, actual public
directory responses, search/category filtering and empty leaderboards.
