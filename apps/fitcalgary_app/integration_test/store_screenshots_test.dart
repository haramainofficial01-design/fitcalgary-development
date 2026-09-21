import 'package:fitcalgary_app/core/onboarding_store.dart';
import 'package:fitcalgary_app/main.dart' as app;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture public store listing screens from the running app', (
    tester,
  ) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(SharedPreferencesOnboardingStore.key);

    app.main();
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EXPLORE FITCALGARY'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01-home');

    for (final destination in const [
      ('Gyms', '02-gyms'),
      ('Board', '03-leaderboards'),
      ('Compete', '04-events'),
      ('Me', '05-profile'),
    ]) {
      await tester.tap(find.text(destination.$1));
      await tester.pumpAndSettle();
      await binding.takeScreenshot(destination.$2);
    }
  });
}
