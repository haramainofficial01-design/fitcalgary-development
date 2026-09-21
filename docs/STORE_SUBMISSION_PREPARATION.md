# FitCalgary V1 store submission preparation

This document records the release preparation completed from the current source
without claiming store upload or approval.

## Application identity

- Product name: FitCalgary Index
- Bundle identifier: `ca.fitcalgary.index`
- Version: `1.0.0`; Android build `3`; Apple build `6`
- Android application ID: `ca.fitcalgary.index`
- Brand icon master: `brand/release/fitcalgary-app-icon-v1.png`
- iOS and Android icon sets: generated from the same approved brand master
- Launch screens: FitCalgary cream/black/coral launch mark on both platforms

## Live release services

- Public web: `https://fitcalgary-web.fitcalgary.workers.dev`
- Privacy: `https://fitcalgary-web.fitcalgary.workers.dev/privacy`
- Support: `https://fitcalgary-web.fitcalgary.workers.dev/support`
- Account deletion: `https://fitcalgary-web.fitcalgary.workers.dev/account-deletion`
- Go API: `https://fitcalgary-api-production.up.railway.app`
- OIDC issuer: `https://fitcalgary-auth-production.up.railway.app/realms/fitcalgary`

The public URLs, API health endpoint and OIDC discovery document were checked
over HTTPS. The Client's permanent domain can be connected later without an
application rewrite.

## Prepared artifacts

- iOS: a signed `1.0.0` build `6` archive and IPA were generated with the embedded
  Watch companion. The archive passes local signature and embedded-binary
  validation and includes the complete Watch icon set required by App Store
  Connect.
- Android: a signed `1.0.0` build `3` AAB was generated with the dedicated Play
  upload key and processed successfully by Google Play Console. The release is
  staged for the closed-testing track.
- Simulator/emulator debug builds: rebuilt and launched after the release identity update
- Web: production build deployed and verified at the public URL above

## Google Play listing copy

**App name**

FitCalgary

**Short description**

Calgary gyms, real membership costs, local events and verified leaderboards.

**Full description**

FitCalgary brings Calgary's fitness community into one clear, trusted index.

Explore gyms across the city, compare structured membership pricing, save the
places you want to revisit and discover local clubs and competitions. Follow
official and community leaderboards across supported disciplines, build an
athlete profile and submit results for review.

FitCalgary is designed around transparent information and credible results:

- Browse Calgary-area gyms and filter by location or category.
- Compare advertised pricing using consistent all-in cost information.
- Save gyms and return to them from your profile.
- Discover sports clubs, leagues, meets and other local events.
- View official and community leaderboards.
- Submit eligible results with private evidence for moderator or judge review.
- Receive status updates when a submission needs attention or is approved.

Final availability of individual listings, events and leaderboard disciplines
depends on the information published by FitCalgary and participating organizers.

**Release notes — English (Canada)**

Welcome to FitCalgary Index. Explore Calgary-area gym listings and transparent
pricing, discover local clubs and events, follow official and community
leaderboards, save gyms, and submit results for review.

**Temporary public support email**

`ramy@fitxplor.com`

The website reads this from `NEXT_PUBLIC_SUPPORT_EMAIL` when configured and
otherwise uses the temporary address above, so the Client address can replace it
without changing page components.

## Store classification and disclosure source of truth

- Category: Health & Fitness.
- Ads: none.
- Government app: no.
- Financial features: none.
- Target audience: adults; not designed for children.
- Restricted access: some account, submission and administration functions
  require sign-in. Browsing the public index remains available without an account.
- Account deletion: available through the application/account flow and the public
  deletion-information URL above.
- Data that may be collected when a user chooses the corresponding feature:
  name, email address, account/user identifier, athlete profile information,
  saved gyms, result/submission activity, private evidence video, notification
  token and basic service/security diagnostics.
- Private evidence is access-controlled and is not sold. Service providers may
  process data only to operate authentication, hosting, storage and notifications.
- Data is transmitted over HTTPS. The server is authoritative for roles and
  protected-resource authorization.

These entries are implementation facts for completing the store questionnaires;
the Console's final wording and category choices remain the authoritative record.

## Final publishing inputs

The following are the only release actions that cannot be completed from the
local source tree alone:

1. Keycloak SMTP credentials for email verification and password reset.
2. Google and Apple identity-provider credentials, plus FCM/APNs credentials for
   production social sign-in and push delivery.
3. Physical iPhone, Android phone and Apple Watch validation.
4. Google Play's account-level closed-test requirement: at least 12 opted-in
   testers continuously for 14 days before production access can be requested.
5. The Client's permanent FitCalgary/FitAlberta domain connection and final
   store/platform review decisions.

These dependencies do not require application feature changes. The release
configuration, fail-closed signing scripts, metadata hooks, entitlements,
migration/runbook documentation and platform assets are present and are intended
to be connected at the publishing step.
