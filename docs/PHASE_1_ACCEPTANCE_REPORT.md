# Phase 1 acceptance report

## A. Executive summary

# PHASE 1 READY FOR CLIENT REVIEW

The current repository materially satisfies the expanded Foundation checkpoint within the Developer’s control, subject only to final private-remote/fresh-clone verification and Client-package quality control. It combines the Flutter/Dart + Go + PostgreSQL + Keycloak technical foundation with a working, responsive product shell derived from the Client’s supplied FitCalgary direction. Onboarding, Home, Gym Index, Board, Compete, Me, sign-in and role-protected administration are recognizable, navigable, and demonstrated on iOS, Android and Flutter web; watchOS remains a separate companion.

Production identity/social credentials, production infrastructure, real devices, store signing/accounts, and final client content are correctly `BLOCKED_EXTERNAL`; they are not represented as completed or production verified.

Original technical-foundation snapshot: `13bac633f623cf259a82fe7238741ae422f89096`. The expanded UI evidence commit is recorded in the final Client package.

## B. Contract requirement matrix

| Requirement | Status | Implementation evidence | Relevant files/modules | Test performed | Result | Remaining dependency/blocker |
|---|---|---|---|---|---|---|
| Repository audit and clean structure | TESTED | One monorepo/topology; deprecated Node service isolated | `AGENTS.md`, `README.md`, `apps/`, `services/`, `infrastructure/`, `docs/` | Full file/status audit; build sweep | PASS | None for Phase 1 |
| Private development history | IN_PROGRESS / TESTED LOCALLY | Authentic history, foundation snapshot, report commit and acceptance-candidate tag preserved; backup bundle verified | `.git`, backup bundle, milestone references | Log/reflog/branch/tag/bundle audit | PASS locally | Private remote and fresh clone are final gate |
| Client source review/import | AUDITED / HISTORY VERIFIED | Read-only Client source snapshot and authenticated full Git history inspected at commit `4c629019`; product/UI/security decisions mapped without extending the obsolete Node backend | `docs/CLIENT_SOURCE_PROVENANCE.md`, external read-only archive and Git clone | Archive/tree digest, three-commit history, file and architecture comparison | PASS | Client repository remains unmodified |
| Flutter/Dart + Go architecture documented | IMPLEMENTED | Runtime/trust topology and decisions documented | `docs/ARCHITECTURE.md`, `docs/DECISIONS.md` | Documentation/code topology comparison | PASS | None |
| Core schema and migrations | TESTED | 30-table PostgreSQL schema plus deterministic seeds/indexes | `services/api/migrations/0001_initial.sql`, `internal/db/migrate.go`, `cmd/migrate` | Empty DB migration and repeat run | PASS | Production DB is `BLOCKED_EXTERNAL` |
| Environment/config structure | CONFIGURED | Non-secret example and strict Go validation | `.env.example`, `internal/config/config.go` | Config review; invalid/missing values fail closed | PASS | Production secret values required |
| User/account foundation | TESTED | OIDC-subject profile upsert, profile/context/delete/saved-gym endpoints | `internal/httpapi/account.go`, Flutter auth/profile code | Mock bearer request persisted active profile | PASS | Real production account test awaits Keycloak host |
| Role/permission model | TESTED | Five known roles, token mapping, stored grants, role/owner/assignment checks | `internal/auth`, `server.go`, `admin.go`, `judge.go` | Unit tests plus authenticated `USER` context | PASS | Production role mapping verification awaits Keycloak host |
| Identity integration foundation | CONFIGURED / TESTED | Keycloak realm, OIDC adapter, PKCE clients, secure Flutter/web sessions | Keycloak realm, `auth.go`, Flutter `auth_service.dart`, web `server-auth.ts` | JSON/settings check; auth unit tests; dev mock flow | PASS | Production host/SMTP `BLOCKED_EXTERNAL` |
| Social sign-in hooks | CONFIGURED / BLOCKED_EXTERNAL | Google/Apple brokers declared disabled with no secrets | Keycloak realm and README | Realm inspection | PASS as hook | Google/Apple credentials and live flows required |
| Flutter ↔ Go service connection | TESTED | App configured to versioned API; Android rendered live API record | Flutter `api_client.dart`, Go router | Android emulator Gyms navigation | PASS | Production URL/TLS required later |
| Go ↔ PostgreSQL read/write | TESTED | Readiness, public query and auth profile upsert used real PostgreSQL | Go router/handlers and migration | Curl + SQL verification | PASS | Managed DB later |
| Gym API foundation | TESTED | Public list/detail plus protected admin/pricing routes | `public.go`, `admin.go` | Live seeded gym query through Flutter | PASS | Client production content |
| Event API foundation | IMPLEMENTED / TESTED | Public filtering and admin create/list routes | `public.go`, `admin.go` | Go build/test and web route build | PASS foundation | Client production content |
| Leaderboard API foundation | IMPLEMENTED / TESTED | Catalogue/detail/rank queries and ranking domain logic | `public.go`, `judge.go`, `domain/` | Unit/build tests | PASS foundation | Phase 2 end-to-end result population |
| Submission API foundation | IMPLEMENTED / TESTED | Owner list/create, multipart lifecycle, validation | `submissions.go`, storage adapter | Go tests/build and route audit | PASS foundation | Live bucket and full Phase 2 workflow |
| Notification API foundation | IMPLEMENTED / TESTED | Owner-scoped devices, encrypted token storage, outbox worker | `account.go`, `security/`, `workers/` | Cipher/ownership/worker tests | PASS foundation | APNs/FCM and devices `BLOCKED_EXTERNAL` |
| Admin API foundation | IMPLEMENTED / TESTED | Overview/reference/users/content/roles/audit protected routes | `admin.go`, web admin/BFF | Go role tests, TypeScript/build checks | PASS foundation | Full Phase 2 operations and client data |
| iOS development/build environment | TESTED (SIMULATOR) | Flutter iOS app builds, installs and launches | Flutter iOS project | Xcode 26.6 simulator build/launch | PASS | Real device/signing NOT DEVICE_VERIFIED |
| Android development/build environment | TESTED (EMULATOR) | SDK/JDK/licenses/AVD configured; APK and AAB build | Flutter Android project | Doctor, APK install/launch, AAB build | PASS | Real device/signing NOT DEVICE_VERIFIED |
| Core Flutter app build/run | TESTED (SIMULATORS) | Shared app analyzes/tests and runs on both mobile simulators | `apps/fitcalgary_app` | Analyze, widget test, iOS/Android launch | PASS | Real devices later |
| Client product shell | TESTED (SIMULATOR/EMULATOR/WEB) | Client-recognizable Home, Gym Index, Board, Compete, Me and Keycloak sign-in shell; working navigation, filters, sort, board selection and event details | Flutter feature screens and navigation tests | Side-by-side review against supplied Client screens; route/control tests; visual launch review | PASS | Final content and deep workflows remain Phase 2 |
| Onboarding and primary routes | TESTED (SIMULATOR/EMULATOR) | First-launch welcome/progression/account entry, completion persistence, returning-user behavior and primary navigation implemented | Flutter onboarding store/screen/router and integration test | Widget tests plus Android/iOS route demonstration | PASS | Production social/account credentials remain external |
| Admin dashboard foundation | TESTED locally | Responsive authenticated dashboard with overview and structural areas; API loading/error states; server-side role enforcement | `apps/web`, Go admin routes/tests | Unauthenticated 401, USER 403, ADMIN 200; rendered overview | PASS foundation | Full Phase 2 CRUD and production identity |
| Web foundation | TESTED locally | Responsive Flutter product shell plus public/admin routes, auth BFF, proxy and admin shell | `apps/fitcalgary_app/web`, `apps/web` | Flutter web release/run; Oxlint, TypeScript, Vinext production build | PASS | Production env/domain `BLOCKED_EXTERNAL` |
| Apple Watch/watchOS foundation | TESTED (SIMULATOR) | Native SwiftUI target, Keychain/session/watch summary model | `apps/watch` | Xcode build/install/launch | PASS | Real Watch NOT DEVICE_VERIFIED |
| Security baseline | TESTED | Secret isolation, OIDC, secure tokens, server authorization, validation/errors, private evidence, auditing | `docs/SECURITY_BASELINE.md` and service/client modules | Auth/owner/cipher tests; source review | PASS foundation | Production penetration/config review in Phase 3 |
| Dependencies documented | IMPLEMENTED | Tool/runtime versions and service dependencies recorded | README, service READMEs, Test Matrix | Documentation audit | PASS | Client provider selections later |
| Client credentials/data documented | IMPLEMENTED | Exact owner/input/verification list | `docs/BLOCKERS.md` | Blocker audit | PASS | Listed external items |
| Phase 2 path documented | IMPLEMENTED | Continuous-codebase continuation plan and acceptance direction | `docs/PHASE_2_IMPLEMENTATION_PATH.md`, `docs/CONTRACT_PHASE_STATUS.md` | Scope review | PASS | Requires explicit authorization |
| Migrations reproducibly initialize | TESTED | Checksum ledger, transaction, second no-op run | `internal/db/migrate.go`, `cmd/migrate` | Fresh PostgreSQL 17.11, twice | PASS | None for Phase 1 |
| Secrets outside committed source | TESTED | Templates/placeholders only; build outputs/toolchains ignored | `.env.example`, `.gitignore` | Final secret-pattern and tracked-file scan | PASS at checkpoint | Production secret manager later |
| Auth/session and role protection demonstrated | TESTED with environment-supplied development identities | Missing token is 401; USER is 403 on admin; ADMIN is 200; profile read/write persists to PostgreSQL | `cmd/phase1-harness`, auth/server tests, admin dashboard | HTTP, rendered dashboard and SQL checks | PASS | Full external login remains `BLOCKED_EXTERNAL` |
| Automated smoke/unit checks | TESTED | Go, Flutter, web/static gates pass | Test suites/configs | Commands in Test Matrix | PASS | Expand in Phase 2 |
| Critical introduced build/runtime errors resolved | TESTED | UUID/JSON API encoding and migration extension dependency found during real integration and fixed | `server.go`, initial migration | Rebuild, rerun, visual API/DB check | PASS | None known for Phase 1 |

## C. Build evidence

| Component | Version/result |
|---|---|
| Flutter | 3.47.2 stable — analyze/test PASS |
| Dart | 3.13.2 |
| Go | 1.27.0 darwin/arm64 — test/vet/build PASS |
| Xcode/iOS | Xcode 26.6 — iPhone 17 Pro simulator build/install/launch PASS |
| Android | SDK 36, emulator 37.1.11, JDK 21 — debug APK build/install/launch PASS; release AAB build PASS |
| Web | Flutter product web release/build/run PASS; web-native public/admin lint/typecheck/build PASS |
| watchOS | watchSimulator 26.5 — Xcode build/install/launch PASS |
| Backend | Go production entry point and migration command build PASS |
| Database | PostgreSQL 17.11 — clean migration plus repeat migration PASS; 30 tables |

## D. Integration evidence

```text
Flutter Android (Pixel API 36 emulator)
  → GET http://10.0.2.2:4400/api/v1/gyms
  → Go Phase 1 gated acceptance runtime
  → PostgreSQL 17.11
  → Phase 1 Integration Gym / $25.00 normalized monthly
```

The rendered result is captured at `artifacts/simulator/android-phase1-api-db.png`. Separately, the Go API’s protected auth context inserted/read `phase1-development-user` in PostgreSQL and returned effective role `USER`.

## E. Auth/security evidence

- Keycloak realm enables registration, verified email, password reset and brute-force protection; `fitcalgary-web` and `fitcalgary-mobile` use S256 PKCE; realm roles are user, moderator, admin, personal trainer and judge.
- Google and Apple broker hooks contain no committed credentials and stay disabled until client keys exist. No Ory deployment exists.
- Flutter uses platform secure storage and standards-based authorization/refresh/logout. Web uses encrypted secure HttpOnly cookies and server-only tokens.
- Go validates bearer tokens through an OIDC adapter, maps an allowlist of roles, merges server grants, and enforces permissions/ownership server-side.
- A missing bearer produced HTTP 401; a fixed local-only development bearer produced an active persisted profile with `USER`. The harness is doubly gated to development and is not built by the production Dockerfile.
- Request size/shape validation, safe errors/request IDs, CORS/security headers, encrypted device tokens, private object storage and audit/retention foundations are present.

## F. Tests

Commands and exact boundaries are maintained in `docs/TEST_MATRIX.md`. All Phase 1 acceptance gates pass: Go tests/vet/build, clean/repeat migration, API/auth integration, Flutter analysis and product-navigation tests, Android APK/emulator/AAB, iOS simulator, Flutter web release/runtime, watchOS simulator, web-native lint/typecheck/build, and Keycloak configuration validation.

## G. External blockers

Production Keycloak/SMTP/Google/Apple credentials; managed PostgreSQL and private storage; APNs/FCM; domain/DNS/TLS; store accounts/signing; real devices; approved content and legal materials remain `BLOCKED_EXTERNAL`. See `docs/BLOCKERS.md`. These are not disguised as tested or production verified.

## H. Remaining Phase 2 work

After explicit authorization, complete and harden the V1 user and operational workflows: client-approved gym/club/event data and comparison UX; complete profile/auth recovery experiences; official and community boards/divisions; full evidence upload/review/comments/resubmission/ranking; operational admin and moderation; notification delivery; analytics/integrations; saved gyms and platform parity. Existing work is preserved and extended.

## I. Plain-language client summary

FitCalgary’s expanded Phase 1 foundation is ready for review. It now combines the production architecture with a working Client-recognizable product shell across iOS, Android and responsive Flutter web, plus the separate Apple Watch companion. The five primary app areas navigate correctly, visible controls behave, development data is labeled, and Flutter has been shown reading PostgreSQL data through the Go service. Production credentials, final content, store access and physical-device checks remain clearly separated from completed work. Subject to Client acceptance, the same codebase is ready for Phase 2.
