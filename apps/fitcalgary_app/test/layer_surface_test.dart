import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcalgary_app/core/layer_surface.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    TargetPlatform platform, {
    bool contrast = false,
    bool reduced = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: MediaQuery(
          data: MediaQueryData(
            highContrast: contrast,
            disableAnimations: reduced,
          ),
          child: const FitLayerSurface(
            floating: true,
            child: Text('FitCalgary'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'floating material adapts without applying Apple blur to Android',
    (tester) async {
      await show(tester, TargetPlatform.iOS);
      expect(find.byType(BackdropFilter), findsOneWidget);
      await show(tester, TargetPlatform.android);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('FitCalgary'), findsOneWidget);
    },
  );
  testWidgets('contrast and reduced motion use an opaque material fallback', (
    tester,
  ) async {
    await show(tester, TargetPlatform.iOS, contrast: true);
    expect(find.byType(BackdropFilter), findsNothing);
    await show(tester, TargetPlatform.iOS, reduced: true);
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
