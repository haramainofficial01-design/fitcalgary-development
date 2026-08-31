import 'package:fitcalgary_app/core/onboarding_store.dart';
import 'package:fitcalgary_app/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Phase 1 visual route demonstration', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(SharedPreferencesOnboardingStore.key);

    app.main();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.text('NEXT →'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('NEXT →'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('EXPLORE FITCALGARY'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    for (final destination in ['Gyms', 'Board', 'Compete', 'Me', 'Home']) {
      await tester.tap(find.text(destination));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
    }
  });
}
