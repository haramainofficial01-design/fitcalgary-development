# Phase 2 implementation path

Phase 2 is explicitly authorized. Phase 1 is complete, accepted, fully paid and
closed, as confirmed by the Developer. Continue from the same Flutter/Dart + Go +
PostgreSQL + Keycloak codebase; no foundation or working behavior is restarted,
removed or duplicated. See `PHASE_2_STATUS.md` for current execution.

## Work sequence

1. Complete real-model gym/pricing and account flows using isolated fixtures under `DATA_POLICY.md`. Import approved Client data through validated admin paths when supplied; its absence does not block unrelated work.
2. Complete account recovery, profile depth, saved gyms and social-sign-in production configuration while preserving standards-based OIDC/OAuth 2.0 + PKCE.
3. Complete official/community leaderboard configuration and deterministic ranking publication.
4. Complete submission, private multipart evidence, judge assignment, review, comments, approval/rejection and resubmission workflows end to end.
5. Expand the existing role-protected admin foundation into the agreed CRUD, moderation, audit, analytics and operational workflows.
6. Connect production notification, storage, email, identity and analytics providers through the established adapters.
7. Maintain iOS, Android, web and watchOS parity appropriate to each platform and expand automated/integration coverage with every workflow.

## Acceptance direction

Phase 2 is feature-complete only when the important V1 workflows operate end to end in development/staging, not merely when screens or route placeholders exist. Production configuration, physical-device/release QA and final handoff remain Phase 3 work unless required earlier to prove a Phase 2 workflow.
