# V1 API foundation contract

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
