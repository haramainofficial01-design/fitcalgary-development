#!/usr/bin/env bash

set -euo pipefail

fc_fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

fc_config_value() {
  local key="$1"
  /usr/bin/awk -v requested="$key" '
    /^[[:space:]]*#/ { next }
    {
      separator = index($0, "=")
      if (separator == 0) next
      key = substr($0, 1, separator - 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      if (key == requested) value = substr($0, separator + 1)
    }
    END {
      gsub(/\r$/, "", value)
      print value
    }
  ' "$FITCALGARY_PRODUCTION_CONFIG"
}

fc_require_value() {
  local name="$1"
  local value="$2"
  [ -n "$value" ] || fc_fail "$name is required in $FITCALGARY_PRODUCTION_CONFIG"
}

fc_validate_https_url() {
  local name="$1"
  local value="$2"
  local normalized
  fc_require_value "$name" "$value"
  case "$value" in
    https://*) ;;
    *) fc_fail "$name must use HTTPS" ;;
  esac
  normalized="$(printf '%s' "$value" | /usr/bin/tr '[:upper:]' '[:lower:]')"
  case "$normalized" in
    *localhost*|*127.0.0.1*|*::1*|*.invalid*|*@*)
      fc_fail "$name must be a real production URL without loopback, .invalid, or embedded credentials"
      ;;
  esac
}

fc_validate_domain() {
  local value="$1"
  local normalized
  fc_require_value "FITCALGARY_ASSOCIATED_DOMAIN" "$value"
  normalized="$(printf '%s' "$value" | /usr/bin/tr '[:upper:]' '[:lower:]')"
  case "$normalized" in
    *localhost*|*.invalid|*://*|*/*|*' '*)
      fc_fail "FITCALGARY_ASSOCIATED_DOMAIN must be a bare real domain without a scheme, path, localhost, or .invalid"
      ;;
  esac
}

fc_prepare_release() {
  FC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  FC_APP="$FC_ROOT/apps/fitcalgary_app"
  FC_FLUTTER="$FC_ROOT/.tooling/flutter/bin/flutter"
  FC_JAVA_HOME="${FITCALGARY_JAVA_HOME:-/Users/sahlshafiq/.fitcalgary-tooling/jdk-21}"
  FITCALGARY_PRODUCTION_CONFIG="${FITCALGARY_PRODUCTION_CONFIG:-$HOME/Library/Application Support/FitCalgary/config/mobile-production.env}"
  FC_RELEASE_OUTPUT="${FITCALGARY_RELEASE_OUTPUT:-$HOME/Library/Application Support/FitCalgary/release}"

  [ -x "$FC_FLUTTER" ] || fc_fail "Flutter executable not found at $FC_FLUTTER"
  [ -f "$FITCALGARY_PRODUCTION_CONFIG" ] || fc_fail "Production config is missing. Copy config/release/mobile-production.env.example to $FITCALGARY_PRODUCTION_CONFIG and replace every placeholder."

  FC_PRODUCTION_BUILD="$(fc_config_value PRODUCTION_BUILD)"
  FC_API_BASE_URL="$(fc_config_value API_BASE_URL)"
  FC_OIDC_ISSUER="$(fc_config_value OIDC_ISSUER)"
  FC_OIDC_CLIENT_ID="$(fc_config_value OIDC_CLIENT_ID)"
  FC_ALLOW_INSECURE_OIDC="$(fc_config_value ALLOW_INSECURE_OIDC)"
  FC_ASSOCIATED_DOMAIN="$(fc_config_value FITCALGARY_ASSOCIATED_DOMAIN)"

  [ "$FC_PRODUCTION_BUILD" = "true" ] || fc_fail "PRODUCTION_BUILD must be true"
  [ "$FC_ALLOW_INSECURE_OIDC" = "false" ] || fc_fail "ALLOW_INSECURE_OIDC must be false"
  fc_validate_https_url API_BASE_URL "$FC_API_BASE_URL"
  fc_validate_https_url OIDC_ISSUER "$FC_OIDC_ISSUER"
  fc_require_value OIDC_CLIENT_ID "$FC_OIDC_CLIENT_ID"
  fc_validate_domain "$FC_ASSOCIATED_DOMAIN"

  local firebase_project firebase_app firebase_key firebase_sender firebase_any
  firebase_project="$(fc_config_value FIREBASE_PROJECT_ID)"
  firebase_app="$(fc_config_value FIREBASE_APP_ID)"
  firebase_key="$(fc_config_value FIREBASE_API_KEY)"
  firebase_sender="$(fc_config_value FIREBASE_MESSAGING_SENDER_ID)"
  firebase_any="${firebase_project}${firebase_app}${firebase_key}${firebase_sender}"
  if [ -n "$firebase_any" ]; then
    fc_require_value FIREBASE_PROJECT_ID "$firebase_project"
    fc_require_value FIREBASE_APP_ID "$firebase_app"
    fc_require_value FIREBASE_API_KEY "$firebase_key"
    fc_require_value FIREBASE_MESSAGING_SENDER_ID "$firebase_sender"
  fi

  local version_line
  version_line="$(/usr/bin/awk '/^version:[[:space:]]*/ {print $2; exit}' "$FC_APP/pubspec.yaml")"
  FC_BUILD_NAME="${FITCALGARY_BUILD_NAME:-${version_line%%+*}}"
  FC_BUILD_NUMBER="${FITCALGARY_BUILD_NUMBER:-${version_line##*+}}"
  [[ "$FC_BUILD_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fc_fail "Invalid build name: $FC_BUILD_NAME"
  [[ "$FC_BUILD_NUMBER" =~ ^[0-9]+$ ]] || fc_fail "Invalid build number: $FC_BUILD_NUMBER"
  mkdir -p "$FC_RELEASE_OUTPUT"
}
