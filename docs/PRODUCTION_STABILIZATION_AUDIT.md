# Production stabilization audit

Last updated: 2026-10-03

This is the working evidence register for the post-release FitCalgary V1
stabilization pass. A status of `PASS` records an executed check. Simulator and
emulator results are not physical-device verification.

## Defect register

| ID | Priority | Finding | Root cause | Resolution / status |
|---|---|---|---|---|
| AUTH-001 | P1 | Registration reaches an email-delivery error in production. | The live Keycloak realm requires verified email, but its SMTP configuration is empty. Railway logs record `Invalid sender address 'null'`. | `BLOCKED_EXTERNAL`: configure a verified SMTP provider/sender, then receive and open a real verification message. Email verification is intentionally still enabled. |
| AUTH-002 | P1 | Google sign-in fails in production. | The live Google identity provider is disabled and has no client ID or secret. | Mobile now routes directly to the Google broker alias and has regression coverage. `BLOCKED_EXTERNAL` for Google OAuth credentials and live-provider verification. |
| AUTH-003 | P1 | Apple sign-in fails in production. | The realm import used unsupported provider ID `apple`; the live provider is absent and Apple credentials are not available. | Realm source now uses Keycloak's standards-based OIDC provider with Apple's documented endpoints. Mobile routes directly to the Apple alias. The Apple Developer account has the existing FitCalgary App ID with Sign in with Apple enabled and a newly created Services ID, `ca.fitcalgary.index.auth`. That Services ID's web capability, return URL, signing key and live Keycloak broker remain unconfigured; no Apple login is verified. |
| AUTH-004 | P2 | Google and Apple buttons opened the generic Keycloak sign-in page rather than their selected providers. | Both buttons invoked the same provider-neutral method. | Fixed with `kc_idp_hint`; Flutter regression tests pass. |
| AUTH-005 | P1 | A protected mobile API request could fail to settle when refreshing an expired session throws; a public directory request could also fail before reaching the API during an identity outage. | The Dio interceptors awaited identity refresh without handling exceptions, including before public requests. | The original 401 now completes if refresh fails, while public reads can proceed without a token. Empty provider access tokens are also rejected before persistence. Three regression tests, the 28-test Flutter suite and static analysis pass. Replacement mobile binaries are required; this is **not yet store verified**. |
| WEB-001 | P1 | Live profile and admin sign-in returned HTTP 503. | The Cloudflare Worker retained its encrypted session secrets but the latest deployment had no runtime bindings for the public URL, API URL, issuer or web client ID. | Fixed by restoring the four production bindings. Profile and admin entry points now return a PKCE authorization redirect to the live Keycloak realm. |
| WEB-002 | P2 | A malformed HTTP 200 token response could produce the literal web access token `undefined`; sign-in configuration failures could expose internal error text; an identity-provider outage could unnecessarily clear a valid session. | The callback and refresh paths coerced absent token fields to strings, the login route returned the caught exception message, and session errors were not distinguished from service outages. | Token responses now require a nonempty access token and valid expiry before a session is stored; sign-in returns a safe message. Return paths reject cross-origin and control-character inputs. Revoked refresh tokens clear sessions while temporary provider outages preserve them. Eight web-auth tests, lint, type-check and production build pass. Cloudflare Worker `1133c897-f783-468f-bc1f-1dd739a13415` is deployed; public pages, auth entry and anonymous protection smoke checks pass. A real authenticated session remains unverified. |
| WATCH-001 | P2 | The standalone Watch project could not be opened by Xcode. | The generated project file was invalid, while the embedded Runner target still compiled. | Regenerated from the checked-in XcodeGen specification; standalone and embedded Watch targets now build. |
| WATCH-002 | P2 | Watch home provided only a terse rank and three plain links, with no dedicated rankings experience or clear cached/offline state. | Initial companion shell was intentionally minimal. | Added real-data home summaries, dedicated results/rankings/review/event views, intentional empty states, clearer connectivity feedback and accessibility labels. |
| WATCH-003 | P1 | A Watch account with nonempty data could fail to load its entire summary. | The Go API emits snake-case result fields and fractional RFC 3339 timestamps, but the Watch decoder expected camel-case fields and basic ISO 8601 dates. Date-only events also have no `start_at`. | The Watch decoder now accepts the real API field names and timestamp precision; the event model accepts a verified day without inventing a time. An API-shaped nonempty snapshot and cache round-trip pass locally. Standalone and embedded Watch simulator builds pass; the logged-out Watch launches. A production authenticated Watch session remains unverified until sign-in works. |
| DATA-001 | P1 | The live gym index described 120 prices as complete all-in monthly costs although 114 source records had unknown annual or enrollment fees. | The approved-data importer converted unknown mandatory fees to zero and used source-derived estimates as proof of completeness. | Importer now requires explicitly known fee values; migration `0009` cleared misleading normalized figures for affected rows. A PostgreSQL 18 production backup was taken before migration. Live API now reports six confirmed-price gyms and 267 needing price confirmation, with all 273 gyms retained. |
| UI-001 | P2 | Android status-bar icons lacked contrast on the first-run dark introduction and on light home screens after navigation. | System overlay style did not follow the active route/theme. | Onboarding uses light status-bar icons; the application applies theme-aware system-bar styling elsewhere. Both appearances were visually checked in the Android emulator after rebuilding. |
| CONTENT-001 | P2 | Mobile and web described every listed competition as enterable, even though the directory includes past and undated events; raw database phase labels were visible. | The page and home copy assumed all catalog events were open, while the API intentionally returns every published event. | Replaced the claim with truthful directory copy, human-readable phase labels, and registration labels only on current/upcoming events; home cards now open their own detail page. Flutter and web label regression tests pass. |
| CONTENT-002 | P1 content dependency | All 531 live competition records originally had no structured date. | Client-supplied `next_dates` is natural-language schedule text, often approximate or multiple dates; the original importer parsed only ISO timestamps. | Three exact single-day source entries were independently corroborated and now populate a date-only field in local migration tests: YYC-172 (Sep 26), YYC-506 (Oct 24), YYC-508 (Dec 12). Their time remains unknown. The other 528 remain undated. This correction is **not yet deployed**, and registration-open status is not inferred from the date. |
| CONTENT-003 | P2 | Six competition registration links return HTTP 404. | The approved source retained links that have since disappeared. | Cleared only the six broken public website fields in the import source and added a provenance-guarded migration that hides the public action without deleting the original source payload. Local migration verified six of six links hidden. **Not yet deployed.** No replacement URL was invented. |
| SEC-001 | P1 | A database tool emitted a production PostgreSQL credential in local session output during backup. | The tunnel helper includes its connection string when closing. | Database role password and Railway Postgres/API variables rotated; API readiness and catalog verified afterward. The temporary Railway SSH key was deregistered and deleted. Remote-local tunnel authentication did not provide a valid old-password rejection test; external credential rejection remains to be independently confirmed. |
| AUTH-006 | P1 | Concurrent mobile refreshes could reuse a rotating refresh token; a late response could restore a logged-out session. | No single-flight refresh or credential-write/session revision guard. | Fixed; refresh, logout-in-flight, revoked-refresh and outage-preservation regression tests pass. New signed store binaries still required. |
| AUTH-007 | P2 | Logout could fail visibly or hang when notification cleanup or provider revocation is unavailable. | Mobile cleanup propagated API/browser failures; web revocation had no deadline. | Local cleanup now completes independently of those expected failures; web revocation is bounded. Remote revocation/delivery is not claimed without real provider verification. |
| WEB-003 | P1 | Provider network failure during the web callback could escape its error handling; the sign-in transaction was deleted on the wrong cookie path. | Exchange fetch was unguarded/unbounded and deletion did not match `/api/auth`. | Callback catches failures, bounds exchange and safely clears the transaction; regression tests and live invalid-callback checks pass. |
| WATCH-004 | P1 | A response started before logout/account change could repopulate cached athlete data afterward. | The async refresh did not check a session revision. | Response/cache updates now reject outdated revisions, logout takes precedence, and cached account data is cleared appropriately. Revision smoke and simulator build pass; authenticated device workflow remains unverified. |
| UI-002 | P2 | Small text failed contrast in selected light-theme surfaces; dark leaderboard non-podium badges were light-on-light. | Static brand colors and fixed white badge text were used across appearances. | Thematic accent/secondary colors and inverse badge text fixed. Light/dark contrast and dark-board widget tests pass. |
| ROUTE-001 | P2 | The home gym-index arrow looked like a link but had no action. | The affordance was plain text. | It is now a 44-point-minimum action routing to the directory; widget navigation regression passes. |
| WATCH-005 | P2 | Self-reported community results appeared in the Watch's verified result history. | The summary selected all non-invalidated results, including `UNVERIFIED` claims. | Verified history now excludes unverified claims while retaining official and community rankings, with explicit board labels. A real local PostgreSQL workflow asserts both boundaries. Source verified; production API deployment remains held behind the existing authentication/safety gate. |
| UI-003 | P2 | Failed pull-to-refresh leaked an unhandled future error; short inbox/review/saved lists could not be pulled to refresh. | Provider failure was awaited outside the screen's error-state handling; short lists lacked always-scrollable physics. | Refresh completion now settles without discarding the watched provider's error/retry state. Short lists remain refreshable. Directory failure/retry and actual empty-inbox drag/outage/recovery widget regressions pass. Shared error messages announce as live regions, and inbox/review loading states have semantic labels. |
| WATCH-006 | P2 | Date-only competition entries could display one calendar day early in Calgary. | UTC midnight was treated as an event instant during local date formatting. | Watch now projects date-only calendar components into the viewer's zone; real timed events keep their instant. Smoke assertions pass for Edmonton, Vancouver, Auckland, UTC, cache round-trip, timed and missing dates. Standalone Watch simulator build passes. |
| ROUTE-002 | P2 | Club/event detail pages had no back control; the selected Compete tab could not return to its directory. | Detail content lacked an exit affordance, and tab selection ignored every route sharing its tab index. | Added a back control with directory fallback and made tab no-op conditional on the exact root path. The selected-tab and back-control regression first failed, then passed after correction. |
| CONTENT-004 | P2 | Date-only event detail responses used a timestamp, unlike directory responses; the web date-only formatter would receive an invalid concatenated timestamp. | Raw PostgreSQL DATE columns were serialized as Go time values, while PostgreSQL JSON aggregation already used YYYY-MM-DD. | Typed event start_date columns now use the consistent calendar-date contract; actual timestamp and established profile formats are unchanged. Local PostgreSQL regression reproduced the mismatch before correction. Production API deployment remains held behind the existing safety gate. |

## Executed evidence

### Current independent stabilization pass

- Web callback now bounds code exchange to 15 seconds, handles provider/network
  and malformed-token failures safely, revalidates the return path, and clears
  the transaction cookie on its actual `/api/auth` path. Refresh is also bounded;
  logout revocation is bounded to five seconds. Ten web-auth regression tests,
  lint, type checking and production build pass.
- Mobile refresh exchanges are single-flight. Session revisions and serialized
  credential writes reject late refresh/sign-in responses after logout or account
  change. Local logout clears credentials before the browser/provider completes.
  A failed optional Watch sync no longer fails phone authentication. Provider
  logout cancellation does not undo local sign-out; server-side revocation is
  **not** claimed if the provider is unavailable.
- Notification API cleanup failure no longer prevents local sign-out and the
  subsequent provider-token deletion attempt. Remote push delivery/revocation
  still requires real provider testing.
- Watch rejects in-flight data from a previous session, clears cached data on
  credential changes/logout, and does not restore account data without a token.
  Empty offline state no longer claims a previous update exists. The native
  watchOS glass surface uses opaque/high-contrast fallbacks for Reduce
  Transparency and increased contrast. Codec/session-invalidation smoke and
  standalone simulator build pass; logged-out Series 12 simulator launch was
  visually inspected. Authenticated and physical Watch tests remain unverified.
- Measured small-text contrast defects were corrected without changing the
  brand: light-theme secondary text and filled actions now meet 4.5:1; dark
  leaderboard ranks beyond the podium no longer render light-on-light. Theme
  and dark-board regression coverage added. This is not a full VoiceOver,
  TalkBack, performance or screen-by-screen acceptance claim.

Current executed checks: **44 Flutter tests**, Flutter analysis, **10 web-auth
tests**, web lint/type-check/production build, Watch codec/session-invalidation
smoke and standalone Watch simulator build. Updated iOS simulator build includes
the embedded Watch target; Android debug APK builds successfully with production
endpoint configuration. These are not signed replacement store artifacts.
The iOS app launches and its dark home screen was inspected against the live
catalog. Watch logged-out launch was inspected. Android installation/launch passed
with the latest session and contrast changes in this pass. Its dark home was
visually inspected, with no AndroidRuntime error in the captured log. iPad
simulator first-launch onboarding was also inspected. Signed release builds and
full authenticated device workflows still remain unverified.

The complete Go suite now passes with the PostgreSQL-backed competition
workflow enabled, including immediate role revocation, stale-role refresh/re-login,
restoration, judge decisions, ranking and Watch verified-history boundaries.
The existing migrations were applied only to the isolated loopback test database
before running this workflow. Go vet and production binary build pass. Storage
and identity-provider interactions in this workflow use controlled mocks; these
results do not verify real SMTP, social login or production evidence storage.

Additional mobile regressions prove that revoked refresh tokens clear local
credentials without a browser logout, temporary provider failures preserve the
credentials for retry, and refresh retains the prior ID token when a provider
omits its replacement. These tests use development fakes, not real provider login.

Subsequent runtime inspection identified low-contrast dark gym operator labels
and account error text; those now use the appearance-aware brand accent. Sign-in
errors announce as a live semantic region and clear on retry. Android public
navigation reached the production gym directory (273 locations and truthful
known/unknown pricing) and the official/community leaderboard entry screen.
Live Go health/readiness return 200; anonymous profile, Watch summary, submissions,
notifications and admin requests all return 401. These are not authenticated
workflow or exhaustive accessibility/performance checks.

Fresh Android emulator, iPhone simulator and iPad simulator integration tests against the
production-configured app pass first launch, all onboarding steps, Home, Gyms, Board, Compete and Me,
and persisted onboarding completion. The old test assertion was updated to
the already-corrected competition heading; no product copy was regressed.
The 42 mm and 46 mm Watch simulators launch the current companion and show a
readable logged-out account-connect state. Populated account screens and real
Watch connectivity remain unverified until authenticated access is available.

Cloudflare Worker `5f06bc8d-f335-4c74-b1a4-416070c77b80` contains the current web
callback/logout/contrast fixes. Home, gyms, clubs, events, privacy and support
return HTTPS 200; invalid callback returns 307 with transaction-cookie removal
on `/api/auth`, and anonymous admin API returns 401. Full authenticated sessions
are still not verified.

### Exact external actions remaining

1. Confirm the authorized FitCalgary/FitAlberta sending domain and provide its
   DNS operator access. No changes were made to HBIC Resend or DNS, and
   `fitxplor.com` is not assumed authorized. Real email receipt remains unverified.
2. Identify the dedicated FitCalgary Google project or authorize creating one.
   Read-only inventory showed HBIC projects, a default project and My First
   Project; none is clearly FitCalgary. No Google project configuration changed.
   Exact broker/OAuth setup is documented in `infrastructure/keycloak/README.md`.
3. Complete Apple Services ID web configuration and authorize/secure its signing
   key. Test the completed provider on real iPhone hardware.
4. Connect authorized physical iPhone/Android/Watch devices for the corresponding
   device-only verification. Currently connected Apple targets are simulators.

Store replacement uploads and final Client export/push remain gated. Client
source/history has not been modified. Work still required independently:
finish screen-by-screen visual/accessibility/performance checks and the complete
authenticated production acceptance matrix once provider access is available.

### Continuation point

- Latest new checks: 44 Flutter tests and analysis pass; Watch codec/date/session
  smoke and standalone simulator build pass. The new refresh regression first
  reproduced an unhandled failure, and the date regression first reproduced the
  previous-day error before the fixes.
- Read-only iPhone simulator integration exercised the live gym directory,
  gym detail, no-match search, club directory and club detail successfully.
  No production catalog/account writes were performed. This is not an
  authenticated workflow or a claim about every imported listing's accuracy.
- Android emulator passed the same read-only catalog flow, including returning
  from club detail to the Compete directory with the corrected selected tab.
- Current fixes have no SMTP/social-provider configuration changes. Existing
  production auth blockers remain open, not waived. Store binaries are still
  older than these source fixes.
- Next independent work: complete the remaining screen-by-screen failure-state
  and accessibility checks, then prepare signed replacements only once source
  stabilizes. Real-provider end-to-end tests require the exact external actions
  above. Do not modify HBIC or the Client repository.
- Phone floating surfaces currently use Flutter material/blur with accessible
  opaque fallbacks, not native UIKit Liquid Glass. Watch uses supported native
  watchOS glass with fallbacks. Full native phone treatment and final visual
  approval are not represented as complete by these regression tests.

| Area | Result | Evidence |
|---|---|---|
| Production web | PASS | Home, privacy and support return HTTPS 200. |
| Production API | PASS | `/health` and database-backed `/ready` return HTTPS 200. |
| Production OIDC discovery | PASS | Realm discovery returns HTTPS 200. |
| Web authentication entry | PASS | Profile and admin sign-in return a PKCE authorization redirect to the production realm; anonymous admin proxy access returns 401. Full authenticated completion still depends on working account/provider credentials. |
| Approved catalogue | PASS | Live API totals: 273 gyms, 743 clubs, 531 competitions. |
| Flutter static analysis | PASS | Flutter 3.47.2 reports no issues after the broker-routing fix. |
| Flutter tests | PASS | 28 tests pass, including Google/Apple provider-hint, event-status copy, failed-refresh handling, empty-token rejection and guest browsing through an identity outage. |
| Go tests | PASS | All non-external Go packages pass; external integration tests remain explicitly skipped without isolated resources. |
| Go vet and production build | PASS | `go vet ./...` and `go build ./cmd/api` pass. |
| Apple Watch compile | PASS | Refined source builds through both the standalone XcodeGen project and the Watch target embedded in Runner. |
| iOS simulator | PASS | Production-configured Flutter app built and launched on iPhone 17 Pro simulator. |
| Android emulator | PASS | Production-configured debug APK built, installed and launched on Pixel 9 API 36 emulator; onboarding to home flow exercised. This is not a signed store build. |
| Pricing correction | PASS | Fresh PostgreSQL 17 import yields `6 complete / 114 incomplete` price rows; migration tested against intentionally stale rows, then applied to backed-up Railway PostgreSQL 18 with the same result. Live public gym filter returns six complete prices, 267 incomplete gym listings; API readiness remains 200. |
| Web deployment | PASS | Current web build deployed to Cloudflare Workers; home, gyms, events, leaderboards, privacy, support and account-deletion pages return HTTPS 200. Profile/admin authentication entry returns 307 to production OIDC and anonymous admin API returns 401. |
| Web session validation | DEPLOYED; AUTHENTICATED FLOW PENDING | Eight web-auth tests include malformed token responses, return-path rejection and revoked-versus-unavailable refresh handling; lint, TypeScript checking and production build pass. Worker `1133c897-f783-468f-bc1f-1dd739a13415` is live. Home, gyms, events, privacy and support return 200; OIDC start returns 307; anonymous admin proxy returns 401. A working production account/provider is still required to prove the full session path. |
| Event copy deployment | PASS | Cloudflare Worker version `8f73360c-c8ab-4e79-9f2a-02afb12c75ef` serves the corrected events heading and status labels. Live home/events/public-events return 200; admin authentication entry remains 307 and API readiness 200. |
| Competition date recovery | LOCAL PASS; PRODUCTION PENDING | Source scan found 3 exact single-day dates in 531 records. Local PostgreSQL migration 0010 yielded 3 dated and 528 undated records; real local API queries returned 3 upcoming, 528 undated and correct month filtering. Flutter/Go/web regression checks pass. The live API has not received migration 0010. |
| Competition URL audit | LOCAL PASS; PRODUCTION PENDING | Of 531 records, 509 contained a website string, 506 were syntactically valid and 22 were absent. A bounded HTTP check covered 395 unique public URLs; six record links were confirmed 404 after GET recheck. 67 other requests were unavailable or inconclusive, not classified as broken. Local migration 0011 hid all six confirmed links. |
| Watch nonempty-data decoding | LOCAL PASS; PRODUCTION PENDING | `WatchSnapshotCodecSmoke.swift` decodes representative Go-shaped rankings, approved results, submissions, fractional timestamps and a date-only event, then reloads the cache. Standalone Watch and embedded iOS/Watch simulator builds pass; the Watch app launches in the simulator. Real account data and physical hardware remain unverified. |
| Stabilization smoke | PASS, LIMITED | Live web home, gyms, clubs, events and leaderboards return HTTPS 200; API health/readiness and OIDC discovery return 200; anonymous admin API returns 401. These are reachability and access-boundary checks, not authenticated end-to-end proof. |
| Content quality | REVIEW REQUIRED | Supplied source has 273 gyms, 743 clubs and 531 competitions. It includes 153 gyms without an advertised membership price, 546 clubs without a street address, 223 clubs without a website, 151 competition date fields missing or explicitly not fetched, and 166 low-confidence competition records. These are source-data gaps, not facts to invent. |

## Verification boundaries

- Email registration, password-reset delivery, Google login and Apple login are
  not production verified until the corresponding externally controlled
  provider configuration is supplied and tested end to end.
- The Apple Developer Services ID exists but is not yet a working Sign in with
  Apple integration. Its web domain/return URL and a signing key must be
  configured before enabling the Keycloak broker. The currently open Google
  Cloud project is unrelated to FitCalgary and must not be modified to fill the
  missing FitCalgary OAuth credentials. A Resend account is now signed in on
  this Mac, but a verified sending domain, SMTP credential and live email
  receipt have not been confirmed for Keycloak.
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
