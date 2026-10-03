import 'package:dio/dio.dart';
import 'package:fitcalgary_app/app/providers.dart';
import 'package:fitcalgary_app/core/api_client.dart';
import 'package:fitcalgary_app/core/auth_service.dart';
import 'package:fitcalgary_app/features/profile/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestAuth extends AuthService {
  @override
  Future<AuthTokens?> current() async => null;
}

void main() {
  testWidgets('empty inbox can pull refresh, report an outage, and recover', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith((ref) async {
            if (++requests == 2) throw StateError('Private service detail');
            return [];
          }),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(
      find.text('The operation could not finish. Please retry.'),
      findsOneWidget,
    );
    expect(find.text('Private service detail'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(requests, 3);
    expect(find.text('You’re all caught up'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification choices persist through the profile API', (
    tester,
  ) async {
    final api = ApiClient(_TestAuth());
    Map<String, dynamic>? saved;
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/profile');
          expect(options.method, 'PATCH');
          saved = options.data as Map<String, dynamic>;
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: {}),
          );
        },
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          notificationsProvider.overrideWith((ref) async => []),
          notificationPreferencesProvider.overrideWith(
            (ref) async => {'eventUpdates': true, 'announcements': false},
          ),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('You’re all caught up'), findsOneWidget);
    await tester.tap(find.byTooltip('Notification preferences'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
      true,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile).last).value,
      false,
    );
    await tester.tap(find.text('Event updates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(saved, {
      'notificationPreferences': {'eventUpdates': false},
    });
    expect(find.byType(NotificationPreferencesDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
