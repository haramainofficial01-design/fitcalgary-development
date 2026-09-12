# Phase 3 execution status

## Operating record

- **Scope:** Original FitCalgary V1 only. The separate future community-product
  discussion is out of scope and must not alter this release.
- **Private baseline:** `601587558c65fd5be31cf25d3989fbdae911dfba` on `main`.
- **Current worktree:** Carries the intentional final-handoff sanitation changes
  from the prior delivery pass. They remain part of the Phase 3 working baseline
  and are not a product rollback.
- **Approved source catalog:** 273 gyms, 743 clubs, 531 competitions (1,547 total
  source records). The club dataset is stored under the `clubs` property; the gym
  and competition datasets are arrays.
- **Status vocabulary:** `NOT_STARTED`, `IN_PROGRESS`, `PASS`,
  `BLOCKED_EXTERNAL`, `BLOCKED_ENVIRONMENT`, `NOT_APPLICABLE`.

## Acceptance matrix

| # | Area | Status | Evidence / next action |
|---|---|---|---|
| 01 | Production configuration | PASS | Fail-closed Go production validation and Flutter release configuration are implemented and tested; live values remain external. |
| 02 | Environment and secrets handling | PASS | `.env.example` is placeholder-only, environment files are ignored, tracked-source secret scan is clean, and release gates reject unsafe endpoints. |
| 03 | Database and migrations | PASS | Fresh PostgreSQL 17.11 database initialized and migrations applied; 35 public tables present. |
| 04 | Approved Client data integrity | PASS | Clean import and repeat import verified at 273 gyms, 743 clubs, 531 events, 1,547 provenance records with the approved batch marker. |
| 05 | Authentication | PASS | Keycloak OIDC/PKCE/session foundation and auth tests pass; live realm/SMTP/social credentials remain BLOCKED_EXTERNAL. |
| 06 | Authorization and roles | PASS | Server-side role, ownership, stale-token revocation, restore and self-escalation regression passed against PostgreSQL. |
| 07 | Account lifecycle | PASS | Account/profile/session/logout paths are covered by Flutter, Go and integration tests; live email delivery remains BLOCKED_EXTERNAL. |
| 08 | Gym directory | PASS | Approved catalog search, filters, detail, pagination and saved-gym isolation passed against PostgreSQL. |
| 09 | Pricing and comparison | PASS | Normalized recurring/first-year pricing, incomplete-price handling and admin price validation passed. |
| 10 | Clubs | PASS | Approved catalog, public publication/detail/search and protected management flows passed. |
| 11 | Events and competitions | PASS | Dates, phases, cancellation, registration state, detail/search and protected management flows passed. |
| 12 | Leaderboards | PASS | Official/community separation, configurable boards, ranking direction, best-result and privacy behavior passed. |
| 13 | Athlete profiles | PASS | Profile persistence, affiliations, privacy and performance presentation passed. |
| 14 | Result submission | PASS | Submission validation, ownership and lifecycle paths passed. |
| 15 | Private evidence | PASS | Protected multipart upload, scoped playback, finalize and retention adapter paths passed with mocked external storage. |
| 16 | Judge review | PASS | Judge queue, evidence access, checklist validation, decisions and comments passed. |
| 17 | Correction and resubmission | PASS | Change-request, single-child and cancelled-submission rules passed. |
| 18 | Approval and ranking | PASS | Approval idempotency, verified-result creation, correct board placement and best-result behavior passed. |
| 19 | Notifications | PASS | Inbox/read state, outbox idempotency, preference handling and queue paths passed; provider delivery remains BLOCKED_EXTERNAL. |
| 20 | Preferences | PASS | Preference merge, defaults and invalid-key rejection passed. |
| 21 | Admin dashboard | PASS | Protected admin web route and representative content/reference/moderation operations passed. |
| 22 | Moderation and audit visibility | PASS | Moderation boundaries, account restrictions, audit history and rollback behavior passed. |
| 23 | Web responsiveness and accessibility | PASS | Lint, type check, production build, route inventory and client accessibility-focused tests pass. |
| 24 | iOS | PASS | Simulator build/launch and unsigned release archive pass; signing, physical device and store verification are BLOCKED_EXTERNAL. |
| 25 | Android | PASS | Emulator debug build/launch and release AAB build pass; production signing, physical device and Play verification are BLOCKED_EXTERNAL. |
| 26 | Apple Watch | PASS | watchOS simulator build/install/launch pass; signing, hardware and store verification are BLOCKED_EXTERNAL. |
| 27 | Deep links | PASS | Supported web/app route inventory and notification-link allow-list tests pass. |
| 28 | Error/loading/empty states | PASS | Flutter widget coverage and web/API structured-error paths pass. |
| 29 | Security | PASS | Authorization, validation, private storage, safe errors, release gates and tracked-source scans pass. |
| 30 | Performance and reliability | PASS | Request timeouts, pagination/limits, idempotent queues, migration checks and graceful failure paths are covered. |
| 31 | Backups and operations | PASS | Backup/restore, migration, deployment and rollback runbooks are documented. |
| 32 | Logging and health checks | PASS | `/health`, `/ready`, structured safe logging and operational failure signals are documented and covered. |
| 33 | Release builds | PASS | Web, Go, Android AAB, iOS simulator/archive, and watchOS simulator builds pass locally. |
| 34 | Store readiness | BLOCKED_EXTERNAL | Technical project metadata is present; Apple/Google accounts, signing, store assets and review submission remain external. |
| 35 | Deployment readiness | BLOCKED_EXTERNAL | Environment-driven deployment is documented; hosting, DNS/TLS, managed DB/storage and production credentials remain external. |
| 36 | Documentation | PASS | Production configuration, database operations, operations runbook, release matrix, dependencies, handoff and final summary are present. |
| 37 | Final handoff candidate | PASS | Clean one-commit candidate prepared locally after final verification; its SHA is reported with the release record. Client `main` was not modified. |

## Verified pre-flight

- Private repository, branch, and baseline are recorded above; no private history
  will be transferred during Phase 3 development.
- The Flutter application, iOS, Android, web/admin, watchOS companion, Go API,
  PostgreSQL migrations, contracts, infrastructure, and approved datasets are
  present in source.
- Phase 2 catalog file counts match the supplied expected source counts.

## Current batch

Fresh database/import verification, complete Go/Flutter/web regression, platform
build and simulator/emulator checks, CocoaPods/toolchain validation, release
configuration hardening and tracked-source sanitation are complete. Remaining
work is limited to the clean one-commit candidate plus external production
configuration and deployment inputs.

## Latest verification evidence

- Flutter 3.47.2 / Dart 3.13.2: `flutter analyze` and `flutter test` pass (20 tests).
- Go: `go test ./...`, `go vet ./...`, and stripped API production build pass.
- PostgreSQL 17.11: clean migration/import and repeat-import checks pass; 35 tables,
  273 gyms, 743 clubs, 531 events and 1,547 source records verified.
- Web: lint, TypeScript, production build, auth tests and admin-content tests pass.
- iOS: simulator build/install/launch and unsigned release archive pass.
- Android: debug APK emulator install/launch and release AAB build pass.
- watchOS: simulator build/install/launch pass.
- Source hygiene: `git diff --check` and tracked secret/internal-tool scans pass;
  `.env` files remain ignored and no production values are committed.
- Handoff hygiene: clean candidate tree contains 387 tracked files, exactly one
  reachable commit, no review media/simulator artifacts, no internal-tool terms,
  no private development references, and no secret material.
