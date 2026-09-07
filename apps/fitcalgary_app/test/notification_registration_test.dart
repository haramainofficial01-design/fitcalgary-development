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
