# FitCalgary Index

FitCalgary Index is a Calgary-first fitness discovery, transparent gym-pricing, events, and verified-performance platform. This repository contains the connected product source:

- `apps/web` — public web, account, judge, and admin UI
- `apps/fitcalgary_app` — Flutter iOS and Android application
- `apps/watch` — native SwiftUI watchOS companion
- `services/api-go` — production Go REST API, integrations, and background workers
- `services/api` — archived TypeScript reference implementation; not deployed
- `packages/contracts` — shared API contracts and enums
- `infrastructure` — local PostgreSQL, Keycloak, MinIO, and Mailpit setup
- `data/client-approved` — approved gym, sport-club, and competition catalog sources
- `docs` — architecture, API, security, development, data, and release documentation

## Local quick start

Prerequisites: Go 1.27+, Node.js 22+ and pnpm 11+ for the web workspace, Docker Desktop, Flutter 3.47+, Xcode 26+, JDK 21, and Android SDK 36+.

1. Copy `.env.example` to `.env` and review non-secret defaults.
2. Start local infrastructure with `docker compose -f infrastructure/docker-compose.yml up -d`.
3. From `services/api-go`, apply migrations with `go run ./cmd/migrate`, then start the API with `go run ./cmd/api`.
4. Start web with `pnpm --dir apps/web dev`.
5. Run mobile with `flutter run` from `apps/fitcalgary_app`.

Development fixtures require the separate `go run ./cmd/dev-seed` command, explicit
`DEMO_DATA=true` and a new loopback-only development/test database. Production refuses
fixture-marked databases. See the [data policy](docs/DATA_POLICY.md) for setup and approved-data import rules.

See the [architecture](docs/ARCHITECTURE.md), [API contract](docs/API_CONTRACT.md), [development guide](docs/DEVELOPMENT.md), [security baseline](docs/SECURITY_BASELINE.md), [implementation status](docs/IMPLEMENTATION_STATUS.md), [production configuration](docs/PRODUCTION_CONFIGURATION.md), [database operations](docs/DATABASE_OPERATIONS.md), [operations runbook](docs/OPERATIONS_RUNBOOK.md), and [release checklist](docs/FINAL_RELEASE_CHECKLIST.md).
