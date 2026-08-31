# Client source provenance

This document records the Client-provided FitCalgary source as pre-existing Client material and explains how it informs the active production codebase without replacing the corrected Flutter/Dart + Go architecture.

## Source identity

- Client repository: `https://github.com/longmirekonoka-design/fitcalgary-studio`
- Retrieved read-only through the Client-authorized, signed-in GitHub session on 2026-08-31.
- GitHub archive source commit: `4c629019f68c3d11709a77f9fea9f3190250ce44`.
- Downloaded archive SHA-256: `3cd63d3e95d735ac94c1e00c6f8fec6c5efb92f4f1df77e91936432ab5584d2e`.
- Extracted snapshot inventory: 203 files; deterministic sorted-file digest `698098c5e00a45d7f3a1a4267f3b218bdc87b3214f75f45c0d1a07d338657e44`.
- Local archive reference path: `/Users/sahlshafiq/Documents/Coding/fitcalgary-client-source-reference`.
- Full authenticated Git clone: `/Users/sahlshafiq/Documents/Coding/fitcalgary-client-source-git`.
- Client repository history verified: three genuine commits on `main`; earliest `1f9be5b`, documentation follow-up `937fdc3`, current source `4c629019`.

The archive commit exactly matches the authenticated repository HEAD. The full clone contains the complete remote branch/tag view available to the Developer account. No new development is pushed to the Client repository; its local push URL is disabled as an additional safeguard.

## Material reviewed

- Product information architecture, public routes and copy under `src/app/(index)`.
- FitCalgary design system under `src/app/(index)/index.css`.
- Home, gym index, leaderboard, Compete, account/profile, submission and staff-console surfaces.
- Client content collections for gyms, competitions, clubs and posts.
- Authentication, permissions, API, database, video-evidence and notification modules.
- Studio/editor, responsive-audit and test structure.
- Architecture, API, authentication, database, deployment, offline and Index product documentation.

## Incorporated product decisions

The active Flutter product directly preserves the recognizable FitCalgary identity and information architecture demonstrated by the Client source:

| Client direction | Active implementation evidence |
|---|---|
| “The city, ranked.” hero and near-monochrome/coral visual identity | Flutter Home and onboarding screens; shared theme/widgets |
| Home / Gyms / Board / Compete / Me mobile navigation | Flutter router and navigation shell |
| True-cost gym index and normalized monthly pricing language | Flutter Gym Index plus Go pricing/domain foundation |
| Video-verified official boards | Flutter Board shell plus Go leaderboard/submission/judge contracts |
| Competition calendar and open-entry presentation | Flutter Compete shell plus Go event contracts |
| Athlete/account, saved gyms and notifications direction | Flutter profile/auth surfaces plus protected Go account/notification routes |
| Staff/administration concepts and server authorization | Responsive admin dashboard plus Go `ADMIN` enforcement |
| Private evidence and review rules | Go private storage/submission/judge foundations |

## Architecture boundary

The Client snapshot is a useful Next.js/TypeScript and SQLite product reference, but it is not the production backend chosen for this engagement. Its product decisions, copy, content structures and security lessons are retained where useful. The active runtime remains:

```text
Flutter/Dart clients + responsive web
              → versioned Go API
              → PostgreSQL
              → Keycloak OIDC/OAuth 2.0 + PKCE
```

The snapshot’s committed PostgreSQL DDL was documented as unverified, its production PostgreSQL driver was not wired, and email/social identity/object-storage integrations were incomplete. The active Go/PostgreSQL/Keycloak foundation addresses those architectural requirements instead of extending the Node backend.

## Data and credential boundary

- Client content collections are preserved in the read-only source snapshot but are not represented as approved production data.
- The active application continues to use clearly labeled development data until the Client supplies or approves production imports.
- Sample passwords or local development credentials documented in the Client snapshot are not imported into active authentication, committed configuration or Client-facing evidence.
- Third-party notices and source provenance are preserved; no third-party or Client-pre-existing code is represented as newly authored custom work.
