import 'package:fitcalgary_app/core/onboarding_store.dart';
import 'package:fitcalgary_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Read-only catalog interactions. No accounts, submissions or content are created.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('published directory supports details, empty search and clubs', (
    tester,
  ) async {
    Future<void> load() async {
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(tester.takeException(), isNull);
    }

    Finder row(String prefix) => find.byWidgetPredicate(
      (widget) =>
          (widget is Container || widget is InkWell) &&
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith(prefix),
    );
    Future<void> reveal(Finder finder) async {
      for (var i = 0; i < 16; i++) {
        if (finder.evaluate().isNotEmpty) {
          await tester.ensureVisible(finder.first);
          await tester.pump();
          return;
        }
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
        await tester.pump(const Duration(milliseconds: 100));
      }
      fail('Expected catalog item was not rendered after scrolling');
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(SharedPreferencesOnboardingStore.key, true);
    app.main();
    await load();
    await tester.tap(find.text('Gyms'));
    await load();
    await reveal(row('gym-'));
    final gymLink = find
        .descendant(of: row('gym-').first, matching: find.byType(TextButton))
        .first;
    await tester.tap(gymLink);
    await load();
    expect(find.text('Gym details'), findsOneWidget);
    expect(find.byTooltip('Save gym privately'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await load();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('gym-search')),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byType(TextField).first,
      'fitcalgary-no-match-qa-847291',
    );
    await load();
    await reveal(find.text('No gyms found'));
    expect(find.text('No gyms found'), findsOneWidget);

    await tester.tap(find.text('Compete'));
    await load();
    await tester.tap(find.text('CLUBS'));
    await load();
    await reveal(row('club-'));
    expect(row('club-'), findsWidgets);
    await tester.tap(row('club-').first);
    await load();
    expect(find.text('CLUB DETAILS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Compete'));
    await load();
    expect(find.text('Calgary\ncompetitions.'), findsOneWidget);
  });
}
