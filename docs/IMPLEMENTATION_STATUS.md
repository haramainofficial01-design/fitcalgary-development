# Implementation status

Status vocabulary: `NOT_STARTED`, `IN_PROGRESS`, `IMPLEMENTED`, `CONFIGURED`, `TESTED`, `DEVICE_VERIFIED`, `PRODUCTION_VERIFIED`, `BLOCKED_EXTERNAL`, `DEPRECATED`, `NON_PRODUCTION`.

“Simulator tested” is not real-hardware `DEVICE_VERIFIED`. Nothing in this report is represented as `PRODUCTION_VERIFIED` unless it was exercised against the production service.

| Area | Current status | Evidence and boundary |
|---|---|---|
| Repository and architecture | IMPLEMENTED / TESTED | One codebase; Flutter/Dart mobile, Go services, PostgreSQL, Keycloak, private storage, web-native public/admin, SwiftUI watchOS. Go test/build and all client builds pass. |
| Source/version control | TESTED / PRIVATE REMOTE VERIFIED | Authentic history, foundation snapshot and acceptance-candidate tag are preserved in `haramainofficial01-design/fitcalgary-development` (private). A clean clone matched remote HEAD and passed Git integrity, Go tests, Flutter analysis and all Flutter tests. Client repository remains read-only input. |
| Client original source | AUDITED / HISTORY VERIFIED | Client-authorized archive and authenticated full clone at source commit `4c629019`; three available commits plus archive/tree digests recorded in `docs/CLIENT_SOURCE_PROVENANCE.md`. Product/UI/security decisions mapped to the active implementation; Client remote remains read-only. |
| PostgreSQL schema/migrations | TESTED | PostgreSQL 17.11 initialized from empty state; `0001_initial.sql` applied twice through the Go migrator; 30 public tables; checksum `a563ca44c48ff9daf4b2ca7f378dcaa048145d818319902f1fc90044013862f7`. |
| Go API and workers | TESTED | Public/account/submission/judge/admin/notification foundations compile; unit/security tests and `go vet` pass; database readiness and read/write integration exercised locally. |
| TypeScript API prototype | DEPRECATED / NON_PRODUCTION | Frozen reference in `services/api`; not in the deployment topology and not extended. |
| Keycloak realm | CONFIGURED / BLOCKED_EXTERNAL | Registration, verification, reset, brute-force protection, PKCE clients, roles, and disabled Google/Apple brokers are represented in valid realm JSON. Production host, SMTP, and broker credentials are external. |
| Auth/session/authorization | TESTED / BLOCKED_EXTERNAL | Go OIDC adapter, web encrypted BFF session, Flutter secure storage/refresh/logout, role/owner tests and environment-supplied development identities pass: unauthenticated admin is 401, USER is 403 and ADMIN is 200. Production OIDC login awaits service credentials. |
| API contracts | IMPLEMENTED / TESTED | Versioned route set in `services/api-go/internal/httpapi`, consumer contracts, and `docs/API_CONTRACT.md`; live gym and auth-context responses exercised. |
| Flutter shared product | TESTED (SIMULATORS/EMULATOR/WEB) / NOT DEVICE_VERIFIED | Client-recognizable Home, Gym Index, Board, Compete, Me and sign-in shell; working navigation, search/filters/sort, board selection and event details. Analysis and navigation tests pass. Android API 36, iPhone 17 Pro simulator and Flutter web build/launch; Android loaded a database record through Go. No real phone test yet. |
| Onboarding and route behavior | TESTED (SIMULATOR/EMULATOR) | First-launch progression, account/auth entry, persisted completion, returning-user bypass and all primary destinations passed widget plus Android/iOS integration demonstrations. |
| Admin dashboard foundation | TESTED locally / BLOCKED_EXTERNAL | Responsive authenticated dashboard, overview/navigation, loading/error states and API-backed representative values are implemented. Server returns 401 unauthenticated, 403 USER and 200 ADMIN. Full CRUD depth and production identity remain later work. |
| Android toolchain/release output | TESTED (EMULATOR) / NOT DEVICE_VERIFIED | SDK 36, JDK 21, emulator 37.1.11, licenses accepted, Pixel API 36 AVD; debug APK installed/launched; release AAB built (53.5 MB). Not signed with client production key or uploaded. |
| iOS toolchain | TESTED (SIMULATOR) / NOT DEVICE_VERIFIED | Xcode 26.6; Flutter simulator debug build, install, launch, and screenshot pass on iPhone 17 Pro. SPM build path works without CocoaPods. No signed archive/real device. |
| Web foundation | TESTED locally / BLOCKED_EXTERNAL | Responsive Flutter product web build/run passes. Public/auth BFF/admin/backend-proxy routes also pass Oxlint, TypeScript and Vinext production build. Neither local surface is production verification. |
| watchOS foundation | TESTED (SIMULATOR) / NOT DEVICE_VERIFIED | Native SwiftUI target builds and launches on Apple Watch Series 11 simulator; companion session reports reachable in simulator. No real Apple Watch test. |
| Private evidence storage | IMPLEMENTED / BLOCKED_EXTERNAL | S3 multipart/sign/playback adapter and retention worker exist. Production bucket and credentials are required for service verification. |
| Notifications | IMPLEMENTED / TESTED / BLOCKED_EXTERNAL | Inbox/outbox, encrypted FCM registration-token lifecycle, preferences, retry/backoff, invalid-token disabling, Flutter permission/registration/logout hooks and an HTTP v1 provider adapter are tested. Firebase/APNs production credentials and real devices remain required for live delivery verification. |
| Gym/account workflows | TESTED increment / IN_PROGRESS overall | Server search/filters/paging, current membership prices/terms, Flutter detail/comparison, private saved gyms and profile persistence run against Go/PostgreSQL; mobile integration tests exercise actual read/write. Broader Phase 2 acceptance remains pending. |
| Club/event workflows | DEVELOPMENT + SIMULATOR TESTED / IN PROGRESS overall | Admin create/update/publish/unpublish/archive, public detail/search/filter/paging and event temporal states use existing schema. Flutter Compete browse/detail and external-link states plus web-admin club/event creation are integrated. Real PostgreSQL and iOS/Android tests verify publication visibility, roles, validation and atomic audit rollback. Full edit forms and Client content remain. |
| Athlete profile | DEVELOPMENT + SIMULATOR/EMULATOR TESTED / IN PROGRESS overall | Persisted birth date, board category, published gym affiliation and privacy controls; owner-only server-ranked official/community results and personal bests; distinct Flutter presentation. PostgreSQL ownership/persistence tests and iOS/Android profile UI tests pass. Final Client rules/content and complete approved-result workflow remain. |
| Gym/event/client data | IN_PROGRESS / BLOCKED_EXTERNAL | Real models plus isolated opt-in development fixtures; production guards reject fixture databases. Client-approved production content remains external. |
| Production deployment | NOT_STARTED / BLOCKED_EXTERNAL | Domain, hosting accounts, managed database/storage/Keycloak, secrets, DNS/TLS, and client ownership decisions required. |
| Store submission | NOT_STARTED / BLOCKED_EXTERNAL | Client store accounts, signing identities, final content/legal approvals, device QA, assets, and production endpoints required. |

Phase 1 is COMPLETE / ACCEPTED / FULLY PAID / CLOSED, as explicitly confirmed by
the Developer. Phase 2 is authorized and in progress; all new work belongs to
Phase 2. Development fixture isolation and production data guards are tested;
see `PHASE_2_STATUS.md` and `PHASE_2_DELIVERY_PLAN.md`. Additive migration `0002`
extends membership terms without changing historical `0001`. Later
production/device dependencies do not reopen Phase 1.

The historical Phase 1 Client review package contains one consolidated four-page
PDF and two MP4 demonstrations, reviewed on 2026-09-01. Preserve the accepted
package and existing Git checkpoint/history. No Phase 1 package, approval, payment
or development work remains pending.
