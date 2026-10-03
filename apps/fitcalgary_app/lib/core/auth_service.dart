import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'build_config.dart';
import 'watch_bridge.dart';

enum AuthIdentityProvider {
  google('google'),
  apple('apple');

  const AuthIdentityProvider(this.alias);
  final String alias;
}

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
  static String get issuer => BuildConfig.oidcIssuer;
  static String get clientId => BuildConfig.oidcClientId;
  static const redirectUrl = 'ca.fitcalgary.index:/oauthredirect';
  final FlutterAppAuth _appAuth;
  final FlutterSecureStorage _storage;
  AuthTokens? _memory;
  int _sessionRevision = 0;
  bool _signingOut = false;
  Future<AuthTokens?>? _refreshing;
  Future<void> _storageQueue = Future.value();
  Future<AuthTokens?> current() {
    if (_signingOut) return Future.value(null);
    final memory = _memory;
    if (memory != null && !memory.expired) return Future.value(memory);
    return _restoreAndRefresh();
  }

  Future<AuthTokens> signIn({AuthIdentityProvider? provider}) async {
    if (_signingOut) throw StateError('Sign-out is still in progress');
    final revision = ++_sessionRevision;
    _refreshing = null;
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId,
        redirectUrl,
        issuer: issuer,
        scopes: ['openid', 'profile', 'email', 'offline_access'],
        promptValues: ['login'],
        additionalParameters: provider == null
            ? const {}
            : {'kc_idp_hint': provider.alias},
        allowInsecureConnections: BuildConfig.allowInsecureOidc,
      ),
    );
    if (result.accessToken == null || result.accessToken!.trim().isEmpty) {
      throw StateError('Identity provider returned no access token');
    }
    final tokens = AuthTokens(
      accessToken: result.accessToken!,
      refreshToken: result.refreshToken,
      idToken: result.idToken,
      expiresAt: result.accessTokenExpirationDateTime,
    );
    await _save(tokens, revision);
    if (revision != _sessionRevision) throw StateError('Sign-in interrupted');
    return tokens;
  }

  Future<AuthTokens> signInWithGoogle() =>
      signIn(provider: AuthIdentityProvider.google);

  Future<AuthTokens> signInWithApple() =>
      signIn(provider: AuthIdentityProvider.apple);

  Future<AuthTokens?> refresh() {
    if (_signingOut) return Future.value(null);
    final pending = _refreshing;
    if (pending != null) return pending;
    late final Future<AuthTokens?> attempt;
    attempt = _performRefresh().whenComplete(() {
      if (identical(_refreshing, attempt)) _refreshing = null;
    });
    _refreshing = attempt;
    return attempt;
  }

  Future<AuthTokens?> _performRefresh() async {
    final revision = _sessionRevision;
    final refreshToken =
        _memory?.refreshToken ?? await _storage.read(key: 'refresh_token');
    if (refreshToken == null ||
        refreshToken.isEmpty ||
        revision != _sessionRevision) {
      return null;
    }
    final previousIdToken =
        _memory?.idToken ?? await _storage.read(key: 'id_token');
    if (revision != _sessionRevision) return null;
    late final TokenResponse result;
    try {
      result = await _appAuth.token(
        TokenRequest(
          clientId,
          redirectUrl,
          issuer: issuer,
          refreshToken: refreshToken,
          scopes: ['openid', 'profile', 'email', 'offline_access'],
          allowInsecureConnections: BuildConfig.allowInsecureOidc,
        ),
      );
    } on FlutterAppAuthPlatformException catch (error) {
      if (revision != _sessionRevision) return null;
      if (error.platformErrorDetails.error != 'invalid_grant') rethrow;
      ++_sessionRevision;
      _memory = null;
      final clear = _storageQueue.then((_) => _storage.deleteAll());
      _storageQueue = clear.catchError((Object _) {});
      await clear;
      await WatchBridge.logout();
      return null;
    }
    if (revision != _sessionRevision) return null;
    if (result.accessToken == null || result.accessToken!.trim().isEmpty) {
      await signOut();
      return null;
    }
    final tokens = AuthTokens(
      accessToken: result.accessToken!,
      refreshToken: result.refreshToken ?? refreshToken,
      idToken: result.idToken ?? previousIdToken,
      expiresAt: result.accessTokenExpirationDateTime,
    );
    await _save(tokens, revision);
    return revision == _sessionRevision ? tokens : null;
  }

  Future<void> signOut() async {
    if (_signingOut) return;
    _signingOut = true;
    ++_sessionRevision;
    _refreshing = null;
    var id = _memory?.idToken;
    _memory = null;
    try {
      try {
        id ??= await _storage.read(key: 'id_token');
      } catch (_) {
        // Local deletion must still be attempted if a logout hint is unreadable.
      }
      // Clear local credentials before waiting for a provider/browser response.
      final clear = _storageQueue.then((_) => _storage.deleteAll());
      _storageQueue = clear.catchError((Object _) {});
      await clear;
      await WatchBridge.logout();
      if (id != null) {
        try {
          await _appAuth.endSession(
            EndSessionRequest(
              idTokenHint: id,
              postLogoutRedirectUrl: redirectUrl,
              issuer: issuer,
              allowInsecureConnections: BuildConfig.allowInsecureOidc,
            ),
          );
        } on PlatformException {
          // Browser/provider cancellation cannot undo completed local sign-out.
        }
      }
    } finally {
      _signingOut = false;
    }
  }

  Future<AuthTokens?> _restoreAndRefresh() async {
    final revision = _sessionRevision;
    final access = await _storage.read(key: 'access_token');
    if (access == null || access.trim().isEmpty) return null;
    final expiresRaw = await _storage.read(key: 'expires_at');
    final tokens = AuthTokens(
      accessToken: access,
      refreshToken: await _storage.read(key: 'refresh_token'),
      idToken: await _storage.read(key: 'id_token'),
      expiresAt: expiresRaw == null ? null : DateTime.tryParse(expiresRaw),
    );
    if (_signingOut || revision != _sessionRevision) return null;
    _memory = tokens;
    return tokens.expired ? refresh() : tokens;
  }

  Future<void> _save(AuthTokens tokens, int revision) async {
    final save = _storageQueue.then((_) async {
      if (_signingOut || revision != _sessionRevision) return;
      await Future.wait([
        _storage.write(key: 'access_token', value: tokens.accessToken),
        _storage.write(key: 'refresh_token', value: tokens.refreshToken),
        _storage.write(key: 'id_token', value: tokens.idToken),
        _storage.write(
          key: 'expires_at',
          value: tokens.expiresAt?.toIso8601String(),
        ),
      ]);
      if (_signingOut || revision != _sessionRevision) return;
      _memory = tokens;
      await WatchBridge.sync(tokens.accessToken);
    });
    _storageQueue = save.catchError((Object _) {});
    await save;
  }
}
