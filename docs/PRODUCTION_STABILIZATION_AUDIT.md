# Production stabilization audit

Last updated: 2026-09-24

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
| WATCH-003 | P1 | A Watch account with nonempty data could fail to load its entire summary. | The Go API emits snake-case result fields and fractional RFC 3339 timestamps, but the Watch decoder expected camel-case fields and basic ISO 8601 dates. Date-only events also have no `start_at`. | The Watch decoder now accepts the real API field names and timestamp precision; the event model accepts a verified day without inventing a time. An API-shaped nonempty snapshot and cache round-trip pass locally. Standalone and embedded Watch simulator builds pass; the logged-out Watch launches. A production authenticated Watch session remains unverified until sign-in works. |
| DATA-001 | P1 | The live gym index described 120 prices as complete all-in monthly costs although 114 source records had unknown annual or enrollment fees. | The approved-data importer converted unknown mandatory fees to zero and used source-derived estimates as proof of completeness. | Importer now requires explicitly known fee values; migration `0009` cleared misleading normalized figures for affected rows. A PostgreSQL 18 production backup was taken before migration. Live API now reports six confirmed-price gyms and 267 needing price confirmation, with all 273 gyms retained. |
| UI-001 | P2 | Android status-bar icons lacked contrast on the first-run dark introduction and on light home screens after navigation. | System overlay style did not follow the active route/theme. | Onboarding uses light status-bar icons; the application applies theme-aware system-bar styling elsewhere. Both appearances were visually checked in the Android emulator after rebuilding. |
| CONTENT-001 | P2 | Mobile and web described every listed competition as enterable, even though the directory includes past and undated events; raw database phase labels were visible. | The page and home copy assumed all catalog events were open, while the API intentionally returns every published event. | Replaced the claim with truthful directory copy, human-readable phase labels, and registration labels only on current/upcoming events; home cards now open their own detail page. Flutter and web label regression tests pass. |
| CONTENT-002 | P1 content dependency | All 531 live competition records originally had no structured date. | Client-supplied `next_dates` is natural-language schedule text, often approximate or multiple dates; the original importer parsed only ISO timestamps. | Three exact single-day source entries were independently corroborated and now populate a date-only field in local migration tests: YYC-172 (Sep 26), YYC-506 (Oct 24), YYC-508 (Dec 12). Their time remains unknown. The other 528 remain undated. This correction is **not yet deployed**, and registration-open status is not inferred from the date. |
| CONTENT-003 | P2 | Six competition registration links return HTTP 404. | The approved source retained links that have since disappeared. | Cleared only the six broken public website fields in the import source and added a provenance-guarded migration that hides the public action without deleting the original source payload. Local migration verified six of six links hidden. **Not yet deployed.** No replacement URL was invented. |
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
| Flutter tests | PASS | 25 tests pass, including Google/Apple provider-hint and event-status copy tests. |
| Go tests | PASS | All non-external Go packages pass; external integration tests remain explicitly skipped without isolated resources. |
| Go vet and production build | PASS | `go vet ./...` and `go build ./cmd/api` pass. |
| Apple Watch compile | PASS | Refined source builds through both the standalone XcodeGen project and the Watch target embedded in Runner. |
| iOS simulator | PASS | Production-configured Flutter app built and launched on iPhone 17 Pro simulator. |
| Android emulator | PASS | Production-configured debug APK built, installed and launched on Pixel 9 API 36 emulator; onboarding to home flow exercised. This is not a signed store build. |
| Pricing correction | PASS | Fresh PostgreSQL 17 import yields `6 complete / 114 incomplete` price rows; migration tested against intentionally stale rows, then applied to backed-up Railway PostgreSQL 18 with the same result. Live public gym filter returns six complete prices, 267 incomplete gym listings; API readiness remains 200. |
| Web deployment | PASS | Current web build deployed to Cloudflare Workers; home, gyms, events, leaderboards, privacy, support and account-deletion pages return HTTPS 200. Profile/admin authentication entry returns 307 to production OIDC and anonymous admin API returns 401. |
| Event copy deployment | PASS | Cloudflare Worker version `8f73360c-c8ab-4e79-9f2a-02afb12c75ef` serves the corrected events heading and status labels. Live home/events/public-events return 200; admin authentication entry remains 307 and API readiness 200. |
| Competition date recovery | LOCAL PASS; PRODUCTION PENDING | Source scan found 3 exact single-day dates in 531 records. Local PostgreSQL migration 0010 yielded 3 dated and 528 undated records; real local API queries returned 3 upcoming, 528 undated and correct month filtering. Flutter/Go/web regression checks pass. The live API has not received migration 0010. |
| Competition URL audit | LOCAL PASS; PRODUCTION PENDING | Of 531 records, 509 contained a website string, 506 were syntactically valid and 22 were absent. A bounded HTTP check covered 395 unique public URLs; six record links were confirmed 404 after GET recheck. 67 other requests were unavailable or inconclusive, not classified as broken. Local migration 0011 hid all six confirmed links. |
| Watch nonempty-data decoding | LOCAL PASS; PRODUCTION PENDING | `WatchSnapshotCodecSmoke.swift` decodes representative Go-shaped rankings, approved results, submissions, fractional timestamps and a date-only event, then reloads the cache. Standalone Watch and embedded iOS/Watch simulator builds pass; the Watch app launches in the simulator. Real account data and physical hardware remain unverified. |
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

## Date and link provenance

The exact date-only source strings are retained in
`data/client-approved/calgary_sport_competitions.json`. Independent organizer
pages corroborate [YYC-172](https://www.calgaryrugby.com/senior-rugby),
[YYC-506](https://wnbfcanada.ca/pages/calgary-naturals) and
[YYC-508](https://www.albertacheerleading.ca/alberta-cheer-competitions).
None supplies a confirmed start time or registration-open state for the
FitCalgary record, so neither is fabricated.

The six 404 public links are YYC-159, YYC-163, YYC-165, YYC-167, YYC-419
and YYC-458. Four distinct destinations were rechecked with GET after the
initial HEAD scan. The old values remain in `client_source_records.payload`
on already-imported databases and in Git history; source `source_urls` fields
are retained for tracing. A further 67 URL checks timed out or were otherwise
inconclusive and were not changed. Client confirmation remains appropriate
before replacing any missing registration destination.
