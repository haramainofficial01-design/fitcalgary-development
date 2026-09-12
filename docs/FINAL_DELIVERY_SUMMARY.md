# FitCalgary V1 final delivery summary

## Complete + verified

- Flutter/Dart consumer application for iOS, Android and web, plus the native
  watchOS companion.
- Go API and worker services with PostgreSQL migrations, protected storage,
  Keycloak OIDC/PKCE integration, role/ownership authorization, submissions,
  judge review, rankings, inbox notifications and administration.
- Client-approved source catalog: 273 gyms, 743 clubs and 531 competitions.
- Automated source tests, migration/import checks, web checks, platform build
  paths and security boundaries are documented and rerun at the final checkpoint.

## Complete + ready but externally blocked

- Production environment templates, fail-closed configuration validation,
  deployment sequence, backup/restore procedure, and release matrix.
- iOS and Android release projects, watchOS release project, store identity and
  privacy material within Developer control.

## Client action required

Provide the production hosting/domain, managed database/storage, Keycloak realm,
SMTP, Google/Apple, Firebase/APNs, Apple/Google store accounts and signing keys;
approve final legal/business copy; and provide representative physical devices for
hardware QA. Exact items are listed in `EXTERNAL_DEPENDENCIES.md`.
