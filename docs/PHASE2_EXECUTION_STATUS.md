# Phase 2 execution ledger

Updated 2026-09-07 after importing and verifying the Client-approved catalog.

## Current position

**PHASE 2: COMPLETE + VERIFIED within Developer control.** Phase 1 is closed.
Phase 3 release configuration, store submission and physical-device work are
not being represented as complete and are not started by this pass.

The authoritative requirement-by-requirement matrix is
[`PHASE_2_FINAL_ACCEPTANCE_MATRIX.md`](PHASE_2_FINAL_ACCEPTANCE_MATRIX.md).

## COMPLETE + VERIFIED

- Flutter/Dart product shell, navigation, directory, pricing comparison,
  favourites, clubs, events, profiles, official/community boards and result
  history are connected to the Go/PostgreSQL service path.
- The central submission workflow is verified with local PostgreSQL and
  S3-compatible private storage: submission, private evidence, correction,
  resubmission, approval, verified result, official placement and inbox notice.
- Judge queue/actions, moderation, audit records, role grant/revoke/restore,
  immediate account restriction and self-escalation denial are server-tested.
- Notification preferences, inbox/outbox behavior, retry/deduplication,
  device registration lifecycle and safe deep-link destinations are tested.
- Flutter analysis/tests, Go tests/vet/build, PostgreSQL initialization and
  migration/read-write checks, web type/lint/production build, iOS simulator,
  Android emulator/release AAB and watchOS simulator build/run evidence exist.
- Client Review PDF, polished Client Demo and Technical Proof are regenerated
  at the paths listed below and visually inspected.
- Client-approved data is imported through a reproducible, idempotent path:
  273 gyms, 743 clubs and 531 competitions (1,547 source records total).

## BLOCKED_EXTERNAL

- Production Keycloak host/SMTP and Google/Apple identity credentials.
- FCM/APNs provider credentials and production notification delivery.
- Hosting, database, private-storage, domain/DNS/TLS and store accounts.
- Physical-device access and store review/signing approval.

These are explicitly external or Phase 3 release dependencies. They do not
represent unfinished Phase 2 implementation.

## NOT STARTED - Phase 3 only

Signed production archives, physical-device regression, production deployment,
store submission, final public-release cleanliness audit and handoff transfer.

## Package and Git evidence

- PDF: `client-review/phase-2/FitCalgary_Phase_2_Client_Review.pdf`
- Client Demo: `client-review/phase-2/FitCalgary_Phase_2_Client_Demo.mp4`
- Technical Proof: `client-review/phase-2/FitCalgary_Phase_2_Technical_Proof.mp4`
- Previous tested implementation: `a8fd0da`
- Previous package/status refs: `3f858ba`, `a35e28e`, `5998632`
- Previous quality-pass commit: `38983c1353cd39fb4676ddab90d6dd915486b43b`
- Final Client-data checkpoint: recorded by the final task commit and tag.

## Resume rule

Do not start Phase 3 from this ledger without explicit authorization. If a
future Phase 3 continuation occurs, begin with production configuration and
release verification, not new Phase 2 feature work.
