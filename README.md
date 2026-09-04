# FitCalgary Index

FitCalgary Index is a Calgary-first fitness discovery, transparent gym-pricing, events, and verified-performance platform. This repository contains one connected product surface:

- `apps/web` — public web, account, judge, and admin UI
- `apps/fitcalgary_app` — Flutter iOS and Android application
- `apps/watch` — native SwiftUI watchOS companion
- `services/api-go` — production Go REST API, integrations, and background workers
- `services/api` — frozen TypeScript prototype retained temporarily for migration reference; not deployed
- `packages/contracts` — shared API contracts and enums
- `infrastructure` — local PostgreSQL, Keycloak, MinIO, and Mailpit setup
- `docs`, `legal`, `data/templates` — operations, release, legal drafts, and import formats

## Local quick start

Prerequisites: Go 1.27+, Node.js 22+ and pnpm 11+ for the web workspace, Docker Desktop, Flutter 3.47+, Xcode 26+, JDK 21, and Android SDK 36+.

1. Copy `.env.example` to `.env` and review non-secret defaults.
2. Start local infrastructure with `docker compose -f infrastructure/docker-compose.yml up -d`.
3. Apply the authoritative migration with `go run ./cmd/migrate`, then start the production API from `services/api-go` using its README.
4. Start web with `pnpm --dir apps/web dev`.
5. Run mobile with `flutter run` from `apps/fitcalgary_app`.

Development fixtures require the separate `go run ./cmd/dev-seed` command, explicit
`DEMO_DATA=true` and a new loopback-only development/test database. Production refuses
fixture-marked databases. See [data policy](docs/DATA_POLICY.md) for setup and approved-data
replacement rules, and [Phase 2 status](docs/PHASE_2_STATUS.md) for current work.

See [architecture](docs/ARCHITECTURE.md), [API contract](docs/API_CONTRACT.md), [Phase 1 report](docs/PHASE_1_ACCEPTANCE_REPORT.md), [test matrix](docs/TEST_MATRIX.md), [blockers](docs/BLOCKERS.md), and [implementation status](docs/IMPLEMENTATION_STATUS.md).
