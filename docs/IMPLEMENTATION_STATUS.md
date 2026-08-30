# Implementation status

Status vocabulary: `NOT_STARTED`, `IN_PROGRESS`, `IMPLEMENTED`, `CONFIGURED`, `TESTED`, `DEVICE_VERIFIED`, `PRODUCTION_VERIFIED`, `BLOCKED_EXTERNAL`, `DEPRECATED`, `NON_PRODUCTION`.

“Simulator tested” is not real-hardware `DEVICE_VERIFIED`. Nothing in this report is represented as `PRODUCTION_VERIFIED` unless it was exercised against the production service.

| Area | Current status | Evidence and boundary |
|---|---|---|
| Repository and architecture | IMPLEMENTED / TESTED | One codebase; Flutter/Dart mobile, Go services, PostgreSQL, Keycloak, private storage, web-native public/admin, SwiftUI watchOS. Go test/build and all client builds pass. |
| PostgreSQL schema/migrations | TESTED | PostgreSQL 17.11 initialized from empty state; `0001_initial.sql` applied twice through the Go migrator; 30 public tables; checksum `a563ca44c48ff9daf4b2ca7f378dcaa048145d818319902f1fc90044013862f7`. |
| Go API and workers | TESTED | Public/account/submission/judge/admin/notification foundations compile; unit/security tests and `go vet` pass; database readiness and read/write integration exercised locally. |
| TypeScript API prototype | DEPRECATED / NON_PRODUCTION | Frozen reference in `services/api`; not in the deployment topology and not extended. |
| Keycloak realm | CONFIGURED / BLOCKED_EXTERNAL | Registration, verification, reset, brute-force protection, PKCE clients, roles, and disabled Google/Apple brokers are represented in valid realm JSON. Production host, SMTP, and broker credentials are external. |
| Auth/session/authorization | TESTED / BLOCKED_EXTERNAL | Go OIDC adapter, web encrypted BFF session, Flutter secure storage/refresh/logout, role/owner tests, 401 test, and development mock identity read/write pass. Production OIDC login is awaiting service credentials. |
| API contracts | IMPLEMENTED / TESTED | Versioned route set in `services/api-go/internal/httpapi`, consumer contracts, and `docs/API_CONTRACT.md`; live gym and auth-context responses exercised. |
| Flutter shared app | TESTED (SIMULATORS) / NOT DEVICE_VERIFIED | Analyze and widget test pass. Android API 36 and iPhone 17 Pro simulators build/install/launch. Android loaded a database record through Go. No real phone test yet. |
| Android toolchain/release output | TESTED (EMULATOR) / NOT DEVICE_VERIFIED | SDK 36, JDK 21, emulator 37.1.11, licenses accepted, Pixel API 36 AVD; debug APK installed/launched; release AAB built (53.5 MB). Not signed with client production key or uploaded. |
| iOS toolchain | TESTED (SIMULATOR) / NOT DEVICE_VERIFIED | Xcode 26.6; Flutter simulator debug build, install, launch, and screenshot pass on iPhone 17 Pro. SPM build path works without CocoaPods. No signed archive/real device. |
| Web foundation | TESTED locally / BLOCKED_EXTERNAL | Public, auth BFF, admin shell, backend proxy, and directory routes build. Oxlint and TypeScript check pass for product code; Vinext production build passes. Current hosted preview is private and not production verification. |
| watchOS foundation | TESTED (SIMULATOR) / NOT DEVICE_VERIFIED | Native SwiftUI target builds and launches on Apple Watch Series 11 simulator; companion session reports reachable in simulator. No real Apple Watch test. |
| Private evidence storage | IMPLEMENTED / BLOCKED_EXTERNAL | S3 multipart/sign/playback adapter and retention worker exist. Production bucket and credentials are required for service verification. |
| Notifications | IMPLEMENTED / BLOCKED_EXTERNAL | Database/outbox/device-token encryption foundations exist and tests pass. APNs/FCM credentials and real devices are required for delivery verification. |
| Gym/event/client data | IN_PROGRESS / BLOCKED_EXTERNAL | Schema, APIs, clients, and admin publication paths exist. Only explicit Phase 1 test data was used; client-confirmed production content is required. |
| Production deployment | NOT_STARTED / BLOCKED_EXTERNAL | Domain, hosting accounts, managed database/storage/Keycloak, secrets, DNS/TLS, and client ownership decisions required. |
| Store submission | NOT_STARTED / BLOCKED_EXTERNAL | Client store accounts, signing identities, final content/legal approvals, device QA, assets, and production endpoints required. |

Substantial Phase 2 feature work is paused pending explicit authorization after Phase 1 client review.
