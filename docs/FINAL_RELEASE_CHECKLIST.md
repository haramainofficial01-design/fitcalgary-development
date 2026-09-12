# Final V1 release gate

V1 must not end as a development-only project. Contractual completion requires the
agreed iOS, Android, responsive website, admin dashboard, Go API, PostgreSQL,
Keycloak authentication, private storage, notifications and watchOS companion to
be production-configured, fully tested and ready for immediate deployment or store
submission within the Developer's control.

## Required completion evidence

- Production builds, signing/configuration, responsive and cross-platform QA,
  release security, reliability/performance and regression checks completed.
- Production hosting, database migrations/backups/recovery, domain/TLS, secrets,
  identity/social/email, storage/retention and notifications configured and verified.
- Client-approved content imported where supplied; fixture loading disabled and
  production data guards verified. No development identities, tokens or synthetic
  content passed off as production readiness.
- iOS/Android store metadata, privacy disclosures, assets, entitlements and uploads
  prepared; watchOS companion/configuration/assets included where applicable.
- Physical-device tests and production-service checks recorded separately from
  simulator/emulator/local tests. Store approval is never assumed.
- Source/configuration templates, deployment/recovery documentation and contractual
  ownership/access handoff prepared with no secrets in Git.

## Classification rule

Ordinary implementation, build, configuration and QA defects remain unfinished
Developer work and must be resolved before completion. They are NOT external
blockers simply because they are still outstanding.

For every genuine external dependency preventing deployment/submission, record
`BLOCKED_EXTERNAL` and the exact missing credential, production account, approved
content/data, hardware/platform dependency or third-party approval. Identify the
responsible party, affected release action, existing implementation/test evidence
and the verification needed once supplied. Do not expose secret values.

Use `IMPLEMENTED`, `CONFIGURED`, `TESTED`, `DEVICE_VERIFIED` and
`PRODUCTION_VERIFIED` only with corresponding evidence. Final release readiness
cannot be inferred from a successful development build or a calendar deadline.
