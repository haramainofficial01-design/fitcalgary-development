# V1 API foundation contract

## Phase 2 athlete profile — September 4 evening

- `GET /profile` now returns the owner’s ranking-eligibility fields, privacy
  preferences, city and current published-gym affiliation. `PATCH /profile`
  accepts validated birth date, board category, published home gym and the two
  supported privacy controls; arbitrary fields and unpublished/missing gyms are
  rejected. Roles remain outside this self-service contract.
- `GET /profile/performance` is authenticated and owner-scoped. It returns recent
  non-invalidated results with server-derived board rank plus one server-selected
  personal best per discipline and board type. Official and community board types
  remain explicit in every result; no evidence object, account email, judge notes
  or moderation data is returned.

The Flutter profile consumes these contracts through typed models and presents
verified and community marks with distinct labels, ranks, personal bests, gym
affiliation and explicit public-profile controls. Executable proof is in
`directory_integration_test.go`, `profile_widgets_test.dart` and
`profile_shell_test.dart`.

## Phase 2 clubs/events — September 4 morning

- `GET /clubs`, `GET /events`: server search `q`, `city` (default Calgary),
  `category`, `sport`, `page`, `pageSize`; public records only. Empty pages retain
  the complete filtered `total`. Responses preserve `data/page/pageSize/total`.
- `GET /clubs/{slug}`, `GET /events/{slug}`: published detail with optional `city`;
  drafts/archives/missing records return 404. Club detail includes address,
  eligibility, season, website/registration links and source information.
- Events additionally accept `month=YYYY-MM` (Edmonton month), `open=true|false`
  and `phase=UPCOMING|CURRENT|COMPLETED|CANCELLED|POSTPONED`. State is server-derived;
  cancellation/postponement overrides dates. With no end time, the event becomes
  completed after start rather than assuming a duration. Open-entry results require
  ACTIVE, registration OPEN and a nonexpired deadline (start time if none supplied).
- `GET/POST /admin/clubs`, `PUT /admin/clubs/{id}`; existing event GET/POST plus
  `PUT /admin/events/{id}`. All require ADMIN server-side. PUT replaces editable
  fields; `publishStatus=DRAFT|PUBLISHED|ARCHIVED` supports unpublishing and reversible
  archiving without deleting IDs/relationships. Event entry requirements and image
  URL are now editable. Typed fields, valid timestamps/date order and HTTP(S) links
  without embedded credentials are enforced. Content and audit commit atomically.

Executable proof: `content_integration_test.go` covers real PostgreSQL publication,
detail/list queries, event state, unsafe input, role rejection and audit rollback.
Client forms/routes still require integration before this is a complete user workflow.

Flutter now consumes the public list/detail contracts for Events and Clubs. The web
admin consumes `admin/clubs` for list/create and `admin/events` for list/create. The
cross-layer mobile test proves newly published administrative content becomes visible
through the shared API; full web-admin update/unpublish controls remain in progress.

## Phase 2 directory/account increment — September 3, 2026

`GET /gyms` accepts `q`, `city`, `category`, `area`, `amenity`,
`pricing=complete|incomplete`, `maxMonthlyCents`, `sort=cost|name`, `pageSize` and
`page`. Invalid bounds/filters return structured validation errors. Results include
stable gym slugs, area, amenities, current normalized ongoing/year-one prices and
pricing-completeness state. Search, filtering, sorting and pagination run on the
server. Unknown costs are not represented as a free membership.

`GET /gyms/{slug}` supplies actual gym details and currently effective pricing plans.
Optional `city` disambiguates a slug. Plan metadata supports membership type,
contract months, eligibility, drop-in cost, trial details, notes and source information.
The additive `0002_membership_terms.sql` migration preserves existing data.

Saved-gym reads/writes are authenticated and owner-scoped. Saving is idempotent;
missing/unpublished gyms are rejected. Another account cannot remove the owner's
saved entry. Profile updates persist through the protected API; supplying role
changes through the profile payload is rejected. Admin pricing writes require
server-authorized administrator access and validated terms/effective dates.

Executable evidence: `internal/httpapi/directory_integration_test.go` in the Go
service and `integration_test/gym_account_flow_test.dart` in the Flutter app. The
latter uses an ephemeral development identity but real service/database operations.

The production contract is the versioned Go API under `/api/v1`. JSON errors use `{ "error": { "code", "message", "requestId", "details" } }`. List endpoints return `{ "data", "page", "pageSize", "total" }` where pagination applies. Protected requests carry an OIDC access token in `Authorization: Bearer <token>`; identity, effective roles, ownership, approvals, and ranks are always resolved server-side.

## Public foundation

| Method | Path | Purpose |
|---|---|---|
| GET | `/health`, `/ready` | Process and database readiness |
| GET | `/api/v1/gyms`, `/gyms/{slug}` | Gym index and normalized pricing |
| GET | `/api/v1/clubs` | Recreational club directory |
| GET | `/api/v1/events` | Events and registration metadata |
| GET | `/api/v1/disciplines` | Versioned discipline/rules metadata |
| GET | `/api/v1/leaderboards`, `/leaderboards/{id}` | Board catalogue and ranked entries |

## Account and notification foundation

| Method | Path | Protection |
|---|---|---|
| GET | `/api/v1/auth/context` | Authenticated identity/effective roles |
| GET, PATCH, DELETE | `/api/v1/profile` | Owner only |
| GET | `/api/v1/profile/performance` | Owner only; public-safe result projection without private evidence |
| GET, PUT, DELETE | `/api/v1/saved-gyms[/{gymId}]` | Owner only |
| GET | `/api/v1/notifications` | Owner only |
| GET, POST, PUT, DELETE | `/api/v1/notification-devices[/{id}]` | Owner only; tokens encrypted at rest |
| GET | `/api/v1/watch/summary` | Owner only, minimal watch payload |

## Submission and judging foundation

| Method | Path | Protection |
|---|---|---|
| GET, POST | `/api/v1/submissions` | Athlete owner |
| POST | `/api/v1/submissions/{id}/uploads` | Owner; private multipart session |
| POST | `/api/v1/uploads/{id}/parts/{partNumber}` | Owner; short-lived signed part URL |
| POST | `/api/v1/uploads/{id}/finalize` | Owner; transactional review transition |
| GET | `/api/v1/judge/queue` | `JUDGE` or `ADMIN` |
| GET | `/api/v1/judge/submissions/{id}/evidence` | Assigned judge or `ADMIN`; audited |
| POST | `/api/v1/judge/submissions/{id}/decision` | Assigned judge or `ADMIN` |

## Administration foundation

The Go router includes protected overview, reference data, users, gyms/pricing, events, settings, role grant/revoke, and audit-log routes under `/api/v1/admin`. Every route requires `ADMIN`; clients cannot self-assign roles. Additional Phase 2 admin surfaces will extend this single contract rather than create a second service.

Request validation rejects unknown JSON fields, limits bodies to 1 MiB at the API boundary, validates identifiers/enums/ranges, and returns safe error bodies with request IDs. The canonical domain enums and response shapes are implemented in Go and mirrored for consumers in `packages/contracts` and Flutter domain models.
