# Current progress

Last updated: 2026-09-05 (America/Edmonton).

## Latest verified continuation

Consumer web home placeholders have been replaced by the read-only Go-backed
directory. Search, paging, retry/empty states and gym/event/board detail routes are
implemented. Chrome acceptance verifies actual published gym search and normalized
pricing, with mobile layout and missing-record behavior. Web type/lint/build and
six unit tests pass. This is not yet full authenticated web workflow parity.

Visual direction is being implemented without changing the brand: layered web
listing cards, floating mobile dock, restrained hover feedback and contrast/motion
fallbacks; Flutter floating navigation with selective Apple translucency and opaque
Android elevation. Adaptive material tests and the updated iOS profile simulator
scenario pass. Major-screen and watch polish are still in progress.

Role restrictions now have PostgreSQL-backed lifecycle regression coverage:
existing token, simulated refreshed/re-login tokens with the same subject and
provider role claim, repeated revocation, legitimate restoration, self-escalation
rejection, and matching effective roles from `/profile` and `/auth/context`.
These checks verify application enforcement; they do not claim a live production
Keycloak token exchange. Dashboard browser tests also exercised grant/revoke
against the running Go service and PostgreSQL. Cross-platform lifecycle UI
verification remains open before closing the entire role-restriction work item.

Phase 2 presentation cleanup is underway: consumer sign-in wording and workflow
errors no longer expose identity-provider details or raw backend diagnostics.
The remaining major-screen refinement must preserve cream/black/red editorial
identity while adding restrained adaptive layered surfaces and accessible motion.
Reduced-motion/readability fallbacks are required. Phase 3 retains the comprehensive
production, store, screenshot and release-configuration audit; this is not being
represented as completed release verification.

The daily development automation has been deleted at the Developer's request.
Continue immediately and finish as early as verification permits. Phase 2 is NOT
yet feature-complete and the final Client review package has not been generated.

Real configured boards, result entry, submission/judge/correction workflows,
configuration administration and notification inbox/preferences are implemented.
The result-entry → Go/PostgreSQL → board/profile scenario passed on iOS Simulator
and Android emulator. Latest checks: Flutter analysis/16 tests, Go tests/vet/build,
web auth/type/lint. Judge/upload transaction tests use mocked storage explicitly.
See the September 5 entry in `TEST_MATRIX.md` for precise evidence boundaries.

Next: operational admin and web parity, real evidence transport/judging,
notification delivery, complete platform regression and final review artifacts.
Historical checkpoints below remain valid but do not describe all current changes.

## Current phase

Phase 2 — Core Product, explicitly authorized and in progress.

Phase 1 is COMPLETE / ACCEPTED / FULLY PAID / CLOSED, as explicitly confirmed
by the Developer. There are no pending Phase 1 development, acceptance or payment
items. Its existing Git checkpoint remains an unchanged historical baseline.

## Completed

- Flutter/Dart product shell reflecting the supplied FitCalgary direction.
- First-launch onboarding with persisted completion and returning-user behavior.
- Primary Home, Gyms, Board, Compete, Me, authentication and administration routes.
- Responsive, authenticated admin dashboard foundation with server-side role protection.
- Versioned Go API, PostgreSQL schema/migrations, Keycloak configuration, validation/error handling and security baseline.
- iOS Simulator, Android emulator, Flutter web and watchOS Simulator build/run foundations.
- Authentic local Git history, foundation snapshot and acceptance-candidate tag preserved.

## Currently working

- September 4: club/event publishing services now pass real-database CRUD,
  visibility, filtering, permission and audit-rollback tests. The Flutter Compete
  directory/detail routes and web-admin club creator are integrated. An admin publish
  → Go/PostgreSQL → Flutter event/club scenario passes on both mobile simulators.
  Athlete profile eligibility, gym/privacy editing, server-ranked performance and
  visually distinct verified/community history now pass database, widget, iOS
  Simulator and Android emulator checks. Ranking/result workflows are next.

- Phase 2 API-backed gym directory/detail/comparison, saved gyms and profile persistence.
- Separate opt-in fixture loader and production data guards are implemented/tested.
- See `PHASE_2_STATUS.md` for scope, `DATA_POLICY.md` for data boundaries and
  `PHASE_2_DELIVERY_PLAN.md` for the September 4–8 work blocks and complete-package target.

## In progress

- Remaining Phase 2 Core Product workflows; next focus is configurable boards and results.
- Production credentials/data and physical-device verification remain explicitly external/later.

## Tested

- Flutter analysis and 11 widget/product tests; directory/account/profile flows passed
  on iOS Simulator and Android emulator using an ephemeral identity and real Go/PostgreSQL.
- Android and iOS onboarding/primary-route integration demonstrations.
- Go tests, vet, production build and role authorization tests.
- PostgreSQL 17.11 clean/repeat initialization, 30-table schema and API read/write path.
- iOS Simulator build/launch; Android emulator build/launch and release AAB; Flutter web release; web lint/type/build/runtime; watchOS Simulator build/launch.
- Unauthenticated admin request `401`, `USER` request `403`, `ADMIN` request `200`.

## Blocked external

Production identity/email/social credentials; managed hosting/database/storage; APNs/FCM; domains/DNS/TLS; signing/store accounts; physical devices; approved production content/rules/legal materials.

## Latest private Git commit

Latest verified implementation push:
`3833a3889e25d64e970760e7fd646cebb89b2293` — September 4 evening athlete profile
performance, eligibility, gym and privacy increment. Private remote `main` matched
the documentation checkpoint `862f45c4fb3f171a529a0cd6d8ec561473be1b50`.

## Latest tested commit

`3833a38` — September 4 evening athlete profile performance, eligibility, gym and
privacy controls; checks are recorded in `TEST_MATRIX.md`.

`47ea8ffcdf88df2c3f0d3ae7e35fe3d2bfd9dcfa` — September 4 afternoon
Client integration: Flutter analysis/nine tests/web build, iOS and Android
admin-publication-to-client flows, and web-native lint/type/production build passed.

Morning service checkpoint:

`384b115718eb1392f0e643c6075080686d6e9c0a` — September 4 morning club/event
service increment: Go tests/vet/build, clean PostgreSQL initialization,
publication/permissions/atomic-audit rollback and gym/account regressions passed.
Flutter baseline analysis and seven tests passed; new content client flows remain
to be integrated and verified in the next blocks.

Previous mobile-tested increment:

`58a2d1469a040c1f2e1d1692f5eb1d2eb71bdb6e` — Phase 2 gym/account increment:
Flutter analysis/seven tests, iOS recorded integration, Android integration,
Flutter web build, Go tests/vet/API build and PostgreSQL directory/account/
membership/authorization checks passed. Phase 1 tag remains unchanged.

Historical full-platform foundation:

`e66e12646974f526e3760f102acdcac3a94ee6d7` — active workspace verified with Flutter analysis/tests, Go tests/vet/build, web lint/type/auth/build, PostgreSQL migration/API read-write checks and all platform simulator/emulator builds and launches.

On 2026-09-01 the Phase 1 PDF and both MP4 files passed layout, playback, privacy
and claim-boundary review. They remain historical evidence of the closed milestone.
The September 3 Phase 2 gym/account increment additionally passed fresh PostgreSQL
membership migration/directory/account tests and actual mobile integration runs.
See `TEST_MATRIX.md` for exact verification boundaries and post-fix reruns.

## Platform status

| Platform | Status |
|---|---|
| iOS | SIMULATOR VERIFIED; NOT DEVICE VERIFIED |
| Android | EMULATOR VERIFIED; release AAB built; NOT DEVICE VERIFIED |
| Web | LOCAL BUILD + RUNTIME VERIFIED; NOT PRODUCTION VERIFIED |
| watchOS | SIMULATOR VERIFIED; NOT DEVICE VERIFIED |

## Onboarding

PASS — first launch, progression, completion persistence, returning-user bypass and authentication entry routes verified.

## Routing

PASS — Home, Gyms, Board, Compete, Me, onboarding, authentication and admin routes verified; Phase 2 actions use controlled next-step states rather than broken primary navigation.

## Admin

PASS — responsive dashboard, overview/navigation, loading/error states and API integration foundation verified; backend role enforcement produced `401`/`403`/`200` as expected.

## Backend

PASS — Go tests, vet and production build; versioned service contracts and protected-service pattern verified.

## Database

PASS — PostgreSQL 17.11, reproducible migration, 30 tables and live API read/write path verified.
