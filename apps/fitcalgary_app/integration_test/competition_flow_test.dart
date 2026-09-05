import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fitcalgary_app/app/app.dart';
import 'package:fitcalgary_app/app/providers.dart';
import 'package:fitcalgary_app/core/auth_service.dart';
import 'package:fitcalgary_app/core/onboarding_store.dart';

// Ephemeral test identity; API calls and persistence use the actual Go/PostgreSQL runtime.
class _TestIdentity extends AuthService {
  @override
  Future<AuthTokens?> current() async =>
      const AuthTokens(accessToken: String.fromEnvironment('TEST_USER_TOKEN'));
  @override
  Future<AuthTokens?> refresh() async => null;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'community claim is submitted in Flutter and persists on its real board and profile',
    (tester) async {
      const base = String.fromEnvironment('API_BASE_URL');
      const token = String.fromEnvironment('TEST_USER_TOKEN');
      expect(base.isNotEmpty && token.isNotEmpty, isTrue);
      final api = Dio(
        BaseOptions(baseUrl: base, headers: {'Authorization': 'Bearer $token'}),
      );
      await api.patch(
        '/profile',
        data: {
          'displayName': 'Development Competition Athlete',
          'privacy': {'publicProfile': true, 'showGym': false},
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(_TestIdentity())],
          child: FitCalgaryApp(
            onboardingStore: MemoryOnboardingStore(complete: true),
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      Future<void> reveal(Finder finder) async {
        await tester.scrollUntilVisible(
          finder,
          150,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 25,
        );
        await settle();
      }

      await settle();
      await tester.tap(find.text('POST RESULT').first);
      await settle();
      await tester.tap(find.text('Community claim'));
      await settle();
      final disciplineField = find
          .byType(DropdownButtonFormField<String>)
          .first;
      await tester.tap(disciplineField);
      await settle();
      await tester.tap(find.text('Bench Press').last);
      await settle();
      await reveal(find.text('City represented'));
      await tester.tap(find.text('City represented'));
      await settle();
      await tester.tap(find.text('Calgary').last);
      await settle();
      await reveal(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '125.5');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      await reveal(find.text('POST UNVERIFIED CLAIM'));
      await tester.tap(find.text('POST UNVERIFIED CLAIM'));
      await settle();
      expect(find.text('125.5 kg'), findsOneWidget);
      expect(find.text('Unverified claim'), findsOneWidget);
      expect(find.text('Development Competition Athlete'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final performance = (await api.get<Map<String, dynamic>>(
        '/profile/performance',
      )).data!;
      final results = (performance['results'] as List)
          .cast<Map<String, dynamic>>();
      expect(
        results.any(
          (r) =>
              r['display_metric'] == '125.5 kg' &&
              r['verification_type'] == 'UNVERIFIED' &&
              r['board_type'] == 'COMMUNITY',
        ),
        isTrue,
      );
      final permission = await api.get(
        '/judge/queue',
        options: Options(validateStatus: (_) => true),
      );
      expect(permission.statusCode, 403);
      await tester.tap(find.text('Me'));
      await settle();
      await reveal(find.text('PERSONAL BESTS'));
      expect(find.text('125.5 kg'), findsWidgets);
      expect(tester.takeException(), isNull);
      debugPrint(
        'PASS: Flutter form → Go → PostgreSQL → public community board → private profile; normal-user judge access rejected.',
      );
    },
  );
}
