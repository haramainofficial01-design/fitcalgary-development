# Phase 3 execution status

## Current production-stabilization override

The historical milestone matrix below is not a current production acceptance.
Use `docs/PRODUCTION_STABILIZATION_AUDIT.md` for active defects and executed evidence.
The private baseline `bf7bd93` is preserved; `7c3de27` adds verified submission
recovery. Subsequent account/content/layout checks pass 57 Flutter tests and
analysis, debug Android build, iOS simulator build and primary navigation checks.
Normal applications are restored after integration harnesses where recorded.

Current hosting check: web responds HTTP 200, while the API health and OIDC
discovery endpoints return HTTP 404. Earlier live checks are historical:

- Website: https://fitcalgary-web.fitcalgary.workers.dev
- API: https://fitcalgary-api-production.up.railway.app/api/v1
- Issuer: https://fitcalgary-auth-production.up.railway.app/realms/fitcalgary

Public-browser checks and anonymous authorization boundaries do **not** prove
authenticated production workflows. SMTP/verified sending domain, dedicated
Google OAuth setup, Apple broker configuration and physical verification remain
BLOCKED_EXTERNAL. Unrelated HBIC configuration is out of scope. Store binaries
do not contain all private stabilization fixes. An opt-in native UIKit glass
navigation preview passes real-control Xcode tests on iPhone and iPad simulators;
light/dark captures were inspected. The user approved this appearance; supported
iOS builds now enable it by default, with the existing platform/capability fallback.
Final native phone material verification,
full authenticated regression and final release/design QA remain IN_PROGRESS.
No current final Client handoff or safe-to-release claim is authorized by a
historical PASS label. Do not push the Client repository before the final gate.

The notification logout race and interrupted-submission return path are fixed
in `6cd4ef6`; their regressions pass. The native navigation preview, capability
fallbacks, native large-text height, status-bar safe area and honest advertised
price display are the current increment: 64 Flutter tests PASS and analysis PASS.
Native large-text/high-contrast route testing passes; full screen-reader and
physical-device verification remain outstanding.
Next: remaining independent security/visual/accessibility checks. Resume actual provider flows immediately
when the explicitly authorized domain/project/key and physical device are available.

### Zero-cost recovery and migration checkpoint

- Railway switched through its explicit Free-only operation: FREE, no payment
  method, active Free subscription, about $0.99987 included credit remaining.
- Both original PostgreSQL volumes retained. Every non-template database and
  globals exported; application and identity dumps restored successfully into
  separate, socket-only PostgreSQL 18 verification clusters. Clusters stopped.
- Current application: 35 tables, 273 gyms / 743 clubs / 531 events, 1 profile,
  no results/submissions/reviews. Current identity: 88 tables, 2 realms, 4 users,
  4 credentials. These are real recovered aggregates, not fixtures.
- Two encrypted local copies per export verified; off-device copy not yet made.
  Configuration snapshots before/after recovery are protected outside Git.
- All Railway workloads stopped again; temporary public database proxies removed.
  No production imports, migrations, deletions or account changes occurred.
- VM deployment candidate prepared, not deployed. Oracle Free signup/capacity,
  approved DNS and Cloudflare Free billing confirmation remain external gates.
- Use `ZERO_COST_MIGRATION.md` for current provider limits, data provenance,
  rollback constraints and the exact next actions. Current mobile endpoints,
  store binaries and Client repository remain unchanged. Do not hand off yet.

### ARM migration rehearsal and configuration safeguards

- Current dumps restored in fresh private PostgreSQL ARM containers; counts and
  validated constraints PASS. Actual Keycloak realm export PASS, protected outside
  Git. SMTP absent, Google disabled/no credentials, Apple broker absent.
- Corrected identity DB-name mismatch, raw-env secret preservation and storage
  CORS path-style configuration. Actual Compose/Caddy configuration PASS.
- ARM Go and optimized Keycloak image builds PASS; restricted Docker context
  excludes history/caches/credentials. Actual ARM SeaweedFS multipart/privacy/
  tampered-signature/range/deletion/CORS checks PASS with temporary credentials.
- Web binds explicit replacement endpoints rather than hard-coded Railway;
  five deployment tests + ten auth tests, lint/type/build PASS. No live deploy.
- Eight live mobile-width public/admin entry routes PASS for rendering/overflow/
  safe outage presentation, not authenticated product availability. No physical
  Apple device was discovered; real-device provider tests remain blocked.
- Next action: Oracle signup/console access, inspect eligible Always Free capacity,
  then provision/restore and public HTTPS testing. Do not produce final store
  replacements for stopped API/auth URLs or perform the Client handoff.
- Native iOS appearance approved and enabled by default on supported versions;
  unsupported/error/Android fallbacks remain intact. Flutter analysis and all
  64 tests PASS after adoption. This closes the appearance-approval dependency,
  not hosting, provider, physical-device or publication gates.

## Operating record

- **Scope:** Original FitCalgary V1 only. The separate future community-product
  discussion is out of scope and must not alter this release.
- **Private baseline:** `601587558c65fd5be31cf25d3989fbdae911dfba` on `main`.
- **Latest verified release record:** `57c8be28ba20f16f141dad7879189e993beba11a`
  on `main`, with the final release-record tag pushed only to the private
  development remote.
- **Clean handoff candidate:** local folder
  `/Users/sahlshafiq/Documents/Coding/fitcalgary-final-handoff-candidate-20260912-final`,
  one-commit SHA `dbc3a027e9aaa2a2c38f61825cef195071d32863`.
- **Current worktree:** Contains the verified cross-platform visual refinement,
  release identity, submission-build preparation and refreshed Client package
  that followed the recorded handoff candidate. No replacement Client handoff
  commit or tag has been created from this worktree.
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
| 23 | Web responsiveness and accessibility | PASS | Lint, type check, production build, route inventory and client accessibility-focused tests pass. Desktop and 390px responsive visual inspection passed with no browser console errors after the layered-surface refinement. |
| 24 | iOS | PASS | FitCalgary release identity and simulator build pass. The Watch companion is embedded in Runner with correct bundle IDs. A signed archive/IPA requires the Client Apple team, Distribution identity, provisioning and real production configuration. |
| 25 | Android | PASS | FitCalgary release identity and emulator debug build/launch pass. A dedicated Play upload key and fail-closed signed-build path are ready; the former debug-signed AAB was quarantined. A new production AAB requires real production configuration. |
| 26 | Apple Watch | PASS | The watchOS companion builds and is embedded in the iOS simulator application; signing, hardware and store verification are BLOCKED_EXTERNAL. |
| 27 | Deep links | PASS | Supported web/app route inventory and notification-link allow-list tests pass. |
| 28 | Error/loading/empty states | PASS | Flutter widget coverage and web/API structured-error paths pass. |
| 29 | Security | PASS | Authorization, validation, private storage, safe errors, release gates and tracked-source scans pass. |
| 30 | Performance and reliability | PASS | Request timeouts, pagination/limits, idempotent queues, migration checks and graceful failure paths are covered. |
| 31 | Backups and operations | PASS | Backup/restore, migration, deployment and rollback runbooks are documented. |
| 32 | Logging and health checks | PASS | `/health`, `/ready` (database ping), structured safe logging and operational failure signals are implemented and documented. |
| 33 | Release builds | PASS | Web, Go and the branded iOS/Android/watchOS development builds pass locally. Mobile release scripts now reject missing or unsafe production values; no store-signed AAB or IPA is represented as complete. |
| 34 | Store readiness | BLOCKED_EXTERNAL | App identity, icon, launch treatment, dedicated Android upload key and fail-closed mobile release paths are prepared. Real production endpoints/domain and Apple signing access are required before store artifacts can be created and verified. |
| 35 | Deployment readiness | BLOCKED_EXTERNAL | The production web build and environment-driven deployment path are ready. Public hosting authorization, DNS/TLS, managed PostgreSQL/storage, Keycloak and provider credentials are still required for a live URL. |
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
configuration hardening and tracked-source sanitation are complete. The refined
layered-surface system is applied to Flutter and web: iOS floating controls use
appropriate translucency and depth, Android/web use platform-suitable layered
surfaces, reading surfaces remain opaque, decorative hero gradients were removed,
and reduced-motion, reduced-transparency and high-contrast fallbacks remain
explicit. FitCalgary app identity, icons and launch treatments are integrated;
the dedicated Android upload key, mobile signing scripts and embedded Watch
companion are prepared. The former debug-signed Android bundle was quarantined,
and no store-signed mobile artifact is claimed before real production inputs are
available. The five-page
Client review and both 1920x1080 videos were refreshed and visually inspected.
The recorded clean handoff candidate remains unchanged until a later authorized
Client handoff. Remaining live release work is limited to external production
configuration, signing, deployment and store-review inputs.

## Latest verification evidence

- Flutter 3.47.2 / Dart 3.13.2: `flutter analyze` and `flutter test` pass (20 tests).
- Go: `go test ./...`, `go vet ./...`, and stripped API production build pass.
- PostgreSQL 17.11: clean migration/import and repeat-import checks pass; 35 tables,
  273 gyms, 743 clubs, 531 events and 1,547 source records verified.
- Web: lint, TypeScript, production build, auth tests and admin-content tests pass.
- Visual refinement regression: Flutter analysis and 20 tests pass; web lint,
  TypeScript and production build pass; responsive desktop/phone visual review
  passes with no browser console errors.
- iOS: branded simulator build passes with the Watch companion embedded; signed
  archive/IPA generation is blocked by Apple signing access and production values.
- Android: branded debug APK emulator install/launch passes; the dedicated upload
  key and signed-build verification path are ready, while production AAB generation
  is blocked by real production values.
- watchOS: companion bundle builds and is embedded in the iOS simulator app.
- Source hygiene: `git diff --check` and tracked secret/internal-tool scans pass;
  `.env` files remain ignored and no production values are committed.
- Handoff hygiene: clean candidate tree contains 387 tracked files, exactly one
  reachable commit, no review media/simulator artifacts, no internal-tool terms,
  no private development references, and no secret material.
- Client package: `client-review/phase-3/` contains the refreshed final review
  PDF, product demonstration and technical proof. The PDF is five pages; both
  H.264 videos are 1920x1080, visually inspected, with clean product evidence and
  explicit external publishing boundaries.
