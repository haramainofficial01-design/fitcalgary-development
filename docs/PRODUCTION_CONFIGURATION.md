# Production configuration

This document is the release-time configuration map for the FitCalgary V1
services. Values are supplied by the deployment secret manager or platform
configuration; no production values belong in Git.

## Go API

| Variable | Required | Purpose / source |
|---|---:|---|
| `APP_ENV` | Yes | `production`; supplied by the deployment environment. |
| `DEMO_DATA` | Yes | Must be the literal `false` in production. |
| `PORT` | Yes | Listening port selected by the hosting platform. |
| `DATABASE_URL` | Yes | Managed PostgreSQL connection string from the hosting provider. |
| `MIGRATIONS_DIR` | Optional | Defaults to the container’s `/app/migrations`. |
| `KEYCLOAK_ISSUER` | Yes | HTTPS Keycloak realm issuer URL. |
| `KEYCLOAK_AUDIENCE` | Yes | API audience claim, normally `fitcalgary-api`. |
| `WEB_PUBLIC_URL` | Yes | HTTPS public web origin used for CORS and origin checks. |
| `S3_ENDPOINT` | Yes | HTTPS S3-compatible storage endpoint. |
| `S3_REGION` | Yes | Storage region. |
| `S3_BUCKET` | Yes | Private evidence bucket name. |
| `S3_ACCESS_KEY_ID` | Yes | Secret-manager reference for the least-privilege storage identity. |
| `S3_SECRET_ACCESS_KEY` | Yes | Secret-manager value for that storage identity. |
| `DEVICE_TOKEN_ENCRYPTION_KEY` | Yes | Secret-manager value containing a base64-encoded random 32-byte key. |
| `SIGNED_URL_TTL_SECONDS` | Optional | Short-lived evidence URL lifetime (30–900 seconds). |
| `MAX_EVIDENCE_BYTES` | Optional | Upload limit; the current feasibility ceiling is 4 GiB. |
| `EVIDENCE_RETENTION_DAYS` | Optional | Retention window, currently 14 days by default. |
| `FCM_PROJECT_ID` | Optional | Firebase project for Android delivery; required when push is enabled. |
| `FCM_CLIENT_EMAIL` | Optional | Secret-manager service-account identity for FCM. |
| `FCM_PRIVATE_KEY` | Optional | Secret-manager private key for FCM; never commit it. |

The API rejects missing required values, invalid ranges, insecure production
endpoints, loopback hosts, embedded URL credentials, enabled demo data, and the
development token-key placeholder.

## Web and Flutter

Web server configuration uses `OIDC_ISSUER`, `OIDC_WEB_CLIENT_ID`, optional
`OIDC_WEB_CLIENT_SECRET`, `WEB_PUBLIC_URL`, `API_BASE_URL`, `SESSION_COOKIE_SECRET`,
and `NEXT_PUBLIC_SITE_URL`. The session secret is a random secret-manager value;
the web BFF seals `HttpOnly`, `Secure`, `SameSite=Lax` cookies and performs token
refresh server-side.

Flutter builds receive `API_BASE_URL`, `OIDC_ISSUER`, `OIDC_CLIENT_ID`, and
`ALLOW_INSECURE_OIDC=false` through release build defines. Firebase mobile/web
defines are supplied only when the corresponding notification provider is
configured. The checked-in `.env.example` contains development placeholders and
must not be used as a production secret source.

Android release signing is supplied only through `FITCALGARY_RELEASE_KEYSTORE`,
`FITCALGARY_RELEASE_STORE_PASSWORD`, `FITCALGARY_RELEASE_KEY_ALIAS`, and
`FITCALGARY_RELEASE_KEY_PASSWORD`. Without all four values the project can still
produce a local debug-signed release artifact, but it is not a store-uploadable
production bundle.

## Keycloak and email/social providers

Import `infrastructure/keycloak/fitcalgary-realm.json` as a starting realm
configuration, then replace redirect hosts and client identifiers for the owned
domains. The Client or production operator supplies verified SMTP, Google OAuth,
Apple Sign in with Apple, and Keycloak bootstrap credentials through the provider
secret manager. The Go API continues to enforce FitCalgary roles independently of
frontend claims.
