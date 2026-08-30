# Security baseline

- Keycloak is the only V1 identity provider. Applications use OIDC discovery and Authorization Code with PKCE; Google and Apple are disabled broker hooks until client credentials are supplied. Ory is not deployed.
- The Flutter app stores access, refresh, and ID tokens in platform secure storage, refreshes before retrying a single unauthorized request, and clears secure state on logout. The web BFF encrypts its `HttpOnly`, `Secure`, `SameSite=Lax` session cookie with AES-GCM and performs server-side refresh/revocation.
- The Go API verifies issuer/audience/signature/expiry through OIDC, maps only known FitCalgary roles, merges server-stored grants, and independently enforces role, ownership, assignment, and account status.
- Request bodies are bounded and decoded with unknown-field rejection. Public filters and UUIDs are validated. Errors expose stable codes and request IDs without internal details.
- PostgreSQL migrations are checksum-guarded and transactional. Stateful decisions, result creation, rank history, audit records, and notification jobs use server-side transactions/locking.
- Evidence remains in private S3-compatible storage. The API issues short-lived multipart/playback authorizations only after ownership or judge assignment checks; retention workers remove expired objects.
- Notification device tokens are AES-GCM encrypted at rest and stored with a one-way lookup hash. Secrets are environment variables and are excluded from source control.
- CORS is allowlisted to the configured web origin. Responses set content-type, frame, referrer, and permissions security headers. Production requires HTTPS, managed secrets, backups, least-privilege infrastructure identities, and provider credential rotation.

The local Phase 1 harness is intentionally separate from the production command, requires two explicit development-only environment gates, and accepts only a fixed non-production token. The production container builds `cmd/api`, not the harness.
