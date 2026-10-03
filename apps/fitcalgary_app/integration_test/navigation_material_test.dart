import 'dart:io';

import 'package:fitcalgary_app/core/onboarding_store.dart';
import 'package:fitcalgary_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('navigation material keeps real app routes accessible', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(SharedPreferencesOnboardingStore.key, true);
    app.main();
    await tester.pumpAndSettle();
    expect(find.byType(UiKitView), findsNothing);
    for (final tab in ['Gyms', 'Board', 'Compete', 'Me', 'Home']) {
      await tester.tap(find.text(tab));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: '$tab navigation');
    }
    await tester.pumpAndSettle();
    if (Platform.isIOS) {
      final bytes = await binding.takeScreenshot('navigation-home');
      final directory = await Directory.systemTemp.createTemp(
        'fitcalgary-visual-',
      );
      final capture = File('${directory.path}/navigation-home.png');
      await capture.writeAsBytes(bytes);
      const output = String.fromEnvironment('VISUAL_CAPTURE_OUTPUT');
      if (output.isNotEmpty) await File(output).writeAsBytes(bytes);
      // Temporary app capture path only; no account/session information.
      debugPrint('FitCalgary visual capture: ${capture.path}');
    }
  });
}
