# Keycloak V1 identity configuration

The checked-in realm is the V1 identity source. It configures registration, verified email, password reset, brute-force protection, PKCE clients, and FitCalgary roles. It intentionally contains no production credentials and no Ory deployment.

For production:

1. Replace every example redirect host with the owned domain and application identifiers.
2. Store the web client secret in the platform secret manager.
3. Configure a verified SMTP sender and test registration, verification, forgot/reset password, and security alerts.
4. For the current Keycloak-brokered flow, use a Google OAuth **web application** client with the Keycloak broker callback URL. The mobile apps authenticate with Keycloak through PKCE; they do not require separate direct Google clients for this architecture. Populate the Google provider securely, enable it only once configured, and test account linking.
5. Create an Apple Services ID, App ID, Sign in with Apple key, team/key IDs, and broker return URL. Generate/rotate the Apple client-secret JWT outside source, populate the disabled standards-based `oidc` provider, enable it, and test relay-email behavior. Stock Keycloak does not provide an `apple` provider ID; Apple is configured through its OpenID Connect endpoints.
6. Map realm roles `user`, `moderator`, `admin`, `personal_trainer`, and `judge` to the `fitcalgary_roles` access-token claim. API resource authorization remains mandatory.
7. Disable development mode, require HTTPS and a strict hostname, move admin endpoints off the public edge, configure backups, and rotate bootstrap credentials.

The applications consume discovery metadata and standard claims only, so a later OIDC provider migration remains localized.

## Outstanding production provider setup

No clearly dedicated FitCalgary project is visible in the currently authenticated
Google Cloud project inventory. Unrelated projects must not be reused or changed.
The operator must identify another existing FitCalgary project or authorize a
dedicated project with display name **FitCalgary Index** and an available project ID.

Prepare its OAuth consent configuration with approved FitCalgary branding,
verified support contact, live privacy/support pages, `openid`, `email` and
`profile` scopes, and explicitly approved test users while it is in testing.
Create the web OAuth client **FitCalgary Keycloak** with this exact redirect:

```text
https://fitcalgary-auth-production.up.railway.app/realms/fitcalgary/broker/google/endpoint
```

Store the client ID/secret in the live Keycloak Google broker, never in Git.
The separate Keycloak-to-mobile redirect is
`ca.fitcalgary.index:/oauthredirect`, for client `fitcalgary-mobile`.
Do not add the mobile URI as a Google web OAuth callback.

The Apple Services ID is `ca.fitcalgary.index.auth`, linked to primary App ID
`ca.fitcalgary.index`. Its website domain and return URL must be configured:

```text
Domain: fitcalgary-auth-production.up.railway.app
Return URL: https://fitcalgary-auth-production.up.railway.app/realms/fitcalgary/broker/apple/endpoint
```

The Apple operator must authorize the Sign in with Apple key and secure its
private key, Key ID and Team ID. Generate the expiring Apple client-secret JWT
outside the repository and configure the Keycloak `apple` OIDC broker.
Neither creating the Services ID nor enabling the App ID capability proves login.

Email remains blocked on confirmation of the authorized FitCalgary/FitAlberta
sending domain and its DNS operator. Do not guess a domain or modify unrelated
Resend/DNS settings. Obtain Resend's exact domain-specific records, verify them,
then configure Keycloak SMTP with the verified sender and protected credential.
Registration and password reset require real inbox receipt and completed links
before they can be marked verified.
