# Production stabilization audit

Last updated: 2026-09-23

This is the working evidence register for the post-release FitCalgary V1
stabilization pass. A status of `PASS` records an executed check. Simulator and
emulator results are not physical-device verification.

## Defect register

| ID | Priority | Finding | Root cause | Resolution / status |
|---|---|---|---|---|
| AUTH-001 | P1 | Registration reaches an email-delivery error in production. | The live Keycloak realm requires verified email, but its SMTP configuration is empty. Railway logs record `Invalid sender address 'null'`. | `BLOCKED_EXTERNAL`: configure a verified SMTP provider/sender, then receive and open a real verification message. Email verification is intentionally still enabled. |
| AUTH-002 | P1 | Google sign-in fails in production. | The live Google identity provider is disabled and has no client ID or secret. | Mobile now routes directly to the Google broker alias and has regression coverage. `BLOCKED_EXTERNAL` for Google OAuth credentials and live-provider verification. |
| AUTH-003 | P1 | Apple sign-in fails in production. | The realm import used unsupported provider ID `apple`; the live provider is absent and Apple credentials are not available. | Realm source now uses Keycloak's standards-based OIDC provider with Apple's documented endpoints. Mobile routes directly to the Apple alias. `BLOCKED_EXTERNAL` for Apple Services ID/key/team material and live-provider verification. |
| AUTH-004 | P2 | Google and Apple buttons opened the generic Keycloak sign-in page rather than their selected providers. | Both buttons invoked the same provider-neutral method. | Fixed with `kc_idp_hint`; Flutter regression tests pass. |
| WEB-001 | P1 | Live profile and admin sign-in returned HTTP 503. | The Cloudflare Worker retained its encrypted session secrets but the latest deployment had no runtime bindings for the public URL, API URL, issuer or web client ID. | Fixed by restoring the four production bindings. Profile and admin entry points now return a PKCE authorization redirect to the live Keycloak realm. |
| WATCH-001 | P2 | The standalone Watch project could not be opened by Xcode. | The generated project file was invalid, while the embedded Runner target still compiled. | Regenerated from the checked-in XcodeGen specification; standalone and embedded Watch targets now build. |
| WATCH-002 | P2 | Watch home provided only a terse rank and three plain links, with no dedicated rankings experience or clear cached/offline state. | Initial companion shell was intentionally minimal. | Added real-data home summaries, dedicated results/rankings/review/event views, intentional empty states, clearer connectivity feedback and accessibility labels. |
| DATA-001 | P1 | The live gym index described 120 prices as complete all-in monthly costs although 114 source records had unknown annual or enrollment fees. | The approved-data importer converted unknown mandatory fees to zero and used source-derived estimates as proof of completeness. | Importer now requires explicitly known fee values; migration `0009` cleared misleading normalized figures for affected rows. A PostgreSQL 18 production backup was taken before migration. Live API now reports six confirmed-price gyms and 267 needing price confirmation, with all 273 gyms retained. |
| UI-001 | P2 | Android status-bar icons lacked contrast on the first-run dark introduction and on light home screens after navigation. | System overlay style did not follow the active route/theme. | Onboarding uses light status-bar icons; the application applies theme-aware system-bar styling elsewhere. Both appearances were visually checked in the Android emulator after rebuilding. |
| SEC-001 | P1 | A database tool emitted a production PostgreSQL credential in local session output during backup. | The tunnel helper includes its connection string when closing. | Database role password and Railway Postgres/API variables rotated; API readiness and catalog verified afterward. The temporary Railway SSH key was deregistered and deleted. Remote-local tunnel authentication did not provide a valid old-password rejection test; external credential rejection remains to be independently confirmed. |

## Executed evidence

| Area | Result | Evidence |
|---|---|---|
| Production web | PASS | Home, privacy and support return HTTPS 200. |
| Production API | PASS | `/health` and database-backed `/ready` return HTTPS 200. |
| Production OIDC discovery | PASS | Realm discovery returns HTTPS 200. |
| Web authentication entry | PASS | Profile and admin sign-in return a PKCE authorization redirect to the production realm; anonymous admin proxy access returns 401. Full authenticated completion still depends on working account/provider credentials. |
| Approved catalogue | PASS | Live API totals: 273 gyms, 743 clubs, 531 competitions. |
| Flutter static analysis | PASS | Flutter 3.47.2 reports no issues after the broker-routing fix. |
| Flutter tests | PASS | 23 tests pass, including Google/Apple provider-hint tests. |
| Go tests | PASS | All non-external Go packages pass; external integration tests remain explicitly skipped without isolated resources. |
| Go vet and production build | PASS | `go vet ./...` and `go build ./cmd/api` pass. |
| Apple Watch compile | PASS | Refined source builds through both the standalone XcodeGen project and the Watch target embedded in Runner. |
| iOS simulator | PASS | Production-configured Flutter app built and launched on iPhone 17 Pro simulator. |
| Android emulator | PASS | Production-configured debug APK built, installed and launched on Pixel 9 API 36 emulator; onboarding to home flow exercised. This is not a signed store build. |
| Pricing correction | PASS | Fresh PostgreSQL 17 import yields `6 complete / 114 incomplete` price rows; migration tested against intentionally stale rows, then applied to backed-up Railway PostgreSQL 18 with the same result. Live public gym filter returns six complete prices, 267 incomplete gym listings; API readiness remains 200. |
| Web deployment | PASS | Current web build deployed to Cloudflare Workers; home, gyms, events, leaderboards, privacy, support and account-deletion pages return HTTPS 200. Profile/admin authentication entry returns 307 to production OIDC and anonymous admin API returns 401. |
| Content quality | REVIEW REQUIRED | Supplied source has 273 gyms, 743 clubs and 531 competitions. It includes 153 gyms without an advertised membership price, 546 clubs without a street address, 223 clubs without a website, 151 competition date fields missing or explicitly not fetched, and 166 low-confidence competition records. These are source-data gaps, not facts to invent. |

## Verification boundaries

- Email registration, password-reset delivery, Google login and Apple login are
  not production verified until the corresponding externally controlled
  provider configuration is supplied and tested end to end.
- iOS, Android and watchOS physical-device verification must not be inferred
  from simulator or emulator results.
- The Client GitHub repository is outside this stabilization work and remains
  unchanged.
- A trusted source count is not a verification of each listing's present-day
  accuracy. Client confirmation remains required for incomplete or low-confidence
  listings before representing them as fully current.
- The corrected Flutter and Watch source is not in the existing store binaries.
  Replacement submission remains unsafe until registration, Google and Apple
  authentication are configured and verified through real provider flows.
