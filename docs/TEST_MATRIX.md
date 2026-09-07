# Test matrix

## September 6 Phase 2 integrated verification

- Real private storage: signed multipart upload (7 MiB), exact bytes, range retrieval,
  unsigned/tampered denial, completion retry and deletion PASS.
- Chrome → Go → PostgreSQL/private storage: playable test clip, correction/resubmission,
  judge approval, official rank and inbox PASS. Synthetic clip tests transport only.
- iOS 26.5 Simulator / Android API 36 emulator: real Flutter submission and correction
  form/file upload, API judge decision, published board and inbox PASS. Test identity
  and picker boundary; not hardware or live-provider identity verification.
- Moderation: full role boundaries, immediate existing-token suspension/ban rejection,
  restoration, atomic notes/audit PASS in SQL and browser.
- Notifications: per-recipient admin announcement→inbox PASS, opt-in/out and essential
  events, idempotency, inactive-account suppression and five-attempt limit PASS in SQL.
- Web gym comparison/club browse/detail/mobile width PASS; type/lint/build PASS.
- Go complete tests/vet/build PASS; Flutter analysis/19 unit-widget tests PASS.

No Phase 2 final acceptance, production push or physical-device claim is implied.

Phase 1 is accepted, paid and closed per the Developer's confirmation. The platform
matrix below is historical evidence, not a pending acceptance list.

## Phase 2 increment — 2026-09-06

`test/admin-browser.mjs` PASS in Chrome with actual Go/PostgreSQL and ephemeral
development identity: profile editing and preferences survive reload; ordinary users
cannot enter admin; saving a gym on its detail page appears on the profile and removal
persists; sign-out removes the cookie and returns to sign-in; sign-in targets profile.
Community Bench Press entry also passes through the website to PostgreSQL, its board
and the owner performance endpoint. Existing directory/admin/browser checks pass.
Web TypeScript, lint and production build pass. These are not live Keycloak/social
sign-in, push delivery, physical-device or production-data verification. Notification
read controls are implemented but not yet included in this browser scenario.

## Phase 2 increment — 2026-09-05

### Subsequent role, administration and presentation verification

- Expanded `TestCompetitionDatabaseWorkflow`: PASS against the loopback PostgreSQL
  test database. Restrictions override existing and simulated refreshed/re-login
  provider claims; `/profile` and `/auth/context` agree; restoration and repeat
  revocation work; ordinary accounts cannot grant/revoke roles or patch their roles.
- `test/admin-browser.mjs`: PASS in Chrome against actual Go/PostgreSQL. Tests
  administrator/ordinary/signed-out gates, live grant/revoke, cross-origin rejection,
  full gym/pricing edits, event publication/edit/unpublication, club archive,
  narrow-screen form layout and Escape dismissal.
- The same browser scenario now verifies signed-out home search, API-backed results,
  clearing an empty search, retry after a simulated network outage, public-proxy
  allowlisting, a real gym detail with server-normalized monthly price and a missing
  listing. Screenshots/video remain internal `.artifacts/phase2/admin-browser` evidence.
- Web type checking, lint, production build and six auth/content unit tests: PASS.
- Flutter analysis and complete 19-test suite: PASS, including Apple/Android
  differentiation and high-contrast and reduced-motion opaque fallbacks.
- Updated iOS profile presentation: fresh Xcode build and simulator test PASS.
  Isolated presentation records are used; this is not new production identity or
  database evidence. Android also rebuilt/installed and passed the same presentation
  test on emulator-5554. An Android SDK XML version warning is present but did not
  fail the build; release-toolchain alignment remains a later validation item.

The implemented Flutter treatment is a platform-adaptive Flutter material surface,
not a claim that a native Liquid Glass API has been integrated. Remaining major-screen
polish, watchOS treatment, complete workflows and final review artifacts remain open.

| Check | Result | Boundary |
|---|---|---|
| Flutter analysis and complete widget/unit suite | PASS | 16 tests; real board projections, verification labels, configured metrics/checklists, normal-user review controls, notification preference save |
| Go tests, vet and `go build -o /tmp/fitcalgary-phase2-api ./cmd/api` | PASS | All packages; PostgreSQL-enabled directory and competition regression |
| `TestCompetitionDatabaseWorkflow` with `DIRECTORY_TEST_DATABASE_URL` | PASS | Actual PostgreSQL: config CRUD/role boundaries; validation; multipart state/ownership; decisions/corrections/cancelled retry; best-result ranks; time/repetition metrics; privacy; notification preference merging and owner-only opened state |
| Evidence provider boundary in that Go test | MOCKED | Verifies API/SQL transactions, not actual object transfer, production storage or video playback |
| Migrations 0003 + 0004 | PASS | Applied to disposable development database; ranking view, workflow constraints and cancelled-correction uniqueness |
| iOS `flutter test integration_test/competition_flow_test.dart` | PASS | Fresh simulator build/run; client submits a community weight result to Go/PostgreSQL, retrieves board/PB, normal-user judge rejection |
| Android same scenario on emulator-5554 | PASS | Fresh APK build/install/run; same actual client/API/database flow |
| Web `pnpm test:auth`, `pnpm exec tsc --noEmit`, `pnpm lint` | PASS | Encrypted sessions/PKCE; exact-origin checks on cookie-authenticated writes; configuration forms |
| Latest full-platform release regression and final client package | NOT YET COMPLETE | AAB, watchOS, web/mobile acceptance and actual recordings will be rerun for the final candidate |

Temporary local mobile run logs: `/tmp/fitcalgary-competition-verify.BWfSwn/ios.log`
and `/tmp/fitcalgary-competition-android.5Ckfwj/android.log`. These are internal
increment evidence, not the final Client deliverables. Subsequent preference/security
fixes passed automated regressions but have not yet had a new mobile recording.
All identity data is development-only; physical devices and production services
remain NOT VERIFIED. No Phase 2 completion, Client acceptance or payment is claimed.

## Phase 2 increment — 2026-09-04 evening

| Check | Result | Boundary |
|---|---|---|
| `flutter analyze`; complete `flutter test`; Flutter web release build | PASS | No findings; 11 tests including profile eligibility/privacy parsing and distinct verified/community result presentation; responsive web output rebuilt |
| `go test ./...`; `go vet ./...`; API production build | PASS | Full Go regression and production entry-point build passed after the final published-gym validation change |
| `DIRECTORY_TEST_DATABASE_URL=... go test ./internal/httpapi -run TestDirectoryAccountDatabaseFlow -count=1 -v` | PASS | Actual PostgreSQL: owner-only performance, current rank/personal best, no cross-account leakage, eligibility/privacy/gym persistence and missing-gym rejection, plus prior directory/account coverage |
| iOS `profile_shell_test.dart` | PASS — SIMULATOR | Built/launched on iPhone 17 Pro; profile identity, distinct official/community marks, ranks and edit controls passed; real screenshot captured and visually inspected |
| Android `profile_shell_test.dart` | PASS — EMULATOR | Debug APK built, installed and the same profile/ranking/privacy presentation assertions passed on Pixel API 36 emulator |
| Production identity/data and physical devices | NOT VERIFIED | Platform UI uses isolated development presentation records; API/database proof uses ephemeral identities and development data. No private evidence is exposed by the profile contract |

The product-profile screenshot is preparation evidence only; the final Phase 2
Client package is not yet generated. Ranking configuration and result lifecycle
remain the next end-to-end increment rather than being inferred from this profile view.

## Phase 2 increment — 2026-09-04 morning

| Check | Result | Boundary |
|---|---|---|
| Baseline `flutter analyze`; `flutter test` | PASS | No findings; seven existing tests pass; Flutter source unchanged this block |
| `go test ./...`; `go vet ./...`; `go build ./cmd/api` | PASS | Current backend with new club/event services |
| Fresh `APP_ENV=test DEMO_DATA=true DATABASE_URL=... go run ./cmd/dev-seed` | PASS | New loopback `fitcalgary_day4_content_test`; existing ordered migrations and isolated development fixtures |
| `CONTENT_TEST_DATABASE_URL=... go test ./internal/httpapi -run 'TestContentPublicationDatabaseFlow\|TestSafeContentLinks' -count=1 -v` | PASS | Existing and clean PostgreSQL: create/publish/update/unpublish/archive, public detail/search/category/sport filters, out-of-range totals, event states, invalid timestamp/link rejection, 401/403, audit persistence and forced audit-failure rollback |
| `DIRECTORY_TEST_DATABASE_URL=... go test ./internal/httpapi -run TestDirectoryAccountDatabaseFlow -count=1 -v` | PASS | Gym/account regression against the new disposable database |
| New club/event client/mobile/web workflow | NOT YET VERIFIED | Backend increment only; client/admin forms and profile depth remain September 4 work |

### September 4 afternoon continuation

| Check | Result | Boundary |
|---|---|---|
| `flutter analyze`; `flutter test` | PASS | No findings; nine tests including published event/club list → detail routes |
| iOS `flutter test integration_test/content_flow_test.dart -d <iPhone Simulator>` | PASS | Authenticated development admin publishes event/club through Go; Flutter retrieves and opens both; teardown archives both; actual PostgreSQL, 11-second assertion run |
| Android same scenario on `emulator-5554` | PASS | Debug APK built/installed; same cross-layer publication → client flow and teardown passed in 12 seconds |
| `flutter build web --release` | PASS | New responsive Compete directory and detail routes compile for web |
| web-native `pnpm lint`; `tsc --noEmit`; `pnpm build` | PASS | Admin club endpoint/creator compiles; production build emitted admin and public routes |
| Physical devices / production identity / production data | NOT VERIFIED | Test uses ephemeral runtime-only admin identity and isolated labelled fixtures |

No new physical-device, production-auth or production-data verification. Phase 1
remains closed and its checkpoint is preserved.

## Phase 2 increment — 2026-09-03

| Check | Result | Boundary |
|---|---|---|
| `go test ./...`, `go vet ./...`, `go build ./cmd/api` | PASS | Go regression and API build |
| `FIXTURE_TEST_DATABASE_URL=... go test ./cmd/dev-seed -v -count=1` | PASS | Fresh PostgreSQL 17.11; migrations, nonempty refusal, repeat load, normalized/unknown prices, production guard, real public API/filter responses |
| Explicit `go run ./cmd/dev-seed` repeat | PASS | Existing batch is not duplicated |
| `flutter analyze`; `flutter test` | PASS | No analysis findings; seven tests including directory parsing, incomplete pricing and error/retry/empty states |
| `DIRECTORY_TEST_DATABASE_URL=... go test ./internal/httpapi -run TestDirectoryAccountDatabaseFlow -count=1 -v` | PASS | Real PostgreSQL: filtering/paging/order, profile edits, saved-gym persistence/idempotency/ownership, unauthenticated rejection, admin pricing terms, future pricing exclusion and invalid payload rejection |
| Migration `0002` on existing and fresh disposable databases; repeat initializer | PASS | Optional membership fields/constraints; original migration unchanged; both ledger entries recorded without repeated initialization |
| iOS `flutter drive --driver=test_driver/gym_flow_driver.dart --target=integration_test/gym_account_flow_test.dart -d <iPhone simulator>` | PASS | Final recorded run: 13 seconds of assertions after Xcode build; browse/detail, normalized comparison, save/reload/remove and unique profile edit/reload through actual Go/PostgreSQL |
| Android `flutter test integration_test/gym_account_flow_test.dart -d emulator-5554` | PASS | Final build/install and 31-second flow passed after the profile-keyboard fix; same real service/database workflow |
| `flutter build web --release` | PASS | Current Flutter production build; no new web-browser account-flow verification implied |
| Recording-related failure and fix | RESOLVED for this run | iOS recording exposed keyboard-obscured profile save; scrollable editor, keyboard dismissal and final rerun passed. Android in-process screenshot surface conversion stalled input; removed capture mechanism and reran successfully. Use external emulator captures. |
| watchOS, Android release AAB, web-native runtime | NOT RERUN for this increment | Existing foundation results below remain historical; full Phase 2 regression scheduled before acceptance |

Toolchain: Flutter 3.47.2 / Dart 3.13; Go 1.27; PostgreSQL 17.11. Mobile tests use
an ephemeral local identity adapter and real loopback Go/PostgreSQL services. They
do not verify production Keycloak, Google/Apple sign-in or physical devices. Actual
iOS screenshots were captured and inspected internally; they are not a finished
Phase 2 client package. Test credentials are runtime-only and not committed.

## Historical Phase 1 checks

Fresh verification executed on 2026-09-01 in the developer’s local macOS environment. Simulator results are separate from real-device verification.

| Target | Command/check | Result | Evidence/notes |
|---|---|---|---|
| Go toolchain | `go version` | PASS | Go 1.27.0 darwin/arm64 |
| Go service | `go test ./...` | PASS | Auth, migration split, pricing, ownership/role, token cipher, workers |
| Go static analysis | `go vet ./...` | PASS | No findings |
| Go production entry point | `go build -o /tmp/fitcalgary-api ./cmd/api` | PASS | Native binary built |
| Migration clean initialization | `go run ./cmd/migrate` against empty PostgreSQL 17.11 | PASS | 30 public tables; 5 disciplines; 5 divisions |
| Migration repeatability | Same migration command a second time | PASS | No changes/errors; checksum ledger verified |
| API readiness/data read | `GET /ready`, `GET /api/v1/gyms` | PASS | Ready response and Phase 1 gym from PostgreSQL |
| Auth protection | `GET /api/v1/profile` without bearer | PASS | HTTP 401 `UNAUTHENTICATED` |
| Auth/role/profile write | Profile endpoint with environment-supplied development identity, then SQL profile query | PASS | HTTP 200; `USER`; active profile persisted; no test credential committed |
| Authorization rejection | `USER` token against `/api/v1/admin/overview` | PASS | HTTP 403 `FORBIDDEN` |
| Admin authorization success | `ADMIN` token against `/api/v1/admin/overview` | PASS | HTTP 200; responsive dashboard rendered current API values |
| Flutter analysis | `flutter analyze` | PASS | No issues |
| Flutter widget/product navigation | `flutter test` | PASS | Four tests cover Home, first-launch progression/persistence, returning-user bypass and Home/Gyms/Board/Compete/Me navigation |
| Flutter onboarding/routes on Android | `flutter test integration_test/phase1_demo_test.dart -d <Android emulator>` | PASS | First launch through Home, Gyms, Board, Compete, Me and return to Home |
| Flutter onboarding/routes on iOS | `flutter test integration_test/phase1_demo_test.dart -d <iOS simulator>` | PASS | Same first-launch and primary-route demonstration passed |
| Flutter product web build/runtime | `flutter build web --release --dart-define=API_BASE_URL=...`; local launch | PASS | Responsive Client product shell rendered; configured-origin API calls succeeded |
| Android debug build | `flutter build apk --debug` with emulator API URL | PASS | APK built and installed |
| Android release artifact | `flutter build appbundle --release` with placeholder production URLs | PASS | `app-release.aab`, 53.5 MB; not production signed |
| Android emulator launch | Explicit `am start` on Pixel/API 36 AVD | PASS | Cold launch, resumed `MainActivity` |
| Flutter → Go → PostgreSQL | Tap Gyms in Android emulator after fresh migration | PASS | UI semantics and screenshot show DB-seeded “Phase 1 Integration Gym” and normalized $25.00 price |
| Android app logs | App-PID error log review | PASS with benign platform notices | No Flutter exception/crash; emulator ashmem/IME notices only |
| iOS simulator build | `flutter build ios --simulator --debug` | PASS | `Runner.app` built with Xcode 26.6 |
| iOS simulator launch | `simctl install`, `simctl launch` on iPhone 17 Pro | PASS | PID returned; rendered screenshot |
| watchOS simulator build | `xcodebuild ... -sdk watchsimulator ... build` | PASS | Native SwiftUI target built |
| watchOS simulator launch | `simctl install`, `simctl launch` on Series 11 | PASS | PID returned; rendered dashboard screenshot |
| Web lint | `pnpm lint` | PASS | Product source linted; generated shadcn primitives excluded |
| Web type check | `pnpm exec tsc --noEmit` | PASS | No TypeScript errors |
| Web production build/runtime | `pnpm build`; HTTP checks for `/`, `/gyms`, `/leaderboards`, `/events`, `/signin`, `/admin` | PASS | All routes emitted and returned HTTP 200; ignored stale cache was cleared and an absolute-path portability scan passed |
| Keycloak realm artifact | JSON parse plus setting inspection | PASS | Verify email/reset/registration/brute force; roles; PKCE S256 clients; disabled Google/Apple hooks |
| Secret scan | High-confidence key/private-key scan plus sensitive-file inventory | PASS | No credential material or secret environment files staged |
| Private source recovery | Clean clone of Developer-controlled private repository; `git fsck --full`; remote/clone SHA comparison; Go tests; Flutter analysis/tests | PASS | Historical clone HEAD `76b8a64` matched its remote and passed; `e66e126` is a historical tested baseline. Phase 1 is closed; future recovery checks belong to ongoing Phase 2 version control. |
| Client review PDF | Generate, inspect metadata/text, render every page, visually inspect pages | PASS | Four-page PDF; clean hierarchy, readable screenshots, no clipping, no secrets, accurate verification boundaries |
| Client videos | Generate H.264 1080p MP4 files; inspect metadata/playback and representative frames | PASS | Demo 169 seconds; technical proof 139 seconds; readable sequence, real project evidence, no secrets or unrelated internal-tool material |

## Platform verification ledger

| Platform | Simulator/emulator | Real device | Production |
|---|---|---|---|
| iOS | TESTED — iPhone 17 Pro simulator | NOT DEVICE_VERIFIED | NOT PRODUCTION_VERIFIED |
| Android | TESTED — Pixel API 36 emulator | NOT DEVICE_VERIFIED | NOT PRODUCTION_VERIFIED |
| watchOS | TESTED — Apple Watch Series 11 simulator | NOT DEVICE_VERIFIED | NOT PRODUCTION_VERIFIED |
| Web | TESTED — local build | Not applicable | NOT PRODUCTION_VERIFIED |
| Go/PostgreSQL | TESTED — local processes | Not applicable | NOT PRODUCTION_VERIFIED |
