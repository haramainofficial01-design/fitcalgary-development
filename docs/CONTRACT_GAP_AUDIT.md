# Signed agreement gap audit

Audited 2026-08-31 against `FitCalgary Development Delivery Agreement Final.pdf`, effective 2026-08-30. The signed selection is the Accelerated delivery option. This document is internal engineering evidence; the consolidated Client-facing summary remains the single Phase 1 review PDF.

## Contract controls applied

- The final objective is one agreed V1 across web, iOS, Android and the agreed Apple Watch companion experience.
- Phase 1 is a Foundation acceptance checkpoint, not a separate codebase and not permission to begin the full Phase 2 workflow scope.
- Phase 1 must leave a working, Client-recognizable FitCalgary shell and materially demonstrate onboarding, primary routes, protected administration, client-to-Go-to-PostgreSQL integration, authentication/session and role protection, reproducible migrations, buildable local platforms, security/config handling, automated checks, private Git history and a concise Client review summary.
- Reasonable small refinements needed to finish the agreed V1 properly are included. The restrained Phase 1 modernization therefore preserves the Client identity while improving hierarchy, spacing, surfaces, depth and transitions.
- Missing production credentials, service access, Client-approved content and physical devices extend or bound verification; they must be documented rather than represented as complete.
- The active project and material development history may remain in a Developer-controlled private repository during development. Pre-existing Client materials remain Client property. Complete agreed custom source/history handoff occurs after full payment and final handoff under the agreement.
- Phase 1 is not represented as Client-accepted until the Client approves it in writing or Phase 2 begins without an unresolved material Phase 1 issue.

## Phase 1 contract-gap result

| Contract requirement | Status | Evidence | Remaining boundary |
|---|---|---|---|
| Client repository/source audit and clean VS Code workspace | VERIFIED | Full authenticated read-only clone; Client commit `4c629019f68c3d11709a77f9fea9f3190250ce44`; active monorepo under direct source control | Client remote is never used as the development push destination |
| Available Client/development history preserved | VERIFIED LOCALLY | Client repository contains three genuine commits; active repository preserves the genuine Phase 1 ancestry, original foundation SHA and acceptance-candidate tag; backup bundle verified | Private push/fresh-clone confirmation recorded at the final checkpoint |
| Flutter/Dart clients + Go architecture | VERIFIED | `docs/ARCHITECTURE.md`; production topology excludes the deprecated Node prototype and does not depend on FlutterFlow | Production hosting remains later/external |
| Database/schema/config foundation | VERIFIED | PostgreSQL 17.11 clean and repeat migration, 30 tables, strict environment configuration | Managed production database/secret values are external |
| Authentication/session/roles | VERIFIED IN DEVELOPMENT | Keycloak realm/PKCE configuration, Flutter secure session handling, web BFF session, Go OIDC adapter and role checks; 401/403/200 demonstration | Production Keycloak, SMTP, Google and Apple credentials are external |
| Onboarding and primary navigation | VERIFIED | First-launch/account entry/completion persistence/returning user tests; Home/Gyms/Board/Compete/Me routes on Android and iOS | Deeper business workflows remain Phase 2 |
| Client-recognizable product shell and refinement | VERIFIED | Supplied screenshots, FlutterFlow reference and Client source were compared with the directly maintained Flutter shell; recognizable terminology, hierarchy, coral/monochrome identity, cards and primary sections are present | Final Client content and later polish remain Phase 2/3 |
| API/service contracts | VERIFIED FOUNDATION | Versioned Go contracts for gyms, events, leaderboards, submissions, notifications and administration | Full V1 operational depth remains Phase 2 |
| Role-protected admin dashboard | VERIFIED FOUNDATION | Authenticated responsive dashboard; server-authoritative ADMIN check; unauthenticated 401 and USER 403 | Full CRUD/operations remain Phase 2 |
| iOS, Android, web, watchOS foundations | VERIFIED IN LOCAL SIMULATOR/EMULATOR/BUILD ENVIRONMENTS | Test Matrix records each build/run and the Android release AAB | Physical devices and production signing are not verified |
| Security/config baseline | VERIFIED FOUNDATION | Secret inventory/scan, `.env.example`, strict config, validation, safe errors, protected routes, private-storage structure and audit foundations | Production security/release review remains Phase 3 |
| Flutter -> Go -> PostgreSQL | VERIFIED | Android emulator rendered a PostgreSQL-seeded gym through the Go API; protected profile write/read also persisted | Production environment remains external |
| Dependencies/blockers/Phase 2 path | VERIFIED | `docs/BLOCKERS.md`, `docs/TEST_MATRIX.md`, `docs/PHASE_2_IMPLEMENTATION_PATH.md` | Explicit `PROCEED TO PHASE 2` authorization required |
| Concise Client review package | FINAL QA IN PROGRESS | One four-page PDF plus two focused MP4 candidates; real captures and precise verification terminology are present | Scheduled 2026-09-04 regeneration, visual/privacy review, final commit/tag/push and clean-clone check |

## Phase boundary

No substantial Phase 2 work is authorized by this audit. Existing later-stage foundations are preserved. After Client review and explicit authorization, Phase 2 continues in the same codebase and completes the agreed V1 workflows described in the signed agreement and `docs/PHASE_2_IMPLEMENTATION_PATH.md`.
