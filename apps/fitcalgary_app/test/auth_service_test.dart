import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitcalgary_app/core/auth_service.dart';

class _FakeAppAuth extends FlutterAppAuth {
  _FakeAppAuth({this.accessToken = 'access'});

  final String accessToken;
  AuthorizationTokenRequest? lastRequest;

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
