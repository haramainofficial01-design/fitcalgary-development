# Architecture

## Runtime topology

```text
Web / iOS / Android / watchOS / Admin
                 │ HTTPS + OIDC access token
                 ▼
             Versioned Go REST API
      ┌──────────┼────────────┬─────────────┐
      ▼          ▼            ▼             ▼
 PostgreSQL   Keycloak   Private S3/R2   Durable jobs
 domain data   identity   video evidence  notifications/retention
```

## Decisions

- Keycloak is the only V1 identity provider. Email/password and external Google/Apple sign-in are brokered there. Mobile uses Authorization Code + PKCE; web uses secure BFF-style server sessions where deployed.
- Flutter/Dart is the primary application and frontend stack for the shared iOS and Android product surfaces. The public/admin web remains web-native where SEO, accessibility, and operational data density require it; the focused watch companion remains native SwiftUI.
- Go is the production backend and integration-services language. The previously started TypeScript service is retained only as a non-production behavioral reference while its routes are migrated; it is not part of the V1 deployment topology.
- API authorization maps standards-based token roles to application permissions and applies resource ownership/assignment rules independently.
- PostgreSQL is authoritative. Large evidence uploads go directly to a private S3-compatible store via short-lived multipart authorizations; binary data never traverses or resides in PostgreSQL.
- PostgreSQL-backed jobs provide an outbox, retry scheduling, deduplication, notifications, retention, and analytics aggregation without a mandatory Redis deployment.
- Region, city, brand, rules, divisions, and disciplines are configuration/data rather than Calgary-specific code.
- Ranking and price normalization are deterministic server-side domain functions covered by tests.
- Public/admin web consumers and Flutter/SwiftUI clients share the same versioned OpenAPI-compatible HTTP contract. Provider integration is isolated behind interfaces so identity, storage, notification, and mail vendors can be replaced without rebuilding the product.

## Trust boundaries

Clients cannot supply user identity, roles, approval state, rank, or verification state. Signed evidence access is issued only after server authorization. Sensitive state changes are transactional, idempotent where retryable, and audit logged with a request ID.
