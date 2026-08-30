# FitCalgary Index Go API

This is the production V1 backend and integration service. It is the single
source of truth for authorization, submissions, review decisions, ranking,
notifications, audit history, and public directory data.

## Local development

```sh
export PATH="$PWD/.tooling/go/bin:$PATH"
cd services/api-go
go mod download
go test ./...
go run ./cmd/api
```

The service uses the shared migration at `services/api/migrations/0001_initial.sql`.
Set `MIGRATIONS_DIR` when the service is started outside the repository layout.

Keycloak is the only production V1 identity provider. Clients use OAuth 2.0
Authorization Code with PKCE; the API validates access tokens through OIDC
discovery and JWKS and enforces FitCalgary roles server-side.

`DEVICE_TOKEN_ENCRYPTION_KEY` must be base64-encoded 32-byte AES key material.
Only a SHA-256 lookup hash and AES-GCM ciphertext are stored for APNs/FCM/web
push tokens.

`DELETE /api/v1/profile` anonymizes profile PII, removes saved/private data,
expires evidence, preserves verified result history, blocks future API access,
and queues an `IDENTITY_DISABLE` outbox job. Production deployment must provide
a worker with a least-privilege Keycloak service account to disable the user and
revoke sessions. Until those Keycloak Admin API credentials are supplied, the
job remains queued and the API-side `DELETED` status remains the enforcement
backstop.

The previous `services/api` Node implementation is retained temporarily as a
reference prototype and must not be deployed.
