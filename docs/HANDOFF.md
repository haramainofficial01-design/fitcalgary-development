# Source handoff

The delivered source is organized as one maintainable FitCalgary codebase:
Flutter mobile/web clients, the web/admin surface, Go services, PostgreSQL
migrations, Keycloak configuration, private-storage adapter, watchOS companion,
shared contracts, approved catalog data, tests and operations documentation.

Before deployment, the operator should follow `PRODUCTION_CONFIGURATION.md`,
`DATABASE_OPERATIONS.md` and `OPERATIONS_RUNBOOK.md`, supply the external inputs
listed in `EXTERNAL_DEPENDENCIES.md`, and complete the release matrix. Secrets,
signing material, private evidence and production credentials must remain in the
appropriate platform secret manager rather than this repository.

Read `DEPLOYMENT_STATUS.md` for current live-service, provider, device and store
dependencies. Source delivery does not establish public-release readiness.

## Access and operating sequence

Transfer hosting, identity administration, database access, private storage,
email/push accounts, signing and store access through an authorized secure
channel. The Client should control permanent accounts and recovery contacts.

Restore application and identity backups into isolated databases first. Preserve
existing encryption keys and account identifiers. Configure HTTPS endpoints and
Keycloak callbacks, then verify authentication, authorization and private storage.
Build release binaries against the functioning endpoints before store submission.
Record actual platform responses; never infer approval from a successful upload.

## Domain change

Connect the approved Client domain, issue TLS, update origins/CORS, Keycloak
redirect/logout URLs and association files. Confirm Google and Apple broker
domain requirements. Replace mobile builds if packaged API/issuer settings change.
Keep old routes working during transition where possible.

## Recovery

Keep encrypted off-device copies and verify restoration. After new writes,
rollback requires verified synchronization or a current backup; restoring an old
export can lose data. Never delete or reinitialize production volumes.
