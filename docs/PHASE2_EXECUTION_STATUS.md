# Phase 2 execution ledger

Updated 2026-09-06. Phase 1 ACCEPTED / PAID / CLOSED. Phase 2 authorized and
IN PROGRESS. No daily pacing; automation cancelled. No Phase 3 authorization.

## Resume contract

Read the Phase 2 master brief, this ledger, Git status/history and current source
before resuming. Continue independent work after each tested increment. Do not
declare acceptance from partial tests. Preserve the five pre-existing modified
Phase 1 package/build-script files; they are not part of current changes.

Master brief: supplied Phase 2 specification (sections 0–39); later execution,
presentation-cleanup and dimensional-design clarifications take precedence over
its obsolete daily schedule. Technical test details remain in TEST_MATRIX.md.

## COMPLETE + VERIFIED — bounded evidence, not whole-phase acceptance

- Repository continuity, private history: current private main `5ffb124`; prior `30066fe`,
  `54fc23b`, `ee59ff9`. No Client-repository push or history rewrite.
- Flutter directory/detail/comparison/favourites/profile persistence: earlier real
  iOS/Android → Go → PostgreSQL tests. Structured normalized ongoing/year-one prices.
- Club/event create/edit/publication/archive, public visibility and validation:
  real SQL tests and mobile publication-to-client tests; browser admin CRUD passes.
- Configured discipline/division/board services, direction/tie/eligibility/privacy
  rules and best-per-athlete official/community projections: SQL regression passes.
- Community results: real mobile and browser → Go → PostgreSQL → board/profile tests.
- Submission/review/correction/approval/ranking transactions: Go/SQL tests pass
  against real private S3-compatible storage. Chrome official upload → playable
  private evidence → correction/resubmission → approval → official board → inbox
  PASS (September 6). Synthetic transport clip, not a genuine athlete performance.
  Flutter real-storage/client loop also PASS on iOS Simulator and Android emulator
  (September 6). OS file picker and identity supplied by test boundaries; actual
  Flutter form, local file, multipart transport, Go/SQL and storage used. Judge
  correction/approval called through API; browser judge UI independently verified.
  Practical large-file acceptance remains open.
- Roles: per-request local restrictions override old/new provider claims; restore,
  repeat revoke, self-escalation denial; account role endpoints agree. Browser
  grant/revoke passes. Refreshed/re-login identity in SQL tests is simulated.
- Web directory/search/detail/retry, profile/preferences, favourites and logout:
  real Chrome/Go/PostgreSQL regression at `30066fe`. Sign-in targets profile.
- Go automated tests/vet/build, Flutter analysis/19 tests, web type/lint/build and
  six unit tests passed at their latest increments. Not a final candidate run.
- Updated Flutter profile shell: iOS Simulator + Android emulator build/run PASS,
  using isolated presentation records. Adaptive-surface accessibility tests pass.
- Isolated opt-in fixtures, production fixture guards, additive migrations 0001–0005,
  protected APIs, safe errors and object-access SQL tests established/tested.

## IN PROGRESS — complete acceptance checklist grouped by master section

| Brief | Remaining acceptance work |
|---|---|
| 0–2 Continuity/domain | Recheck final domain coverage/constraints and clean initialization with all final migrations; maintain authentic commits |
| 3 Accounts/auth | Live local Keycloak registration/verification/reset/session/logout where feasible; full platform restoration, correct social hints; profile-photo/affiliation coverage; role UX across clients |
| 4 Gym index | Final search/filter/sort/comparison/data-freshness coverage, especially web comparison and full filters; cross-session favourites regression |
| 5 Clubs | Consumer web clubs browse/filter/detail; final platform/publication acceptance |
| 6 Events | Web status/filter/registration fidelity and assets; final cancellation/completed/empty states |
| 7 Profiles | Web result/PB/recent history and affiliation/category editing; optional safe photo/social links per supplied scope; no private data leakage |
| 8 Boards | Complete web filters/paging, mobile filter persistence, movement from real history, all category/age/direction edge cases |
| 9 Submissions | Full Flutter and web entry/status/correction flows; official web upload; real retry/cancel/large-file practical test |
| 10 Evidence | Actual private S3-compatible bytes and playback; unauthorized/expired links; retention deletion while retaining result; test practical size ceiling |
| 11 Judging | Web review queue/detail/private playback/comments/actions, Flutter real evidence review, safe assignment and next-item productivity |
| 12 Moderation | Account suspension/reactivation, notes/audit, abuse/rate controls and tested permissions |
| 13 Admin | Account moderation, review exception controls, notification operations, media where applicable, confirmation and comprehensive audit visibility |
| 14 Notifications | Outbox-to-inbox end-to-end, preferences enforced, delivery adapters/device registration, safe deep links; actual provider verification distinguished |
| 15 Analytics | Privacy-preserving event collection + useful operational admin aggregates; no secrets/evidence in telemetry |
| 16–20 Platforms | Full shared-state workflow regressions on iOS/Android/web and Watch companion; Android AAB; web viewport/back/keyboard; Watch auth/status/recent results/stale/no-account states |
| 21–24 Quality | Full role matrix USER/MODERATOR/TRAINER/JUDGE/ADMIN, object authorization, safe errors, bounded requests/rate limiting, clean schema, loading/empty/offline/expired session |
| 25 Value-adds | PB exists on mobile; complete real movement/share presentation/recent activity/smart defaults/safe social links/judge productivity/audit/feedback/deep links/data freshness where applicable; no unapproved monetization |
| 27–28 Tests | Final complete automated and end-to-end acceptance run, not merely increment tests |
| 29 Git | Final tested candidate commit/tag and private remote verification after all acceptance gates |
| 33–39 Acceptance | Requirement-by-requirement final audit; complete proof package, truthful boundaries, stop for Phase 2 Client review |

### Required end-to-end scenarios (do not infer PASS)

1. New account → profile → saved gym → reload: portions tested; local identity flow pending.
2. Directory → filters → structured comparison: mobile tested; full web pending.
3. Admin publishes gym/pricing/club/event → client sees correct data: tested increments; final pass pending.
4. Community result → correct board/profile: mobile/web tested.
5. **Athlete submission → real private evidence → judge correction → resubmission →
   approval → verified result → correct official rank → notification:** highest
   priority; real storage + SQL + Chrome loop PASS. Flutter iOS/Android private-file
   loop PASS, including correction form, published board navigation and inbox check.
6. Unauthorized account/role/object access rejected; revocation/restoration across
   dashboard and clients: backend/browser tested; full platform lifecycle pending.
7. Moderation and notifications/preferences/delivery: incomplete.
8. Same athlete/profile/saved/submission/rank across supported clients incl. Watch:
   final acceptance pending.

## NOT STARTED — final deliverables / candidate

- Final whole-scope acceptance run including current Android AAB/watchOS.
- Final Phase 2 candidate/tag and comprehensive source secret scan.
- Final PDF (concise, real embedded screenshots), client demo MP4 and technical proof
  MP4, visually inspected. Only these three Client files, repository phase-2 folder
  and Desktop `FitCalgary Phase 2 Client Review Package`. Do not package partial work
  as complete. Internal tooling, credentials and unrelated material excluded.

## BLOCKED_EXTERNAL — only genuinely external verification

- Client-approved gym/pricing/club/event content, final ranking/boundary/verification
  decisions and legal copy: use isolated fixtures/configuration until supplied.
- Production Google/Apple identity client credentials, production email and Keycloak
  host/domain setup: integration hooks are not live production authentication.
- Production hosting/database/private-storage accounts, domains/DNS/TLS, APNs/FCM
  credentials and signing/store access: local adapters/testing still developer work.
- Appropriate physical devices: simulator/emulator proof is NOT DEVICE VERIFIED.
- Production/store configuration/submission audit is Phase 3, not Phase 2 completion.

## Presentation gates

Phase 2: no technical auth/raw errors/development warnings in ordinary screens;
fixtures remain isolated and disclosed in review docs. Cream/black/red editorial
identity, selective platform-appropriate depth/translucency, smooth restrained motion,
readability, reduced-motion and high-contrast fallbacks on major screens. Watch compact
native. Current navigation/material work is an increment, not full visual completion.
Comprehensive release/environment/store/public-cleanliness audit remains Phase 3.

## Exact current execution position

### Private-storage increment underway

- Local SeaweedFS 4.45 installed from its official release; archive SHA-256
  `e38ed55f9b9d59d926befcba05088010454551677547835ba154dbc2a2d8d4a4` verified.
  Binary/data ignored; credentials randomly generated in child environments; all
  listeners loopback, ancillary UI/WebDAV/telemetry disabled. Source:
  https://github.com/seaweedfs/seaweedfs/releases/tag/4.45
- `scripts/verify_private_storage.mjs`: PASS actual 7 MiB/two-part upload, exact
  retrieval, unsigned and tampered-signature denial, range playback and deletion.
- Same runner with DIRECTORY_TEST_DATABASE_URL: PASS complete Go/SQL submission,
  corrections, approval/ranking and private judge byte retrieval using REAL storage.
  Transport payload is test bytes, not a codec/video playback demonstration.
- Development harness optionally connects to loopback real storage and starts
  the notification outbox. Chrome full loop PASS, including actual video decoding,
  normal-user evidence rejection, correction, re-upload, approval, official placement
  and matching inbox notification. Production runtime unchanged.
- Storage-completion retry after successful provider completion is regression tested
  against real storage. Upload errors now avoid returning raw provider messages.
- Web official upload/private judge review/submission detail/correction implemented.
  Profile now links submission history, authorized review queue and allowlisted
  notification destinations. Final regression in progress after navigation additions.
- Next: verify current increment, commit privately, then Flutter real-storage workflow
  and remaining notification/moderation work. Do not stop after this checkpoint.

- Last completed: website account/preferences/favourites/logout and community result
  workflow. Commit `30066fe`, private push verified.
- Latest tests: Chrome admin/public/profile/community SQL-backed scenario PASS;
  web type/lint/build PASS. Earlier Flutter19 tests and iOS/Android profile PASS.
- Known failing test: none at last verified increment; full acceptance not run.
- Current unfinished work: notification
  preference/delivery operations, moderation and the remaining checklist above.
- September 6 rerun: actual storage/Go/SQL/Chrome full correction-to-rank-to-inbox
  workflow PASS after profile navigation updates; Go all tests/vet/build PASS;
  web type/lint/production build PASS; four auth/link unit tests PASS.
- September 6 mobile evidence run: `private_evidence_flow_test.dart` PASS on
  iPhone 17 Pro/iOS 26.5 and Pixel emulator/API 36. Flutter analysis and all 19
  widget/unit tests PASS. Added normal detail refresh/back navigation and a testable
  OS file-selection boundary. Initial Android run waited on emulator boot; rerun PASS.
- Current independent increment: audited account notes/suspension/ban/restoration,
  immediate-token denial tests PASS in Go/SQL; browser moderation test pending.
  Notification opt-out/opt-in, essential inbox, inactive-account suppression and
  five-attempt poison-job limit PASS against isolated actual PostgreSQL tables.
  Administrative send UI and provider delivery remain open, not production verified.
- **Next action:** inspect S3 evidence adapter and local storage availability; bring
  up isolated compatible storage, test real multipart upload/private playback, then
  integrate web judge/submission and Flutter acceptance against it. Update this ledger
  after each increment and immediately continue to the next open requirement.
