# FitCalgary store signing and submission

## Release identity

- Product name: FitCalgary
- iOS and Android identifier: `ca.fitcalgary.index`
- Watch companion identifier: `ca.fitcalgary.index.watchkitapp`
- Watch companion app: included with the iOS submission; it does not receive a
  separate App Store listing.
- Version source: `apps/fitcalgary_app/pubspec.yaml` (`1.0.0+1` initially).

## Android signing

The local Play upload key is stored outside Git at:

`~/Library/Application Support/FitCalgary/credentials/android/fitcalgary-upload.jks`

Alias: `fitcalgary-upload`. Its passwords are stored as macOS Keychain generic
password items. Back up the keystore to a second encrypted location and retain
the Keychain credentials; losing the upload key requires Google Play's upload-key
reset process.

Local Play upload-key certificate fingerprints:

- SHA-256: `03:B8:69:B2:1F:3C:20:54:CA:ED:60:32:FE:36:95:DD:68:3B:87:8A:7F:8D:D9:69:6A:3F:67:D8:12:D5:29:43`
- SHA-1: `75:C5:4A:12:7D:78:E8:13:A6:3D:34:AA:35:CD:B5:63:4B:3D:A7:34`

The upload key signs AAB files sent to Google Play. Google Play App Signing uses
a separate Google-controlled app-signing key for APKs delivered to users. Do not
describe the local upload certificate as the Play app-signing certificate.

If Play Console still requests manual package verification after the app record
is created, use the **local Play upload key** SHA-256 fingerprint printed by
`scripts/build_android_release.sh`. Do not invent or substitute a Google Play
app-signing fingerprint before Play creates it.

The earlier locally generated AAB was confirmed to use the standard Android
debug certificate and was quarantined outside tracked source. It must not be
uploaded. The release script replaces it only after real production URLs and a
real associated domain are supplied.

## Apple setup

Create or select these identifiers under the correct Apple Developer Team:

- `ca.fitcalgary.index`: Push Notifications, Sign in with Apple and Associated
  Domains.
- `ca.fitcalgary.index.watchkitapp`: Push Notifications and its companion
  relationship to `ca.fitcalgary.index`.

Use automatic signing. The main app and Watch target must use the same Team.
The release script requires an installed Apple Distribution identity and a real
associated domain.

App Store Connect record:

- Platform: iOS
- Name: FitCalgary
- Primary language: English (Canada), or English (U.S.) if unavailable
- Bundle ID: `ca.fitcalgary.index`
- SKU: `FITCALGARY-IOS-001`
- User access: Full Access

## Commands

Copy `config/release/mobile-production.env.example` outside the repository to
`~/Library/Application Support/FitCalgary/config/mobile-production.env`, replace
all placeholders, then run from the repository root:

```bash
./scripts/build_android_release.sh
./scripts/build_ios_release.sh
```

Override `FITCALGARY_BUILD_NAME` and `FITCALGARY_BUILD_NUMBER` for later uploads.
Each store upload requires a new build number/version code.
