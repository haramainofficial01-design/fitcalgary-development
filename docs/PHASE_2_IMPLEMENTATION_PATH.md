# Phase 2 implementation path

Phase 2 begins only after explicit `PROCEED TO PHASE 2` authorization. It continues from the same Flutter/Dart + Go + PostgreSQL + Keycloak codebase; no Phase 1 foundation or working product behavior is restarted, removed or duplicated.

## Work sequence

1. Replace development fixtures with Client-approved gym, pricing, club, event, discipline, division and policy data through import/admin paths.
2. Complete account recovery, profile depth, saved gyms and social-sign-in production configuration while preserving standards-based OIDC/OAuth 2.0 + PKCE.
3. Complete official/community leaderboard configuration and deterministic ranking publication.
4. Complete submission, private multipart evidence, judge assignment, review, comments, approval/rejection and resubmission workflows end to end.
5. Expand the existing role-protected admin foundation into the agreed CRUD, moderation, audit, analytics and operational workflows.
6. Connect production notification, storage, email, identity and analytics providers through the established adapters.
7. Maintain iOS, Android, web and watchOS parity appropriate to each platform and expand automated/integration coverage with every workflow.

## Acceptance direction

Phase 2 is feature-complete only when the important V1 workflows operate end to end in development/staging, not merely when screens or route placeholders exist. Production configuration, physical-device/release QA and final handoff remain Phase 3 work unless required earlier to prove a Phase 2 workflow.
