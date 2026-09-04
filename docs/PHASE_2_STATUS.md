# Phase 2 — Core Product

Updated: 2026-09-03, America/Edmonton.

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
This increment is not a new iOS/Android/web/watchOS verification or a complete
Phase 2 acceptance run. Existing platform results remain separately recorded.

## Execution path

| Area | Next acceptance evidence | Status |
|---|---|---|
| Gyms, pricing, accounts, saved gyms | Signed-in client browse/detail/compare/save, persisted through Go/PostgreSQL | IN_PROGRESS; production model and foundation exist; complete flow not yet freshly verified |
| Clubs, events, athlete profiles | Search/detail/profile edits and persistence across clients | IN_PROGRESS foundation; deeper flow verification pending |
| Official/community boards | Configured disciplines/divisions, correct ranking and clear verification status | IN_PROGRESS foundation; end-to-end acceptance pending |
| Submission, evidence and judging | Private upload, permissions, comments, decisions, resubmission and ranking publication | IN_PROGRESS foundation; full acceptance pending |
| Administration | Actual content/user/role/review operations with server permission tests | IN_PROGRESS foundation; full CRUD depth pending |
| Notifications and integrations | Persisted state, workflow triggers, configured delivery adapters | IN_PROGRESS foundation; external production credentials pending |
| Cross-platform acceptance | Regression suite plus actual iOS/Android/web/watchOS runs and evidence | PENDING Phase 2 verification |
| Phase 2 Client package | Concise review document, real demo and technical proof after acceptance tests | NOT_STARTED |

Daily sequence: domain/gyms/accounts; clubs/events/profiles; boards/results;
evidence/judging; admin/notifications/platform checks; integrated acceptance QA.
Carry unfinished higher-risk work forward honestly instead of declaring a day's
scope complete because its calendar date passed. Commit logical tested increments
with real timestamps to the private development remote only.

## Dependencies

Approved Client content is expected over the weekend; receipt and approval are not
yet verified. Use isolated development fixtures meanwhile. Final ranking and
verification rules, production identity/social/email/storage/push/signing credentials
and real hardware remain separately tracked in `BLOCKERS.md`. These are later
product/release dependencies, not reopened Phase 1 obligations.
