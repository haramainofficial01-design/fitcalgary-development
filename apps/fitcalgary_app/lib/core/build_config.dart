import 'package:flutter/foundation.dart';

/// Compile-time configuration shared by mobile, web and the watch bridge.
///
/// Development keeps convenient loopback defaults. Release builds must pass
/// `PRODUCTION_BUILD=true` together with HTTPS service URLs; missing or
/// insecure values fail at startup instead of silently targeting localhost.
abstract final class BuildConfig {
  static const production = bool.fromEnvironment(
    'PRODUCTION_BUILD',
    // Release mode is fail-closed by default. Local release builds can opt
    // into development endpoints explicitly with PRODUCTION_BUILD=false.
    defaultValue: kReleaseMode,
  );
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _oidcIssuer = String.fromEnvironment('OIDC_ISSUER');
  static const _oidcClientId = String.fromEnvironment('OIDC_CLIENT_ID');

  static String get apiBaseUrl => _url(
    name: 'API_BASE_URL',
    value: _apiBaseUrl,
    fallback: 'http://localhost:4000/api/v1',
  );

  static String get oidcIssuer => _url(
    name: 'OIDC_ISSUER',
    value: _oidcIssuer,
    fallback: 'http://localhost:8080/realms/fitcalgary',
  );

  static String get oidcClientId => _required(
    name: 'OIDC_CLIENT_ID',
    value: _oidcClientId,
    fallback: 'fitcalgary-mobile',
  );

  static bool get allowInsecureOidc =>
      !production && bool.fromEnvironment('ALLOW_INSECURE_OIDC');

  static String _required({
    required String name,
    required String value,
    required String fallback,
  }) {
    if (value.isEmpty) {
      if (production) {
        throw StateError('$name is required for a production build');
      }
      return fallback;
    }
    return value;
  }

  static String _url({
    required String name,
    required String value,
    required String fallback,
  }) {
    final resolved = _required(name: name, value: value, fallback: fallback);
    if (!production) return resolved;
    final uri = Uri.tryParse(resolved);
    final host = uri?.host.toLowerCase();
    if (uri == null || uri.scheme != 'https' || host == null || host.isEmpty) {
      throw StateError('$name must be an HTTPS URL for a production build');
    }
    if (host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host.endsWith('.invalid')) {
      throw StateError(
        '$name must not target a loopback or placeholder host in production',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw StateError('$name must not embed credentials');
    }
    return resolved;
  }
}
