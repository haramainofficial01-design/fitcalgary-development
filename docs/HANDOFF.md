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

The final source snapshot can be exported as a clean one-commit handoff when the
remaining external release inputs and final verification are complete.
