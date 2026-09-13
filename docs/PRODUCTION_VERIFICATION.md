# Production verification record

## Current state

The FitCalgary V1 source, approved catalog import, release configuration and
platform build artifacts are prepared. Local verification covers the Flutter
client, Go services, PostgreSQL migrations, responsive web/admin routes, iOS and
watchOS simulators, and the Android emulator.

## Publishing boundary

The public website and mobile stores are not represented as production-verified
until a hosting account, production service credentials, signing accounts and
physical devices are connected. The Client's final `fitcalgary` / `fitalberta`
domain can then be attached without rebuilding the application.

## Verification to record after access is supplied

- HTTPS website and API health/readiness checks on the selected host.
- PostgreSQL migration, backup and restore against the managed database.
- Keycloak realm, SMTP, Google and Apple broker configuration.
- Private storage and retention checks with production bucket credentials.
- APNs and FCM notification delivery checks.
- Signed iOS archive upload validation and signed Android AAB upload validation.
- Physical-device smoke, privacy, deep-link and notification checks.
- Store metadata, privacy declarations and review submission status.

No Client credentials or production secrets are stored in Git.
