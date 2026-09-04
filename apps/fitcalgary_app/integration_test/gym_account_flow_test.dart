import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fitcalgary_app/app/app.dart';
import 'package:fitcalgary_app/app/providers.dart';
import 'package:fitcalgary_app/core/auth_service.dart';
import 'package:fitcalgary_app/core/onboarding_store.dart';

// Test-only identity adapter. All directory/profile/favourite calls still use
// the real Go service and PostgreSQL. This is not production OIDC verification.
class DevelopmentIdentity extends AuthService {
  DevelopmentIdentity(this.token);
  final String token;
  @override
  Future<AuthTokens?> current() async => AuthTokens(accessToken: token);
  @override
  Future<AuthTokens?> refresh() async => null;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'directory pricing comparison profile and favourites persist through Go',
    (tester) async {
      const token = String.fromEnvironment('TEST_USER_TOKEN');
      expect(
        token.isNotEmpty,
        isTrue,
        reason: 'Supply an ephemeral local test identity',
      );
      Widget application() => ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(DevelopmentIdentity(token)),
        ],
        child: FitCalgaryApp(
          onboardingStore: MemoryOnboardingStore(complete: true),
        ),
      );
      Future<void> settle() async {
        await tester.pumpAndSettle(
          const Duration(milliseconds: 200),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
      }

      Future<void> reveal(Finder finder) async {
        await tester.scrollUntilVisible(
          finder,
          180,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 25,
        );
        await settle();
      }

      await tester.pumpWidget(application());
      await settle();
      await tester.tap(find.text('Gyms'));
      await settle();
      final monthly = find.text('Development Fixture — Monthly Gym');
      await reveal(monthly);
      await tester.tap(monthly);
      await settle();
      expect(find.text('Gym details'), findsOneWidget);
      await reveal(find.text('\$25.00 / month all-in'));
      expect(find.text('\$25.00 / month in year one'), findsOneWidget);
      await reveal(find.byKey(const ValueKey('save-development-monthly-gym')));
      if (find.byTooltip('Remove saved gym').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('Remove saved gym'));
        await settle();
      }
      await tester.tap(find.byTooltip('Save gym privately'));
      await settle();
      expect(find.byTooltip('Remove saved gym'), findsOneWidget);
      // Android captures use the external emulator tooling: in-process surface
      // conversion stalls input on this emulator. It is not application logic.
      if (defaultTargetPlatform != TargetPlatform.android) {
        await binding.takeScreenshot('day3-gym-detail-saved');
      }

      // Dispose every client provider and rebuild: the saved state must come
      // back from the service, not from a card-local boolean.
      await tester.pumpWidget(const SizedBox.shrink());
      await settle();
      await tester.pumpWidget(application());
      await settle();
      await tester.tap(find.text('Gyms'));
      await settle();
      await reveal(find.text('SAVED GYMS'));
      await tester.tap(find.text('SAVED GYMS'));
      await settle();
      expect(monthly, findsOneWidget);
      expect(find.byTooltip('Remove saved gym'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove saved gym'));
      await settle();
      expect(find.text('No saved gyms'), findsOneWidget);
      await tester.pageBack();
      await settle();

      await reveal(monthly);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('gym-development-monthly-gym')),
          matching: find.byType(FilterChip),
        ),
      );
      await settle();
      final biweekly = find.text('Development Fixture — Biweekly Gym');
      await reveal(biweekly);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('gym-development-biweekly-gym')),
          matching: find.byType(FilterChip),
        ),
      );
      await settle();
      await reveal(find.text('COMPARE (2/3)'));
      await tester.tap(find.text('COMPARE (2/3)'));
      await settle();
      expect(find.text('Compare memberships'), findsOneWidget);
      await reveal(find.text('\$31.00 / month all-in'));
      expect(find.text('\$33.50 / month in year one'), findsOneWidget);
      if (defaultTargetPlatform != TargetPlatform.android) {
        await binding.takeScreenshot('day3-comparison');
      }
      await tester.pageBack();
      await settle();
      await tester.tap(find.text('Me'));
      await settle();
      await reveal(find.text('EDIT PROFILE'));
      await tester.tap(find.text('EDIT PROFILE'));
      await settle();
      final updatedName =
          'Development Athlete ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(find.byType(TextField).first, updatedName);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle();
      await tester.ensureVisible(find.text('SAVE CHANGES'));
      await settle();
      await tester.tap(find.text('SAVE CHANGES'));
      await settle();
      expect(find.text('SAVE CHANGES'), findsNothing);
      expect(find.text(updatedName), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await settle();
      await tester.pumpWidget(application());
      await settle();
      await tester.tap(find.text('Me'));
      await settle();
      expect(find.text(updatedName), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
