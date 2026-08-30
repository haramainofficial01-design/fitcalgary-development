# Keycloak V1 identity configuration

The checked-in realm is the V1 identity source. It configures registration, verified email, password reset, brute-force protection, PKCE clients, and FitCalgary roles. It intentionally contains no production credentials and no Ory deployment.

For production:

1. Replace every example redirect host with the owned domain and application identifiers.
2. Store the web client secret in the platform secret manager.
3. Configure a verified SMTP sender and test registration, verification, forgot/reset password, and security alerts.
4. Create Google OAuth web/iOS/Android clients, configure the Keycloak broker callback URL, populate the Google provider, enable it, and test account linking.
5. Create an Apple Services ID, App ID, Sign in with Apple key, team/key IDs, and broker return URL. Generate/rotate the Apple client-secret JWT outside source, populate the provider, enable it, and test relay-email behavior.
6. Map realm roles `user`, `moderator`, `admin`, `personal_trainer`, and `judge` to the `fitcalgary_roles` access-token claim. API resource authorization remains mandatory.
7. Disable development mode, require HTTPS and a strict hostname, move admin endpoints off the public edge, configure backups, and rotate bootstrap credentials.

The applications consume discovery metadata and standard claims only, so a later OIDC provider migration remains localized.
