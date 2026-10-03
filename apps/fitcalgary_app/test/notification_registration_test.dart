import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fitcalgary_app/core/api_client.dart';
import 'package:fitcalgary_app/core/auth_service.dart';
import 'package:fitcalgary_app/core/notification_registration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoAuth extends AuthService {
  @override
  Future<AuthTokens?> current() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a device registration finishing after logout cannot restore local state',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = ApiClient(_NoAuth());
      final started = Completer<void>();
      final finish = Completer<void>();
      final requests = <String>[];
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            requests.add('${options.method} ${options.path}');
            if (options.method == 'POST') {
              started.complete();
              await finish.future;
            }
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: options.method == 'DELETE' ? 204 : 200,
                data: options.method == 'DELETE' ? null : {'id': 'late-device'},
              ),
            );
          },
        ),
      );
      final registration = NotificationRegistration(api);
      final pending = registration.registerToken(
        'isolated-provider-test-token',
      );
      await started.future;
      await registration.unregister();
      finish.complete();
      await pending;
      expect(
        (await SharedPreferences.getInstance()).getString(
          'notification_device_id',
        ),
        isNull,
      );
      expect(requests, [
        'POST /notification-devices',
        'DELETE /notification-devices/late-device',
      ]);
      api.dio.close();
    },
  );

  test('an API outage does not block device cleanup during logout', () async {
    SharedPreferences.setMockInitialValues({
      'notification_device_id': 'test-device',
    });
    final api = ApiClient(_NoAuth());
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ),
          );
        },
      ),
    );
    await NotificationRegistration(api).unregister();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('notification_device_id'), isNull);
  });

  test(
    'device token is registered, refreshed and removed on sign-out',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = ApiClient(_NoAuth());
      final requests = <String>[];
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add('${options.method} ${options.path}');
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: options.method == 'DELETE' ? 204 : 200,
                data: options.method == 'DELETE'
                    ? null
                    : {'id': '11111111-1111-4111-8111-111111111111'},
              ),
            );
          },
        ),
      );
      final registration = NotificationRegistration(api);
      await registration.registerToken('a-valid-provider-token-1234567890');
      await registration.registerToken('a-refreshed-provider-token-123456');
      await registration.unregister();
      expect(requests, [
        'POST /notification-devices',
        'PUT /notification-devices/11111111-1111-4111-8111-111111111111',
        'DELETE /notification-devices/11111111-1111-4111-8111-111111111111',
      ]);
    },
  );
}
