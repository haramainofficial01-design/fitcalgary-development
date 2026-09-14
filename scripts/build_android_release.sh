#!/usr/bin/env bash

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release_common.sh"
fc_prepare_release

export JAVA_HOME="$FC_JAVA_HOME"
export PATH="$JAVA_HOME/bin:$PATH"

keystore_path="${FITCALGARY_RELEASE_KEYSTORE:-$HOME/Library/Application Support/FitCalgary/credentials/android/fitcalgary-upload.jks}"
key_alias="${FITCALGARY_RELEASE_KEY_ALIAS:-fitcalgary-upload}"
keychain_account="$(id -un)"

[ -x "$JAVA_HOME/bin/keytool" ] || fc_fail "keytool not found under $JAVA_HOME"
[ -x "$JAVA_HOME/bin/jarsigner" ] || fc_fail "jarsigner not found under $JAVA_HOME"
[ -f "$keystore_path" ] || fc_fail "FitCalgary Play upload keystore not found at $keystore_path"

export FITCALGARY_RELEASE_KEYSTORE="$keystore_path"
export FITCALGARY_RELEASE_KEY_ALIAS="$key_alias"
export FITCALGARY_RELEASE_STORE_PASSWORD="$(security find-generic-password -a "$keychain_account" -s 'FitCalgary Android Upload Store Password' -w 2>/dev/null)" || fc_fail "Upload-keystore password is missing from macOS Keychain"
export FITCALGARY_RELEASE_KEY_PASSWORD="$(security find-generic-password -a "$keychain_account" -s 'FitCalgary Android Upload Key Password' -w 2>/dev/null)" || fc_fail "Upload-key password is missing from macOS Keychain"
trap 'unset FITCALGARY_RELEASE_STORE_PASSWORD FITCALGARY_RELEASE_KEY_PASSWORD' EXIT

expected_sha256="$($JAVA_HOME/bin/keytool -J-Duser.language=en -list -v -keystore "$keystore_path" -alias "$key_alias" -storepass:env FITCALGARY_RELEASE_STORE_PASSWORD | /usr/bin/awk -F'SHA256:' '/SHA256:/ {gsub(/[[:space:]]/, "", $2); print $2; exit}')"
[ -n "$expected_sha256" ] || fc_fail "Unable to read the upload certificate fingerprint"

cd "$FC_APP"
"$FC_FLUTTER" pub get
"$FC_FLUTTER" build appbundle --release \
  --build-name="$FC_BUILD_NAME" \
  --build-number="$FC_BUILD_NUMBER" \
  --dart-define-from-file="$FITCALGARY_PRODUCTION_CONFIG" \
  --android-project-arg="FITCALGARY_APP_LINK_HOST=$FC_ASSOCIATED_DOMAIN"

aab_path="$FC_APP/build/app/outputs/bundle/release/app-release.aab"
[ -f "$aab_path" ] || fc_fail "Expected AAB was not produced at $aab_path"
"$JAVA_HOME/bin/jarsigner" -verify -strict "$aab_path" >/dev/null
actual_sha256="$($JAVA_HOME/bin/keytool -J-Duser.language=en -printcert -jarfile "$aab_path" | /usr/bin/awk -F'SHA256:' '/SHA256:/ {gsub(/[[:space:]]/, "", $2); print $2; exit}')"
[ "$actual_sha256" = "$expected_sha256" ] || fc_fail "The AAB signer does not match the dedicated FitCalgary Play upload key"

apk_path=""
if [ "${FITCALGARY_BUILD_RELEASE_APK:-false}" = "true" ]; then
  "$FC_FLUTTER" build apk --release \
    --build-name="$FC_BUILD_NAME" \
    --build-number="$FC_BUILD_NUMBER" \
    --dart-define-from-file="$FITCALGARY_PRODUCTION_CONFIG" \
    --android-project-arg="FITCALGARY_APP_LINK_HOST=$FC_ASSOCIATED_DOMAIN"
  apk_path="$FC_APP/build/app/outputs/flutter-apk/app-release.apk"
fi

printf 'ANDROID RELEASE READY\n'
printf 'Package: ca.fitcalgary.index\n'
printf 'Version name: %s\n' "$FC_BUILD_NAME"
printf 'Version code: %s\n' "$FC_BUILD_NUMBER"
printf 'Upload alias: %s\n' "$key_alias"
printf 'Upload SHA-256: %s\n' "$expected_sha256"
printf 'Signed AAB: %s\n' "$aab_path"
if [ -n "$apk_path" ]; then printf 'Signed APK: %s\n' "$apk_path"; fi
