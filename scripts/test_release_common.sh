#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$root/scripts/release_common.sh"
config="$(mktemp)"
output="$(mktemp -d)"
trap 'unlink "$config"; rmdir "$output"' EXIT
# Test-only values; no store build or production connection is made.
printf '%s\n' \
  'PRODUCTION_BUILD=true' \
  'API_BASE_URL=https://api.example.org/api/v1' \
  'OIDC_ISSUER=https://auth.example.org/realms/fitcalgary' \
  'OIDC_CLIENT_ID=fitcalgary-mobile' \
  'ALLOW_INSECURE_OIDC=false' \
  'FITCALGARY_ASSOCIATED_DOMAIN=example.org' > "$config"
export FITCALGARY_PRODUCTION_CONFIG="$config"
export FITCALGARY_RELEASE_OUTPUT="$output"
export FITCALGARY_FLUTTER=/usr/bin/true
export FITCALGARY_JAVA_HOME=/example/operator-jdk
fc_prepare_release
[[ "$FC_FLUTTER" == /usr/bin/true ]]
[[ "$FC_JAVA_HOME" == /example/operator-jdk ]]
unset FITCALGARY_FLUTTER FITCALGARY_JAVA_HOME
export JAVA_HOME=/example/environment-jdk
fc_prepare_release
[[ -x "$FC_FLUTTER" ]]
[[ "$FC_JAVA_HOME" == /example/environment-jdk ]]
if (fc_validate_https_url API_BASE_URL http://localhost:4000) >/dev/null 2>&1; then
  printf 'Insecure release configuration was accepted\n' >&2
  exit 1
fi
printf 'Release tool discovery, overrides and insecure-endpoint rejection PASS\n'
