import 'package:fitcalgary_app/core/native_navigation.dart';
import 'package:fitcalgary_app/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scrolling content cannot replace the status-bar backdrop', (
    tester,
  ) async {
    const content = Key('scrolling-content');
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(top: 44)),
          child: AppShell(
            location: '/',
            child: SizedBox.expand(key: content),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(content)).dy, 44);
    expect(tester.takeException(), isNull);
  });
  testWidgets('non-iOS builds preserve usable fallback navigation', (
    tester,
  ) async {
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: NativeFitNavigation(
          selectedIndex: 0,
          onSelected: (index) => selected = index,
          fallback: TextButton(
            onPressed: () => selected = 1,
            child: const Text('Gyms'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(UiKitView), findsNothing);
    await tester.tap(find.text('Gyms'));
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });

  for (final unavailable in [false, true]) {
    testWidgets('iOS capability failure $unavailable retains fallback', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      const capability = MethodChannel('fitcalgary/material');
      var capabilityChecks = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        capability,
        (call) async {
          capabilityChecks++;
          if (unavailable) throw PlatformException(code: 'UNAVAILABLE');
          return false;
        },
      );
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          capability,
          null,
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: NativeFitNavigation(
            selectedIndex: 0,
            onSelected: (_) {},
            fallback: const Text('FitCalgary navigation'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        capabilityChecks,
        const bool.fromEnvironment('NATIVE_IOS_NAVIGATION', defaultValue: true)
            ? 1
            : 0,
      );
      expect(find.text('FitCalgary navigation'), findsOneWidget);
      expect(find.byType(UiKitView), findsNothing);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
