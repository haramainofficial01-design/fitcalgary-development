# V1 handoff

The delivered source is organized as one maintainable FitCalgary codebase:
Flutter mobile/web clients, the web/admin surface, Go services, PostgreSQL
migrations, Keycloak configuration, private-storage adapter, watchOS companion,
shared contracts, approved catalog data, tests and operations documentation.

Before deployment, the operator should follow `PRODUCTION_CONFIGURATION.md`,
`DATABASE_OPERATIONS.md` and `OPERATIONS_RUNBOOK.md`, supply the external inputs
listed in `EXTERNAL_DEPENDENCIES.md`, and complete the release matrix. Secrets,
signing material, private evidence and production credentials must remain in the
appropriate platform secret manager rather than this repository.

The final source snapshot has been prepared as a clean one-commit candidate in
the local release workspace for inspection. It is intentionally not pushed to the
Client repository while hosting, provider credentials, signing accounts, physical
devices and store inputs remain external. The candidate contains no review media,
simulator artifacts, internal phase-history files, private development references
or secrets. A final transfer can be produced from the same source once those
external release inputs and the corresponding verification are complete.
