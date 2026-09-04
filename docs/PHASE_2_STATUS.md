# Phase 2 — Core Product

Updated: 2026-09-04 morning, America/Edmonton.

## Authority and target

Phase 1 is COMPLETE / ACCEPTED / PAID / CLOSED, as explicitly confirmed by the
Developer. There is no outstanding Phase 1 acceptance, payment or development work.
Preserve its existing Git checkpoint as a historical baseline without rewriting it.
All new implementation belongs to Phase 2, which is explicitly authorized.

September 8 is the internal Phase 2 acceptance-candidate target, not an automatic
completion date. Substantial Phase 3 work still requires explicit authorization.

## Current verified increment

Development-data isolation is IMPLEMENTED / DEVELOPMENT TESTED:

- A separate opt-in fixture loader uses the real PostgreSQL schema and pricing model.
- Production refuses fixture-enabled configuration and fixture-marked databases.
- Existing records cannot be silently mixed with the synthetic directory seed.
- Actual Go public routes read seeded gyms, clubs and events; search/category tests
  operate against PostgreSQL. No fabricated official leaderboard results are seeded.
- Go tests, vet and API build pass. A disposable PostgreSQL 17.11 database passed
  migrations, repeat loading, existing-data refusal and API-response integration checks.

Evidence: `cmd/dev-seed/main_test.go`, `internal/config/config_test.go`,
`internal/db/data_guard_test.go` under `services/api-go`; see `DATA_POLICY.md`.
The September 3 gym/account increment additionally implements server-side directory
search, area/category/amenity/price filters, sorting and pagination; API-backed gym
details and two/three-gym comparison; owner-scoped saved gyms; and persisted profile
edits. Current normalized ongoing/year-one pricing is distinguished from incomplete
plans. Additive migration `0002` adds membership terms and effective-date metadata;
the migrator now applies ordered, checksum-verified migrations under one transaction
and advisory lock, preserving existing data.

Seven Flutter tests, analysis, Go regression/vet/build and real PostgreSQL
directory/account/admin-permission tests pass. The complete mobile flow passes on
iOS Simulator and Android emulator, including a unique profile edit after full
client-state reload. An initial recording exposed a keyboard-obscured save button;
the editor is now scrollable and the final recorded iOS and Android runs pass.
Android in-process screenshot capture stalled emulator input; removing that capture
mechanism allowed the unchanged business flow to pass. Use external Android capture.

These tests use ephemeral development identities and actual Go/PostgreSQL data,
not live production Keycloak/social authentication. Full Phase 2 acceptance and a
new watchOS regression remain ahead; older platform evidence is separately recorded.

## Execution path

September 4 morning: the club/event service increment is DEVELOPMENT TESTED.
Administrators can create, edit, publish, unpublish and archive club/event records
using the existing production schema. Each mutation and audit entry commits in one
transaction; forced audit failure rolls the content write back. Public detail routes
hide drafts/archives and support city-qualified slugs. List routes search/filter/page
on the server and retain totals even beyond the last page. Event state is derived
from dates with cancellation/postponement taking precedence; open-entry filtering
excludes cancelled events and expired registration. Timestamp and link validation,
normal-user rejection, publication visibility and atomic rollback passed against
both an existing and a newly initialized disposable PostgreSQL database.

This is the morning backend increment, NOT completion of September 4's full scope.
Next: connect clubs and detailed event routes in Flutter/web; implement the matching
admin forms; extend gym-affiliation/profile presentation; verify publication through
actual client UI and rerun iOS/Android routes. No new platform verification is claimed
for these endpoints yet. No new external blocker was encountered this morning.

| Area | Next acceptance evidence | Status |
|---|---|---|
| Gyms, pricing, accounts, saved gyms | Signed-in client browse/detail/compare/save, persisted through Go/PostgreSQL | TESTED increment; final content, broader comparison UX and web-native parity remain Phase 2 work |
| Clubs, events, athlete profiles | Search/detail/profile edits and persistence across clients | IN_PROGRESS foundation; deeper flow verification pending |
| Official/community boards | Configured disciplines/divisions, correct ranking and clear verification status | IN_PROGRESS foundation; end-to-end acceptance pending |
| Submission, evidence and judging | Private upload, permissions, comments, decisions, resubmission and ranking publication | IN_PROGRESS foundation; full acceptance pending |
| Administration | Actual content/user/role/review operations with server permission tests | IN_PROGRESS foundation; full CRUD depth pending |
| Notifications and integrations | Persisted state, workflow triggers, configured delivery adapters | IN_PROGRESS foundation; external production credentials pending |
| Cross-platform acceptance | Regression suite plus actual iOS/Android/web/watchOS runs and evidence | PENDING Phase 2 verification |
| Phase 2 Client package | Concise review document, real demo and technical proof after acceptance tests | PLANNED; increment screenshots captured, final package not yet produced |

Daily sequence: domain/gyms/accounts; clubs/events/profiles; boards/results;
evidence/judging; admin/notifications/platform checks; integrated acceptance QA.
Carry unfinished higher-risk work forward honestly instead of declaring a day's
scope complete because its calendar date passed. Commit logical tested increments
with real timestamps to the private development remote only.

The dated work split, three daily blocks and September 8 complete-package target
are documented in `PHASE_2_DELIVERY_PLAN.md`. Flag schedule risk promptly; a
scheduled run or target date does not guarantee product acceptance.

## Dependencies

Approved Client content is expected over the weekend; receipt and approval are not
yet verified. Use isolated development fixtures meanwhile. Final ranking and
verification rules, production identity/social/email/storage/push/signing credentials
and real hardware remain separately tracked in `BLOCKERS.md`. These are later
product/release dependencies, not reopened Phase 1 obligations.
