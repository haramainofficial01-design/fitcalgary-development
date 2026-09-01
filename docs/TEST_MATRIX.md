# Test matrix

Executed on 2026-08-31 in the developer’s local macOS environment. Simulator results are separate from real-device verification.

Daily regression refresh on 2026-09-01: Flutter analysis and all four widget tests passed; Go tests, `go vet` and production build passed; web lint, TypeScript checking, two session/PKCE authorization tests and the production build passed. Platform simulator/emulator entries below retain their 2026-08-31 verification dates until the scheduled final checkpoint.

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
| Flutter product web build/runtime | `flutter build web --release --dart-define=API_BASE_URL=...`; local Chrome launch | PASS | Responsive Client product shell rendered; configured-origin API calls succeeded |
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
| Web production build | `pnpm build` | PASS | Public/admin/auth/backend routes emitted |
| Keycloak realm artifact | JSON parse plus setting inspection | PASS | Verify email/reset/registration/brute force; roles; PKCE S256 clients; disabled Google/Apple hooks |
| Secret scan | High-confidence key/private-key scan plus sensitive-file inventory | PASS | No credential material or secret environment files staged |
| Private source recovery | Clean clone of Developer-controlled private repository; `git fsck --full`; remote/clone SHA comparison; Go tests; Flutter analysis/tests | PASS | Clone HEAD `76b8a64`; remote matched; Go packages passed; Flutter found no issues and all four tests passed |

## Platform verification ledger

| Platform | Simulator/emulator | Real device | Production |
|---|---|---|---|
| iOS | TESTED — iPhone 17 Pro simulator | NOT DEVICE_VERIFIED | NOT PRODUCTION_VERIFIED |
| Android | TESTED — Pixel API 36 emulator | NOT DEVICE_VERIFIED | NOT PRODUCTION_VERIFIED |
| watchOS | TESTED — Apple Watch Series 11 simulator | NOT DEVICE_VERIFIED | NOT PRODUCTION_VERIFIED |
| Web | TESTED — local build | Not applicable | NOT PRODUCTION_VERIFIED |
| Go/PostgreSQL | TESTED — local processes | Not applicable | NOT PRODUCTION_VERIFIED |
