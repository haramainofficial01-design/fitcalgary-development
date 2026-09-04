# Phase 2 delivery plan

Updated September 3, 2026 — America/Edmonton.

Phase 1 is accepted, fully paid and CLOSED. Its milestone stays unchanged. Phase 2
is authorized. September 8 morning is the complete Phase 2 review-package target,
with afternoon/evening reserved as contingency. This is a delivery target, not a
guarantee or permission to omit agreed functionality or claim untested completion.

## Daily execution and acceptance

Scheduled work blocks: 08:00, 13:00 and 18:00 Edmonton, September 4–8 inclusive.
Each block continues the current codebase; it does not restart completed work.
An automation is an opportunity to run work, not proof that work ran or passed.

| Date | Main work | Required evidence before calling the increment complete |
|---|---|---|
| September 3 | Gym directory, pricing, saved gyms and account persistence | Signed-in Flutter client browses actual Go/PostgreSQL data, compares memberships, saves/removes a gym and reloads persisted profile state |
| September 4 | Clubs/events and athlete profile depth | API-backed search/detail and profile workflows; permissions, persistence and client navigation tests |
| September 5 | Disciplines/divisions, official/community boards and results | Deterministic ranking tests; correct status/division isolation; operational result workflow |
| September 6 | Private evidence and judging | Upload/access boundaries, review comments, approve/reject/resubmit and ranking publication tested end to end |
| September 7 | Admin CRUD, notifications, integrations and platform regression | Operational permissions and workflow checks; iOS/Android/web/watchOS regressions; begin real visual captures and review-document layout |
| September 8 morning | Integrated acceptance and complete client package | Full agreed Phase 2 requirement audit, important end-to-end tests, final captures, rendered PDF inspection and MP4 playback/privacy checks |
| September 8 afternoon/evening | Contingency | Resolve acceptance defects and regenerate affected evidence; report any unmet requirement explicitly |

Morning blocks prioritize implementation and the highest-risk unmet acceptance
criteria. Afternoon blocks finish integration and platform testing. Evening blocks
resolve failures, preserve meaningful private Git commits and assess the next day's
critical path. Carry unfinished work forward explicitly; do not equate a date with
completion. Notify the Developer promptly if scope, failures, environment access or
external dependencies put September 8 at risk. Preserve time for verification and
packaging rather than treating them as optional work after the deadline.

## Complete client package

Only three client-facing files, together in the Desktop folder
`FitCalgary Phase 2 Client Review Package`, with repository copies under
`client-review/phase-2/`:

- `FitCalgary_Phase_2_Client_Review.pdf`
- `FitCalgary_Phase_2_Client_Demo.mp4`
- `FitCalgary_Phase_2_Technical_Proof.mp4`

The concise PDF follows the established FitCalgary typography, colours and clean
layout. It contains scope/status, actual embedded platform/workflow screenshots,
plain-language architecture/security, a compact test summary, external dependencies,
later physical-device/production verification, remaining Phase 3 work and an explicit
client-review section. Internal engineering reports remain internal. Do not expose
private repository access, credentials, unrelated windows or internal tooling/process
material. Make no false claim about development methods.

Videos show actual running product and technical evidence with short labels, clear
sequencing and little waiting. Inspect every PDF page and the finished video files
for readability, clipping, accuracy and privacy. Simulator/emulator evidence is not
physical-device verification; development identities and fixtures are not production
authentication or approved Client content. Do not claim acceptance or payment for
Phase 2 before the Developer confirms it.

## Data and release boundaries

Keep synthetic content in the opt-in development fixture system using real models.
Client-approved content, ranking decisions and production service credentials remain
external dependencies until received/verified; do not block unrelated engineering.
Do not deploy or start substantial Phase 3 work without explicit authorization.
Preserve authentic commit times and history; push new work only to the private
development remote. No premature Client source transfer.
