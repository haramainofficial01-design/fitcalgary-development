# Blockers and external dependencies

## Phase 2 schedule and verification

September 4 morning: no new external blocker. Club/event service acceptance tests
pass; remaining client/admin form wiring and athlete-profile scope are developer
implementation work scheduled next, not dependencies to request from the Client.

September 4 afternoon: no new external blocker. Mobile/web Client routes and the
admin club creator are integrated; production content is still deliberately absent.
Athlete profile depth and comprehensive edit controls remain engineering work.

September 8 morning (evening contingency) targets the entire Phase 2 product and
three-file Client review package; it is not a completion guarantee. See
`PHASE_2_DELIVERY_PLAN.md`. Remaining workflow integration, web parity and final
cross-platform regression are engineering work, not Client blockers. Escalate
material schedule risk promptly. The September 3 directory/account flow is tested
on iOS Simulator and Android emulator with actual Go/PostgreSQL and test identities.
Recording-related emulator input/keyboard issues were corrected and rerun; they do
not establish physical-device or production-auth verification.

The Client-recognizable Flutter product shell, onboarding, primary routes and administration foundation are included, and development fixtures are explicitly labeled. The private development remote and clean-clone recovery have been verified. The items below correctly remain `BLOCKED_EXTERNAL` or later-phase work; adapters, environment variables, fixtures and test accounts keep them from blocking foundation/product-shell implementation.

## Client/service inputs (`BLOCKED_EXTERNAL`)

| Needed | Blocks | Required from client/service owner | Verification when supplied |
|---|---|---|---|
| Production Keycloak host and ownership | Production auth runtime | Canadian-region host/account, hostname, admin ownership | Discovery, login, refresh, logout, failover |
| SMTP sender and DNS | Email verification/reset | Provider credentials, verified sender/domain | New-account verification and password reset receipt |
| Google OAuth clients | Google Sign-In | Web/iOS/Android client IDs/secrets and allowed redirects | New/returning login and account linking |
| Apple developer identity materials | Sign in with Apple | Team ID, Services/App IDs, key ID/private key, return URLs | iOS/web login and relay-email flow |
| Managed PostgreSQL | Production data | Client-owned connection, region, backup/restore policy | Migration, readiness, backup and restore drill |
| Private S3-compatible bucket | Evidence/media | Bucket, endpoint, least-privilege key, lifecycle/region | Multipart upload, private playback, expiry/deletion |
| APNs and Firebase | Push delivery | Apple/Firebase projects, keys, app configs | Send/receive/tap routing on real devices/watch |
| Domain, DNS and TLS | Public web/API/deep links | Registrar/DNS access and approved hostnames | HTTPS, CORS, universal/app links |
| App Store/Play accounts and signing | Release/submission | App Store Connect, Play Console, certificates/keys | Signed archives/AAB and upload validation |
| Approved content/data | Production usefulness | Gym pricing, clubs, events, rules, source links, owners | Admin import/publication and client review |
| Legal/privacy/trademark approvals | Public release | Approved policies, terms, consent wording and marks | Published versions and recorded approval |

## Verification boundaries

- Phase 1 is accepted, paid and closed, as confirmed by the Developer. The remaining
  dependencies here belong to Phase 2 or release verification, not Phase 1 acceptance.
- Client data is expected over the weekend but has not been received/approved.
  This does not block unrelated Phase 2 implementation. Follow `DATA_POLICY.md`;
  initial discipline/division/checklist configuration remains provisional pending
  Client rules. Complete validated import/admin workflows before claiming bulk-data
  replacement is verified.

- iPhone and Apple Watch testing is simulator-only; both remain **NOT DEVICE VERIFIED**.
- Android testing is emulator-only; it remains **NOT DEVICE VERIFIED** despite a successful APK launch and API/database flow.
- The hosted web preview is private and uses no production API/identity/storage configuration; the full system remains **NOT PRODUCTION VERIFIED**.
- CocoaPods is not installed, but the checked-in iOS project uses Flutter Swift Package Manager and builds successfully. Install CocoaPods only if a later plugin requires it.
- Docker is not installed on this host. Phase 1 database verification used a checksum-verified local PostgreSQL 17.11 build; the Compose topology is documented but not claimed as locally executed.
