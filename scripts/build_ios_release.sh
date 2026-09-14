#!/usr/bin/env bash

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release_common.sh"
fc_prepare_release

identity_output="$(security find-identity -v -p codesigning 2>/dev/null)"
distribution_line="$(printf '%s\n' "$identity_output" | /usr/bin/grep -E 'Apple Distribution:|iPhone Distribution:' | /usr/bin/head -1 || true)"
[ -n "$distribution_line" ] || fc_fail "No Apple Distribution signing identity is installed. Add the Apple Developer account in Xcode and create/download an Apple Distribution certificate."

detected_team="$(printf '%s\n' "$distribution_line" | /usr/bin/sed -nE 's/.*\(([A-Z0-9]{10})\).*/\1/p')"
apple_team="${FITCALGARY_APPLE_TEAM_ID:-$detected_team}"
[[ "$apple_team" =~ ^[A-Z0-9]{10}$ ]] || fc_fail "Set FITCALGARY_APPLE_TEAM_ID to the 10-character Apple Developer Team ID"
if [ -n "$detected_team" ] && [ "$detected_team" != "$apple_team" ]; then
  fc_fail "The selected Apple Team does not match the installed Apple Distribution identity"
fi

main_bundle="$(xcodebuild -workspace "$FC_APP/ios/Runner.xcworkspace" -scheme Runner -configuration Release -showBuildSettings 2>/dev/null | /usr/bin/awk -F' = ' '/PRODUCT_BUNDLE_IDENTIFIER = ca\.fitcalgary\.index$/ {print $2; exit}')"
watch_bundle="$(xcodebuild -project "$FC_APP/ios/Runner.xcodeproj" -target FitCalgaryWatch -configuration Release -showBuildSettings 2>/dev/null | /usr/bin/awk -F' = ' '/PRODUCT_BUNDLE_IDENTIFIER/ {print $2; exit}')"
[ "$main_bundle" = "ca.fitcalgary.index" ] || fc_fail "Unexpected iOS bundle ID: ${main_bundle:-missing}"
[ "$watch_bundle" = "ca.fitcalgary.index.watchkitapp" ] || fc_fail "Unexpected Watch bundle ID: ${watch_bundle:-missing}"

ios_output="$FC_RELEASE_OUTPUT/ios"
archive_path="$ios_output/FitCalgary.xcarchive"
export_path="$ios_output/export"
export_options="$ios_output/ExportOptions.plist"
mkdir -p "$export_path"

/usr/bin/python3 - "$export_options" "$apple_team" <<'PY'
import plistlib
import sys
path, team = sys.argv[1:]
payload = {
    "destination": "export",
    "method": "app-store-connect",
    "signingStyle": "automatic",
    "teamID": team,
    "uploadSymbols": True,
    "manageAppVersionAndBuildNumber": False,
}
with open(path, "wb") as handle:
    plistlib.dump(payload, handle)
PY

cd "$FC_APP"
"$FC_FLUTTER" pub get
"$FC_FLUTTER" build ios --release --config-only \
  --build-name="$FC_BUILD_NAME" \
  --build-number="$FC_BUILD_NUMBER" \
  --dart-define-from-file="$FITCALGARY_PRODUCTION_CONFIG"

xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive_path" \
  DEVELOPMENT_TEAM="$apple_team" \
  CODE_SIGN_STYLE=Automatic \
  FITCALGARY_ASSOCIATED_DOMAIN="$FC_ASSOCIATED_DOMAIN" \
  FLUTTER_BUILD_NAME="$FC_BUILD_NAME" \
  FLUTTER_BUILD_NUMBER="$FC_BUILD_NUMBER" \
  -allowProvisioningUpdates \
  archive

xcodebuild -exportArchive \
  -archivePath "$archive_path" \
  -exportPath "$export_path" \
  -exportOptionsPlist "$export_options" \
  -allowProvisioningUpdates

ipa_path="$(find "$export_path" -maxdepth 1 -name '*.ipa' -print -quit)"
[ -n "$ipa_path" ] || fc_fail "The signed IPA was not exported"
archive_app="$archive_path/Products/Applications/Runner.app"
archive_bundle="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$archive_app/Info.plist")"
[ "$archive_bundle" = "ca.fitcalgary.index" ] || fc_fail "Archive bundle ID mismatch"
watch_app="$(find "$archive_app/Watch" -maxdepth 1 -name '*.app' -print -quit 2>/dev/null || true)"
[ -n "$watch_app" ] || fc_fail "The FitCalgary Watch companion was not embedded in the iOS archive"
embedded_watch_bundle="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$watch_app/Info.plist")"
[ "$embedded_watch_bundle" = "ca.fitcalgary.index.watchkitapp" ] || fc_fail "Embedded Watch bundle ID mismatch"
codesign --verify --deep --strict "$archive_app"

printf 'IOS RELEASE READY\n'
printf 'Bundle ID: %s\n' "$archive_bundle"
printf 'Watch bundle ID: %s\n' "$embedded_watch_bundle"
printf 'Apple Team: %s\n' "$apple_team"
printf 'Version: %s\n' "$FC_BUILD_NAME"
printf 'Build: %s\n' "$FC_BUILD_NUMBER"
printf 'Archive: %s\n' "$archive_path"
printf 'IPA: %s\n' "$ipa_path"
