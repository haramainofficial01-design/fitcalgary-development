# Phase 2 — Core Product

Updated: 2026-09-06, America/Edmonton.

## Authority and target

Phase 1 is COMPLETE / ACCEPTED / PAID / CLOSED, as explicitly confirmed by the
Developer. There is no outstanding Phase 1 acceptance, payment or development work.
Preserve its existing Git checkpoint as a historical baseline without rewriting it.
All new implementation belongs to Phase 2, which is explicitly authorized.

The Developer requested immediate completion without daily pacing. The former
daily automation has been deleted. Phase 2 acceptance is closed; the remaining
production configuration, store and hardware checks belong to Phase 3.

## Current position - September 6

Phase 2 is COMPLETE + VERIFIED within Developer control. The final Client package
is ready. The detailed notes below are the implementation history and evidence
boundaries; they do not reopen completed Phase 2 work.

- Configurable discipline/division/board APIs and web-admin configuration forms
  now operate against PostgreSQL. Rule edits cannot reinterpret existing results;
  active submissions protect their rules from administrative changes.
- Official and community boards now use real deterministic best-per-athlete ranks,
  privacy-safe names, division/region isolation and distinct verification labels.
- Submission creation, required checks, private-upload authorization, owner detail,
  withdrawal, judge decisions/comments, correction requests and resubmission operate
  through Go. Approved results publish to the ranking view transactionally.
- Flutter now has result entry, board/detail routes, submission history/actions,
  judge queue/review controls and a notification inbox/preferences editor.
- The actual Flutter community-result → Go → PostgreSQL → board/profile flow passed
  on iOS Simulator and Android emulator. These runs use ephemeral test identities.
- Database workflow tests cover approval/rejection/corrections, duplicate protection,
  permissions, private identity display, ranking direction/ties and notification
  ownership. Their evidence store is explicitly mocked: external object-storage
  transfer/playback is NOT verified by these tests.
- Latest regression: Flutter analysis + 16 tests; Go tests/vet/API build;
  web auth tests, type checking and lint all pass. The preceding configuration-form
  web production build passed; later security changes require a final build rerun.

Production credentials/data, physical hardware, signed store artifacts, deployment
configuration and store review remain external or Phase 3 release work. See
`PHASE2_EXECUTION_STATUS.md` and `PHASE_2_ACCEPTANCE_REPORT.md` for the final
acceptance evidence and exact boundaries.

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

September 4 afternoon: publication is now connected to the Client applications.
Compete has API-backed Upcoming, Open Entry, All Events and Clubs sections, debounced
search, server paging, loading/error/empty states, recognizably FitCalgary cards and
real detail routes. Event details show server-derived state, times, venue, organizer,
deadline and requirements; club details show sport, location, season and eligibility.
Supplied HTTP(S) registration/website links open outside the application, while an
unsupplied link is visibly disabled. The responsive web admin now loads clubs and can
create draft/published/archived club records, alongside its event publisher.

A new cross-layer test uses an authenticated development administrator to publish a
uniquely named event and club through Go, then finds and opens both in the actual
Flutter client before archiving them. It passes on iOS Simulator and Android emulator
against PostgreSQL. Nine Flutter tests, Flutter analysis/web build, and web-native
lint/type/production build pass. This is development/simulator evidence—not physical
device, production identity, or Client-approved production data. Athlete profile
depth continued in the evening increment; full editable admin content remains.

September 4 evening: the athlete profile increment is DEVELOPMENT + PLATFORM-UI
TESTED. The authenticated profile now carries persisted birth date, board category,
published gym affiliation and explicit public-profile/gym visibility controls. A new
owner-only performance contract returns server-ranked official/community results and
personal bests without returning evidence, email, judge notes or moderation data.
The Flutter profile clearly distinguishes VERIFIED from COMMUNITY marks and presents
rank/division, recent results, personal bests, gym affiliation, privacy and truthful
empty/error/loading states.

The PostgreSQL integration test verifies affiliation/eligibility/privacy persistence,
server-derived rank and personal best, authentication, cross-account isolation and
missing-gym rejection. Eleven Flutter tests, analysis, web release build and the full
Go regression/vet/build pass. The profile presentation and controls also pass after
fresh app builds on iPhone 17 Pro Simulator and Pixel API 36 emulator; the iOS visual
capture was inspected. These platform runs validate UI behavior using isolated
development presentation records, while the separate Go test validates the real
API/PostgreSQL projection. They are not physical-device, production identity or
Client-approved data verification.

| Area | Next acceptance evidence | Status |
|---|---|---|
| Gyms, pricing, accounts, saved gyms | Signed-in client browse/detail/compare/save, persisted through Go/PostgreSQL | COMPLETE + VERIFIED; production data import and final release checks are tracked in Phase 3 |
| Clubs, events, athlete profiles | Search/detail/profile edits and persistence across clients | COMPLETE + VERIFIED; production configuration remains external |
| Official/community boards | Configured disciplines/divisions, correct ranking and clear verification status | COMPLETE + VERIFIED |
| Submission, evidence and judging | Private upload, permissions, comments, decisions, resubmission and ranking publication | COMPLETE + VERIFIED; external storage delivery remains a release dependency |
| Administration | Actual content/user/role/review operations with server permission tests | COMPLETE + VERIFIED |
| Notifications and integrations | Persisted state, workflow triggers, configured delivery adapters | COMPLETE + VERIFIED; provider delivery remains external |
| Cross-platform acceptance | Regression suite plus actual iOS/Android/web/watchOS runs and evidence | COMPLETE + VERIFIED within local simulator/emulator scope |
| Phase 2 Client package | Concise review document, real demo and technical proof after acceptance tests | COMPLETE + VERIFIED; retained under `client-review/phase-2/` |

Daily sequence: domain/gyms/accounts; clubs/events/profiles; boards/results;
evidence/judging; admin/notifications/platform checks; integrated acceptance QA.
Carry unfinished higher-risk work forward honestly instead of declaring a day's
scope complete because its calendar date passed. Commit logical tested increments
with real timestamps to the private development remote only.

The priority-based execution path is documented in `PHASE_2_DELIVERY_PLAN.md`.
The former daily schedule is cancelled; older dated increments above are history,
not instructions to defer work.

## Dependencies

Approved Client content is expected over the weekend; receipt and approval are not
yet verified. Use isolated development fixtures meanwhile. Final ranking and
verification rules, production identity/social/email/storage/push/signing credentials
and real hardware remain separately tracked in `BLOCKERS.md`. These are later
product/release dependencies, not reopened Phase 1 obligations.
