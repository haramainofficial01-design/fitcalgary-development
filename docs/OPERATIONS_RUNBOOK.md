# Operations runbook

## Health and startup

- `GET /health` reports process health.
- `GET /ready` reports database readiness.
- API startup fails clearly when required configuration, OIDC discovery, storage,
  migrations, or the production data-origin guard cannot be established.
- The server uses bounded request/read/write/idle timeouts and graceful shutdown.

## Routine deployment

1. Confirm the release commit and configuration version.
2. Verify a current encrypted database backup.
3. Apply migrations with `go run ./cmd/migrate` or the release job.
4. Deploy the immutable API image, then check `/health` and `/ready`.
5. Confirm the web BFF can establish and refresh a session against the configured
   Keycloak issuer.
6. Verify one public catalog request, one authenticated request, and one admin
   request from an authorized operator.

## Logs and incidents

The Go service emits JSON structured logs with request context. Never log access
tokens, refresh tokens, cookies, private evidence URLs, upload contents, or secret
values. Storage, notification, migration, and retention failures include a safe
operation message and remain retryable where designed.

For an incident: preserve the relevant request ID and timestamp, check `/ready`,
database/provider health, queue retries and recent deploys, then roll back the
application image if the fault is code-only. Rotate credentials through the secret
manager if exposure is suspected.

## Data and evidence care

Evidence objects remain private and are removed by the retention worker after the
configured window while approved result records remain. Do not delete storage
objects manually without checking submission/result metadata and an approved
retention or incident procedure.
