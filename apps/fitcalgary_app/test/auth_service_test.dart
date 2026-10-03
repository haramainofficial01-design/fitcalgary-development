import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitcalgary_app/core/auth_service.dart';

class _FakeAppAuth extends FlutterAppAuth {
  _FakeAppAuth({this.accessToken = 'access'});

  final String accessToken;
  AuthorizationTokenRequest? lastRequest;
  Completer<TokenResponse>? pendingRefresh;
  Completer<EndSessionResponse>? pendingLogout;
  int refreshCalls = 0;
  bool logoutUnavailable = false;

  @override
  Future<TokenResponse> token(TokenRequest request) {
    refreshCalls++;
    return pendingRefresh!.future;
  }

  @override
  Future<EndSessionResponse> endSession(EndSessionRequest request) async {
    if (logoutUnavailable) {
      throw PlatformException(code: 'provider_unavailable');
    }
    return pendingLogout == null
        ? EndSessionResponse(null)
        : pendingLogout!.future;
  }

  @override
  Future<AuthorizationTokenResponse> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  ) async {
    lastRequest = request;
    return AuthorizationTokenResponse(
      accessToken,
      'refresh',
      DateTime.now().add(const Duration(hours: 1)),
      'id',
      'Bearer',
      const ['openid'],
      null,
      null,
    );
  }
}

class _MemoryStorage extends FlutterSecureStorage {
  _MemoryStorage();
  final values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
  }) async => values[key];

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
  }) async => values.clear();
}

void main() {
  test(
    'revoked refresh tokens clear local credentials without opening logout',
    () async {
      final storage = _MemoryStorage();
      final appAuth = _FakeAppAuth()
        ..pendingRefresh = Completer<TokenResponse>();
      final service = AuthService(appAuth: appAuth, storage: storage);
      await service.signIn();
      final attempt = service.refresh();
      appAuth.pendingRefresh!.completeError(
        FlutterAppAuthPlatformException(
          code: 'token_error',
          platformErrorDetails: FlutterAppAuthPlatformErrorDetails(
            error: 'invalid_grant',
          ),
        ),
      );
      expect(await attempt, isNull);
      expect(storage.values, isEmpty);
      expect(await service.current(), isNull);
    },
  );

  test('temporary refresh failures preserve credentials for retry', () async {
    final storage = _MemoryStorage();
    final appAuth = _FakeAppAuth()..pendingRefresh = Completer<TokenResponse>();
    final service = AuthService(appAuth: appAuth, storage: storage);
    await service.signIn();
    final attempt = service.refresh();
    appAuth.pendingRefresh!.completeError(
      FlutterAppAuthPlatformException(
        code: 'network_error',
        platformErrorDetails: FlutterAppAuthPlatformErrorDetails(
          error: 'temporarily_unavailable',
        ),
      ),
    );
    await expectLater(attempt, throwsA(isA<FlutterAppAuthPlatformException>()));
    expect(storage.values['refresh_token'], 'refresh');
  });

  test(
    'refresh keeps the ID token when the provider omits a replacement',
    () async {
      final storage = _MemoryStorage();
      final appAuth = _FakeAppAuth()
        ..pendingRefresh = Completer<TokenResponse>();
      final service = AuthService(appAuth: appAuth, storage: storage);
      await service.signIn();
      final attempt = service.refresh();
      appAuth.pendingRefresh!.complete(
        TokenResponse(
          'new-access',
          'new-refresh',
          DateTime.now().add(const Duration(hours: 1)),
          null,
          'Bearer',
          null,
          null,
        ),
      );
      expect((await attempt)?.idToken, 'id');
      expect(storage.values['id_token'], 'id');
    },
  );
  test('provider logout failure still completes local logout', () async {
    final storage = _MemoryStorage();
    final appAuth = _FakeAppAuth()..logoutUnavailable = true;
    final service = AuthService(appAuth: appAuth, storage: storage);
    await service.signIn();
    await service.signOut();
    expect(storage.values, isEmpty);
    expect(await service.current(), isNull);
  });
  test(
    'concurrent refresh requests exchange a rotating token only once',
    () async {
      final appAuth = _FakeAppAuth()
        ..pendingRefresh = Completer<TokenResponse>();
      final service = AuthService(appAuth: appAuth, storage: _MemoryStorage());
      await service.signIn();
      final first = service.refresh();
      final second = service.refresh();
      expect(appAuth.refreshCalls, 1);
      appAuth.pendingRefresh!.complete(
        TokenResponse(
          'new-access',
          'new-refresh',
          DateTime.now().add(const Duration(hours: 1)),
          'id',
          'Bearer',
          null,
          null,
        ),
      );
      expect((await first)?.accessToken, 'new-access');
      expect((await second)?.refreshToken, 'new-refresh');
    },
  );

  test('logout clears credentials before the provider returns and rejects late refresh', () async {
    final appAuth = _FakeAppAuth()
      ..pendingRefresh = Completer<TokenResponse>()
      ..pendingLogout = Completer<EndSessionResponse>();
    final storage = _MemoryStorage();
    final service = AuthService(appAuth: appAuth, storage: storage);
    await service.signIn();
    final refreshing = service.refresh();
    final logout = service.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(storage.values, isEmpty);
    expect(await service.current(), isNull);
    appAuth.pendingRefresh!.complete(
      TokenResponse(
        'late-access',
        'late-refresh',
        DateTime.now().add(const Duration(hours: 1)),
        'id',
        'Bearer',
        null,
        null,
      ),
    );
    expect(await refreshing, isNull);
    expect(storage.values, isEmpty);
    appAuth.pendingLogout!.complete(EndSessionResponse(null));
    await logout;
    expect(await service.current(), isNull);
  });

  test('blank provider access tokens are rejected', () async {
    final storage = _MemoryStorage();
    final service = AuthService(
      appAuth: _FakeAppAuth(accessToken: '  '),
      storage: storage,
    );
    await expectLater(service.signIn(), throwsStateError);
    expect(storage.values, isEmpty);
  });
  test('email sign-in does not force a social provider', () async {
    final appAuth = _FakeAppAuth();
    final service = AuthService(appAuth: appAuth, storage: _MemoryStorage());

    await service.signIn();

    expect(appAuth.lastRequest?.additionalParameters, isEmpty);
    expect(appAuth.lastRequest?.redirectUrl, AuthService.redirectUrl);
  });

  test('Google sign-in sends the Keycloak provider hint', () async {
    final appAuth = _FakeAppAuth();
    final service = AuthService(appAuth: appAuth, storage: _MemoryStorage());

    await service.signInWithGoogle();

    expect(appAuth.lastRequest?.additionalParameters?['kc_idp_hint'], 'google');
  });

  test('Apple sign-in sends the Keycloak provider hint', () async {
    final appAuth = _FakeAppAuth();
    final service = AuthService(appAuth: appAuth, storage: _MemoryStorage());

    await service.signInWithApple();

    expect(appAuth.lastRequest?.additionalParameters?['kc_idp_hint'], 'apple');
  });

  test('an empty provider access token is never stored as a session', () async {
    final storage = _MemoryStorage();
    final service = AuthService(
      appAuth: _FakeAppAuth(accessToken: ''),
      storage: storage,
    );

    await expectLater(service.signIn(), throwsStateError);
    expect(storage.values, isEmpty);
  });
}
