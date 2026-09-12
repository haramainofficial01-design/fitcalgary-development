# External dependencies

These are release inputs, not missing application functionality. The source,
adapters, validation and local verification paths are maintained in the project.

| Service / input | Required from Client or operator | Ready in source | Release verification still needed |
|---|---|---|---|
| Hosting and DNS/TLS | Production host, domain, DNS and certificate access | Docker/API/web deployment structure | Deploy and verify public HTTPS endpoints |
| PostgreSQL | Managed production database and backup/PITR access | Migrations, guards, import and operations docs | Clean production migration/import and restore drill |
| Keycloak | Production realm host, bootstrap/admin access and secret storage | Realm JSON, OIDC/PKCE clients, role mapping | Registration, verification, reset and session checks |
| SMTP/email | Verified sender and provider credentials | Keycloak email flows and environment map | Registration/reset/verification delivery |
| Google Sign-In | Google OAuth client IDs/secrets and consent configuration | Keycloak broker hook | Live broker login and account linking |
| Sign in with Apple | Apple team/key/service configuration | Keycloak broker hook | Live broker login and relay-email behavior |
| Object storage | Production private bucket, credentials and lifecycle policy | S3 multipart/sign/playback adapter and retention worker | Upload/playback/retention against production bucket |
| Push notifications | Firebase/FCM and APNs credentials | Outbox, retry, encrypted token storage, provider adapter | Real-device delivery and token invalidation |
| Apple Developer / App Store Connect | Team, signing, certificates and store access | iOS project, entitlements and release settings | Signed archive and submission metadata |
| Google Play Console | Developer account and upload key | Android project and release AAB path | Signed bundle upload and review metadata |
| Physical devices | Representative iPhone, Android phone and Apple Watch | Simulator/emulator paths and test coverage | Hardware QA for network, notifications, media and deep links |
| Legal/business content | Approved privacy, terms, support contact and store business details | Technical privacy/data map and templates | Final approval and publication |
