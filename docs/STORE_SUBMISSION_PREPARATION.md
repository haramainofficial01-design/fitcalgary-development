# FitCalgary V1 store submission preparation

This document records the release artifacts prepared from the current source
without claiming store upload or approval.

## Application identity

- Product name: FitCalgary Index
- Bundle identifier: `ca.fitcalgary.index`
- Version: `1.0.0` / build `1`
- Android application ID: `ca.fitcalgary.index`
- Brand icon master: `brand/generated/fitcalgary-app-icon-v1.png`
- iOS and Android icon sets: generated from the same approved brand master
- Launch screens: FitCalgary cream/black/coral launch mark on both platforms

## Prepared artifacts

- iOS: unsigned `Runner.xcarchive` produced with `flutter build ipa --release --no-codesign`
- Android: `app-release.aab` produced with `flutter build appbundle --release`
- Simulator/emulator debug builds: rebuilt and launched after the release identity update
- Web: production `vinext` build completed and ready for hosting

## Final publishing inputs

The following are the only release actions that cannot be completed from the
local source tree alone:

1. Production hosting and a temporary HTTPS address, followed by the Client's
   final FitCalgary/FitAlberta domain connection.
2. Production API, PostgreSQL, private storage, Keycloak, email and push-provider
   credentials in the deployment secret manager.
3. Apple Developer/App Store Connect signing access and Google Play Console
   upload access.
4. Physical iPhone, Android phone and Apple Watch validation before submission.
5. Client-approved privacy/support/store listing information and third-party
   review decisions.

These dependencies do not require source changes. The release configuration,
metadata hooks, entitlements, build scripts, migration/runbook documentation and
platform assets are already present and are intended to be connected at the
publishing step.
