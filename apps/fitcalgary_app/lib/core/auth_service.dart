import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'watch_bridge.dart';

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    this.expiresAt,
  });
  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime? expiresAt;
  bool get expired =>
      expiresAt != null &&
      DateTime.now().isAfter(expiresAt!.subtract(const Duration(seconds: 30)));
}

class AuthService {
  AuthService({FlutterAppAuth? appAuth, FlutterSecureStorage? storage})
    : _appAuth = appAuth ?? const FlutterAppAuth(),
      _storage =
          storage ?? const FlutterSecureStorage(aOptions: AndroidOptions());
  static const issuer = String.fromEnvironment(
    'OIDC_ISSUER',
    defaultValue: 'http://localhost:8080/realms/fitcalgary',
  );
  static const clientId = String.fromEnvironment(
    'OIDC_CLIENT_ID',
    defaultValue: 'fitcalgary-mobile',
  );
  static const redirectUrl = 'ca.fitcalgary.index:/oauthredirect';
  final FlutterAppAuth _appAuth;
  final FlutterSecureStorage _storage;
  AuthTokens? _memory;
  Future<AuthTokens?> current() {
    final memory = _memory;
    if (memory != null && !memory.expired) return Future.value(memory);
    return _restoreAndRefresh();
  }

  Future<AuthTokens> signIn() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId,
        redirectUrl,
        issuer: issuer,
        scopes: ['openid', 'profile', 'email', 'offline_access'],
        promptValues: ['login'],
        allowInsecureConnections: bool.fromEnvironment('ALLOW_INSECURE_OIDC'),
      ),
    );
    if (result.accessToken == null) {
      throw StateError('Identity provider returned no access token');
    }
    final tokens = AuthTokens(
      accessToken: result.accessToken!,
      refreshToken: result.refreshToken,
      idToken: result.idToken,
      expiresAt: result.accessTokenExpirationDateTime,
    );
    await _save(tokens);
    return tokens;
  }

  Future<AuthTokens?> refresh() async {
    final refreshToken =
        _memory?.refreshToken ?? await _storage.read(key: 'refresh_token');
    if (refreshToken == null) return null;
    final result = await _appAuth.token(
      TokenRequest(
        clientId,
        redirectUrl,
        issuer: issuer,
        refreshToken: refreshToken,
        scopes: ['openid', 'profile', 'email', 'offline_access'],
        allowInsecureConnections: bool.fromEnvironment('ALLOW_INSECURE_OIDC'),
      ),
    );
    if (result.accessToken == null) {
      await signOut();
      return null;
    }
    final tokens = AuthTokens(
      accessToken: result.accessToken!,
      refreshToken: result.refreshToken ?? refreshToken,
      idToken: result.idToken,
      expiresAt: result.accessTokenExpirationDateTime,
    );
    await _save(tokens);
    return tokens;
  }

  Future<void> signOut() async {
    final id = _memory?.idToken ?? await _storage.read(key: 'id_token');
    try {
      if (id != null) {
        await _appAuth.endSession(
          EndSessionRequest(
            idTokenHint: id,
            postLogoutRedirectUrl: redirectUrl,
            issuer: issuer,
            allowInsecureConnections: bool.fromEnvironment(
              'ALLOW_INSECURE_OIDC',
            ),
          ),
        );
      }
    } finally {
      _memory = null;
      await _storage.deleteAll();
      await WatchBridge.logout();
    }
  }

  Future<AuthTokens?> _restoreAndRefresh() async {
    final access = await _storage.read(key: 'access_token');
    if (access == null) return null;
    final expiresRaw = await _storage.read(key: 'expires_at');
    final tokens = AuthTokens(
      accessToken: access,
      refreshToken: await _storage.read(key: 'refresh_token'),
      idToken: await _storage.read(key: 'id_token'),
      expiresAt: expiresRaw == null ? null : DateTime.tryParse(expiresRaw),
    );
    _memory = tokens;
    return tokens.expired ? refresh() : tokens;
  }

  Future<void> _save(AuthTokens tokens) async {
    _memory = tokens;
    await Future.wait([
      _storage.write(key: 'access_token', value: tokens.accessToken),
      _storage.write(key: 'refresh_token', value: tokens.refreshToken),
      _storage.write(key: 'id_token', value: tokens.idToken),
      _storage.write(
        key: 'expires_at',
        value: tokens.expiresAt?.toIso8601String(),
      ),
    ]);
    await WatchBridge.sync(tokens.accessToken);
  }
}
