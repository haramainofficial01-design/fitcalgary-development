# Implementation status

Status vocabulary: `NOT_STARTED`, `IN_PROGRESS`, `IMPLEMENTED`, `CONFIGURED`, `TESTED`, `DEVICE_VERIFIED`, `PRODUCTION_VERIFIED`, `BLOCKED_EXTERNAL`, `DEPRECATED`, `NON_PRODUCTION`.

“Simulator tested” is not real-hardware `DEVICE_VERIFIED`. Nothing in this report is represented as `PRODUCTION_VERIFIED` unless it was exercised against the production service.

| Area | Current status | Evidence and boundary |
|---|---|---|
| Repository and architecture | IMPLEMENTED / TESTED | One codebase; Flutter/Dart mobile, Go services, PostgreSQL, Keycloak, private storage, web-native public/admin, SwiftUI watchOS. Go test/build and all client builds pass. |
| Delivered source | IMPLEMENTED | Application source, tests, migrations, approved catalog data, infrastructure templates, shared contracts, and maintenance documentation are included in this repository. |
| Client product direction | INCORPORATED | Product identity, information architecture, content structures, and relevant security decisions are reflected in the current implementation; see `docs/CLIENT_SOURCE_PROVENANCE.md`. |
| PostgreSQL schema/migrations | TESTED | PostgreSQL 17.11 initialized from empty state; ordered migrations `0001`-`0008` and the idempotent Client catalog import are verified. |
| Go API and workers | TESTED | Public/account/submission/judge/admin/notification foundations compile; unit/security tests and `go vet` pass; database readiness and read/write integration exercised locally. |
| TypeScript API prototype | DEPRECATED / NON_PRODUCTION | Frozen reference in `services/api`; not in the deployment topology and not extended. |
| Keycloak realm | CONFIGURED / BLOCKED_EXTERNAL | Registration, verification, reset, brute-force protection, PKCE clients, roles, and disabled Google/Apple brokers are represented in valid realm JSON. Production host, SMTP, and broker credentials are external. |
| Auth/session/authorization | TESTED / BLOCKED_EXTERNAL | Go OIDC adapter, web encrypted BFF session, Flutter secure storage/refresh/logout, role/owner tests and environment-supplied development identities pass: unauthenticated admin is 401, USER is 403 and ADMIN is 200. Production OIDC login awaits service credentials. |
| API contracts | IMPLEMENTED / TESTED | Versioned route set in `services/api-go/internal/httpapi`, consumer contracts, and `docs/API_CONTRACT.md`; live gym and auth-context responses exercised. |
| Flutter shared product | TESTED (SIMULATORS/EMULATOR/WEB) / NOT DEVICE_VERIFIED | Client-recognizable Home, Gym Index, Board, Compete, Me and sign-in shell; working navigation, search/filters/sort, board selection and event details. Analysis and navigation tests pass. Android API 36, iPhone 17 Pro simulator and Flutter web build/launch; Android loaded a database record through Go. No real phone test yet. |
| Onboarding and route behavior | TESTED (SIMULATOR/EMULATOR) | First-launch progression, account/auth entry, persisted completion, returning-user bypass and all primary destinations passed widget plus Android/iOS integration demonstrations. |
| Admin dashboard | TESTED locally / BLOCKED_EXTERNAL | Responsive authenticated dashboard, overview/navigation, content operations, loading/error states and API-backed values are implemented. Server returns 401 unauthenticated, 403 USER and 200 ADMIN. Production identity configuration remains external. |
| Android toolchain/release output | TESTED (EMULATOR) / NOT DEVICE_VERIFIED | SDK 36, JDK 21, emulator 37.1.11, licenses accepted, Pixel API 36 AVD; current debug APK installed/launched; release AAB built (55.1 MB). Not signed with client production key or uploaded. |
| iOS toolchain | TESTED (SIMULATOR) / NOT DEVICE_VERIFIED | Xcode 26.6 and CocoaPods 1.17.0; Flutter simulator build/install/launch pass on iPhone 17 Pro and an unsigned release archive is reproducible. No production signing or real-device test. |
| Web foundation | TESTED locally / BLOCKED_EXTERNAL | Responsive Flutter product web build/run passes. Public/auth BFF/admin/backend-proxy routes also pass Oxlint, TypeScript and Vinext production build. Neither local surface is production verification. |
| watchOS foundation | TESTED (SIMULATOR) / NOT DEVICE_VERIFIED | Native SwiftUI target builds and launches on Apple Watch Series 11 simulator; companion session reports reachable in simulator. No real Apple Watch test. |
| Private evidence storage | IMPLEMENTED / BLOCKED_EXTERNAL | S3 multipart/sign/playback adapter and retention worker exist. Production bucket and credentials are required for service verification. |
| Notifications | IMPLEMENTED / TESTED / BLOCKED_EXTERNAL | Inbox/outbox, encrypted FCM registration-token lifecycle, preferences, retry/backoff, invalid-token disabling, Flutter permission/registration/logout hooks and an HTTP v1 provider adapter are tested. Firebase/APNs production credentials and real devices remain required for live delivery verification. |
| Gym/account workflows | VERIFIED | Server search/filters/paging, current membership prices/terms, Flutter detail/comparison, private saved gyms and profile persistence run against Go/PostgreSQL; mobile and web integration tests exercise actual read/write. |
| Club/event workflows | VERIFIED | Admin create/update/publish/unpublish/archive, public detail/search/filter/paging and event temporal states use the production schema. The Client-approved clubs and competitions are imported and visible through Flutter/web and admin service paths. |
| Athlete profile | VERIFIED / BLOCKED_EXTERNAL | Persisted birth date, board category, published gym affiliation and privacy controls; owner-only server-ranked official/community results and personal bests; distinct Flutter/web presentation. Final policy decisions remain external where not supplied. |
| Gym/event/client data | IMPLEMENTED / TESTED | Client-approved JSON catalog imported through an idempotent Go path: 273 gyms, 743 clubs and 531 competitions; full source payload retained for provenance. |
| Production deployment | NOT_STARTED / BLOCKED_EXTERNAL | Domain, hosting accounts, managed database/storage/Keycloak, secrets, DNS/TLS, and client ownership decisions required. |
| Store submission | NOT_STARTED / BLOCKED_EXTERNAL | Client store accounts, signing identities, final content/legal approvals, device QA, assets, and production endpoints required. |

## Release boundary

Production identity, messaging providers, managed hosting and storage, domains, signing accounts, store access, and physical-device verification remain external until the corresponding credentials and accounts are supplied. These dependencies are not represented as production verified.
