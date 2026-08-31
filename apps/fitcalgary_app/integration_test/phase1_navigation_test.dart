import 'package:fitcalgary_app/core/onboarding_store.dart';
import 'package:fitcalgary_app/features/profile/profile_screen.dart';
import 'package:fitcalgary_app/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch reaches every primary product area', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(SharedPreferencesOnboardingStore.key);

    app.main();
    await tester.pumpAndSettle();
    expect(find.text('The city,\nranked.'), findsOneWidget);

    await tester.tap(find.text('NEXT →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EXPLORE FITCALGARY'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('POST A RESULT →'), findsOneWidget);

    await tester.tap(find.text('Gyms'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Every major gym\nin Calgary.'), findsOneWidget);

    await tester.tap(find.text('Board'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('The city,\nranked.'), findsOneWidget);

    await tester.tap(find.text('Compete'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('You can enter\nthese.'), findsOneWidget);

    await tester.tap(find.text('Me'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ProfileScreen), findsOneWidget);

    expect(preferences.getBool(SharedPreferencesOnboardingStore.key), isTrue);
  });
}
