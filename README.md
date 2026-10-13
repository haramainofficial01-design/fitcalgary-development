# FitCalgary Index

FitCalgary connects fitness discovery, membership comparison, clubs, competitions,
athlete profiles, verified results and content administration in one codebase.

- `apps/web` — public web, account, judge, and admin UI
- `apps/fitcalgary_app` — Flutter iOS and Android application
- `apps/watch` — native SwiftUI watchOS companion
- `services/api-go` — production Go REST API, integrations, and background workers
- `services/api/migrations` — ordered PostgreSQL migrations
- `services/api/src` — archived backend reference; not deployed
- `packages/contracts` — shared API contracts and enums
- `infrastructure` — local PostgreSQL, Keycloak, MinIO, and Mailpit setup
- `data/client-approved` — approved gym, sport-club, and competition catalog sources
- `docs` — architecture, API, security, development, data, and release documentation

See [deployment status](docs/DEPLOYMENT_STATUS.md) before publishing. Source
delivery does not establish live authentication, store approval or physical-device verification.

## Prerequisites

Go 1.27+, Node.js 22.13+, pnpm 11+, Flutter 3.47+, and Docker with Compose 2.30+.
Apple builds require macOS, Xcode 26+, CocoaPods and an authorized signing team.
Android builds require JDK 21 and Android SDK 37+. Put tools on PATH; release
scripts accept explicit tool paths. XcodeGen regenerates standalone Watch and
native navigation test projects.

## Local setup

Copy `.env.example` to an ignored `.env`. Its predictable credentials are
local-only examples, never production credentials. From the repository root:

```sh
docker compose --env-file .env -f infrastructure/docker-compose.yml up -d \
  postgres keycloak minio create-bucket mailpit
set -a
. ./.env
set +a
cd services/api-go
go run ./cmd/migrate
go run ./cmd/api
```

In another terminal, load the same ignored environment and start the website:

```sh
set -a
. ./.env
set +a
cd apps/web
pnpm install --frozen-lockfile
pnpm dev
```

The dashboard is `/admin`; Go enforces its permissions. Provision local test
accounts through Keycloak, not hard-coded access tokens. For Flutter, from
`apps/fitcalgary_app`:

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:4000/api/v1 \
  --dart-define=OIDC_ISSUER=http://localhost:8080/realms/fitcalgary \
  --dart-define=OIDC_CLIENT_ID=fitcalgary-mobile
```

Android emulator access requires host routing or `adb reverse` for ports 4000
and 8080. Development HTTP is forbidden in production builds. Approved native
navigation is enabled on supported iOS; other platforms retain the Flutter fallback.

## Database and verification

Development fixtures require the separate `go run ./cmd/dev-seed` command, explicit
`DEMO_DATA=true` and a new loopback-only development/test database. Production refuses
fixture-marked databases. See the [data policy](docs/DATA_POLICY.md) for setup and approved-data import rules.

Import approved catalog data using `cmd/client-data-import`. Missing prices or
dates must not be invented. The source contains 273 gyms, 743 clubs and 531 competitions.

From `services/api-go`: `go test ./...`, `go vet ./...`, `go build ./cmd/api`.
From `apps/web`: `pnpm install --frozen-lockfile`, `pnpm lint`, `pnpm exec tsc --noEmit`,
`pnpm test:auth`, `pnpm test:deployment`, `pnpm build`.
From `apps/fitcalgary_app`: `flutter pub get`, `flutter analyze`, `flutter test`.
From the root: `bash scripts/test_watch_snapshot.sh` and
`bash scripts/test_release_common.sh`.
Integration tests need explicitly isolated services; skipped checks are not end-to-end verification.

## Releases and deployment

Use `scripts/build_ios_release.sh` for signed iOS with embedded Watch and
`scripts/build_android_release.sh` for signed Android bundles. Supply an ignored
production configuration using `FITCALGARY_PRODUCTION_CONFIG`. Select Flutter
with `FITCALGARY_FLUTTER`; select JDK with `FITCALGARY_JAVA_HOME` or `JAVA_HOME`.
Keep keys and signing passwords outside Git. Read
[store signing](docs/STORE_SIGNING_AND_SUBMISSION.md) before uploading.
The scripts require live API health/readiness and matching HTTPS OIDC discovery
before starting a signed build. These checks do not replace real login/device QA.

The responsive website runs on Cloudflare Workers; its server-side account
routes require more than static hosting. The candidate in `infrastructure/free-vm`
retains PostgreSQL, Keycloak, Go and private evidence storage. Verify account
eligibility and capacity before provisioning. Never upgrade or purchase automatically.

## Operating documentation

See [architecture](docs/ARCHITECTURE.md), [API contract](docs/API_CONTRACT.md),
[development](docs/DEVELOPMENT.md), [security](docs/SECURITY_BASELINE.md),
[production configuration](docs/PRODUCTION_CONFIGURATION.md),
[database operations](docs/DATABASE_OPERATIONS.md),
[operations runbook](docs/OPERATIONS_RUNBOOK.md),
[handoff](docs/HANDOFF.md) and [release checklist](docs/FINAL_RELEASE_CHECKLIST.md).
Preserve licences and Client-material provenance. Never commit credentials,
private evidence, user exports or production database backups.
