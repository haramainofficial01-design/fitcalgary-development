# Client source provenance

The delivered repository incorporates the Client-provided FitCalgary product direction and pre-existing materials into the current Flutter/Dart, Go, PostgreSQL, web, and watchOS codebase. Client-provided materials remain identifiable by their product role and are not represented as newly authored third-party work.

## Preserved product direction

The current product retains the recognizable FitCalgary identity and information architecture:

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

## Current architecture

The delivered runtime is:

```text
Flutter/Dart clients + responsive web
              → versioned Go API
              → PostgreSQL
              → Keycloak OIDC/OAuth 2.0 + PKCE
```

## Data and credential boundary

- The Client-approved catalog is imported through the production data model; isolated development fixtures remain test-only.
- Production credentials and signing material are not committed.
- Third-party notices and attribution must remain intact when dependencies or assets are redistributed.
