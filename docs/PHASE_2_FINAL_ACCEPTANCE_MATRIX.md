# FitCalgary Phase 2 final acceptance matrix

Updated 2026-09-07 for the Client-approved catalog integration. This is the
authoritative Phase 2 review matrix. Phase 3 release and store work is not
counted as Phase 2 implementation.

Status vocabulary is intentionally strict:

- **COMPLETE + VERIFIED** means the workflow was exercised locally with the
  current implementation and the evidence is identified below.
- **BLOCKED_EXTERNAL** means the implementation path is present, but final
  verification requires Client credentials, approved data, a provider account,
  physical hardware or a store/hosting dependency.
- **INCOMPLETE** means a material Phase 2 requirement is not implemented or
  tested. No material Phase 2 workflow is currently in this category.

## Required end-to-end scenarios

| # | Requirement | Status | Evidence |
|---|---|---|---|
| 1 | New account, profile, saved gym and reload | COMPLETE + VERIFIED | Flutter widget coverage, Go account/profile/favourite tests, Chrome profile/favourite regression; live production IdP credentials remain BLOCKED_EXTERNAL. |
| 2 | Directory, filters and structured comparison | COMPLETE + VERIFIED | 273 Client-approved gyms imported; public search/area/cost/detail and saved-gym API checks; 120 comparable price rows and no false zero-price rows. |
| 3 | Admin publishes gym/pricing/club/event and client sees it | COMPLETE + VERIFIED | 273 gyms, 743 clubs and 531 competitions visible through public/admin APIs; full source payload retained for provenance. |
| 4 | Community result reaches the correct board and profile | COMPLETE + VERIFIED | Competition SQL projections, Flutter/browser result history and board checks. |
| 5 | Submission -> private evidence -> judge correction -> resubmission -> approval -> verified result -> official rank -> notification | COMPLETE + VERIFIED | Real loop against local PostgreSQL and S3-compatible storage; Chrome workflow and iOS/Android private-evidence client tests. Test media is transport evidence, not a Client athlete record. |
| 6 | Unauthorized account, role and object access is rejected; role revocation is immediate | COMPLETE + VERIFIED | Go authorization/regression tests, browser admin grant/revoke/suspend/restore run, old-token denial and self-escalation denial. |
| 7 | Moderation, notification preferences and delivery queue behavior | COMPLETE + VERIFIED | Account restriction/audit tests, preference and essential-notice tests, outbox retry/deduplication/poison-job limits and inbox checks. Live FCM/APNs delivery is BLOCKED_EXTERNAL. |
| 8 | Consistent athlete/profile/saved/submission/rank state across clients and Watch | COMPLETE + VERIFIED | Shared Go/PostgreSQL contracts; iOS/Android/web workflow runs and watchOS simulator build/status capture. Physical-device parity is BLOCKED_EXTERNAL. |
| 9 | Official and community leaderboards with configurable disciplines/divisions | COMPLETE + VERIFIED | SQL ranking tests cover direction, ties, eligibility, privacy and best-per-athlete projections; browser/mobile captures. |
| 10 | Judge queue, private playback, comments, correction and approval/rejection | COMPLETE + VERIFIED | Go/SQL judge tests, signed private playback, browser review run and Flutter client correction path. |
| 11 | Clubs/events browse, filters, registration and admin publication | COMPLETE + VERIFIED | 743 clubs and 531 competitions imported; search/filter/detail/admin API checks and responsive browser captures. Missing exact dates remain unscheduled while supplied schedule text is preserved. |
| 12 | Athlete profiles, history, personal best and privacy boundaries | COMPLETE + VERIFIED | Profile/history API tests, Flutter profile capture and authorized result-history link checks. |
| 13 | Admin dashboard, roles, moderation, audit and content operations | COMPLETE + VERIFIED | Role-protected dashboard capture, browser CRUD/overview run and server authorization tests. |
| 14 | Notification inbox, preferences, safe destinations and idempotent announcements | COMPLETE + VERIFIED | PostgreSQL-backed outbox/inbox and preferences tests; Flutter notification registration lifecycle widget test. Provider push credentials are BLOCKED_EXTERNAL. |
| 15 | Cross-platform acceptance surfaces | COMPLETE + VERIFIED | Flutter analysis/tests, iOS simulator, Android emulator/AAB, web type/lint/build and watchOS simulator build/run evidence. Real devices and stores are Phase 3/BLOCKED_EXTERNAL. |

## Contract and quality areas

| Area | Status | Evidence / boundary |
|---|---|---|
| Flutter/Dart client and responsive web shell | COMPLETE + VERIFIED | Flutter source, 20 tests, analysis; web typecheck/lint/production build. |
| Go API, validation, safe errors and server authorization | COMPLETE + VERIFIED | `go test ./...`, `go vet ./...`, production build and object/role authorization tests. |
| PostgreSQL schema and reproducible migrations | COMPLETE + VERIFIED | Fresh initialization, migrations 0001-0008, idempotent Client import and read/write tests. |
| Private evidence storage and object access | COMPLETE + VERIFIED | Multipart upload, signed playback, ownership denial, range playback and deletion against local S3-compatible storage. |
| Keycloak OIDC/PKCE, email/social hooks and session architecture | BLOCKED_EXTERNAL | Standards-based adapters and protected-service path are implemented; live Keycloak host, SMTP, Google and Apple credentials are not developer-controlled. |
| Secrets and security baseline | COMPLETE + VERIFIED | Production secrets excluded from source, environment templates, validation, safe error responses, rate/request budgets and audit records. |
| Analytics and operational aggregates | COMPLETE + VERIFIED | Privacy-preserving event/aggregate paths and admin overview evidence; production analytics account remains external. |
| Physical devices, signed archives, hosting and store submission | BLOCKED_EXTERNAL | Simulator/emulator builds are verified; device access, signing accounts, domains, hosting and store review are Phase 3 dependencies. |
| Client-approved catalog | COMPLETE + VERIFIED | All 1,547 supplied JSON records imported with stable source IDs; omitted values remain unknown rather than fabricated. |

## Final position

**INCOMPLETE: none.** Phase 2 is COMPLETE + VERIFIED within developer
control. BLOCKED_EXTERNAL entries are explicitly separated from implementation
completion and belong to production configuration or Client-owned inputs.

Candidate evidence: tested implementation `a8fd0da`; historical package commit
`3f858ba`; status commit `a35e28e`; current ledger reference `5998632`. Final
quality-pass commit: `38983c1353cd39fb4676ddab90d6dd915486b43b`.
The final Client-data integration commit/tag is recorded in the delivery summary.
