import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcalgary_app/core/api_client.dart';
import 'package:fitcalgary_app/core/auth_service.dart';

class _FailingRefreshAuth extends AuthService {
  int refreshCalls = 0;

  @override
  Future<AuthTokens?> current() async => const AuthTokens(accessToken: 'old');

  @override
  Future<AuthTokens?> refresh() async {
    refreshCalls++;
    throw StateError('Identity provider is unreachable');
  }
}

class _UnauthorizedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('Unauthorized', 401);

  @override
  void close({bool force = false}) {}
}

class _UnavailableIdentityAuth extends AuthService {
  @override
  Future<AuthTokens?> current() async => throw StateError('Identity offline');

  @override
  Future<AuthTokens?> refresh() async => throw StateError('Identity offline');
}

class _PublicAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.headers.containsKey('Authorization')) {
      return ResponseBody.fromString('Unexpected authorization', 400);
    }
    return ResponseBody.fromString(
      '{"data":[]}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('a failed token refresh settles the original 401 request', () async {
    final auth = _FailingRefreshAuth();
    final client = ApiClient(auth);
    client.dio.httpClientAdapter = _UnauthorizedAdapter();

    await expectLater(
      client.dio.get('/profile').timeout(const Duration(seconds: 2)),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'status code',
          401,
        ),
      ),
    );
    expect(auth.refreshCalls, 1);
  });

  test('public directory loads when the identity provider is unavailable', () async {
    final client = ApiClient(_UnavailableIdentityAuth());
    client.dio.httpClientAdapter = _PublicAdapter();

    expect(await client.list('/gyms'), isEmpty);
  });
}
