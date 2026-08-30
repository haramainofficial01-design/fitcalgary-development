import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitcalgary_app/app/app.dart';
import 'package:fitcalgary_app/features/profile/profile_screen.dart';

void main() {
  testWidgets('launches the FitCalgary home experience', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitCalgaryApp()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('The city,\nranked.'), findsOneWidget);
    expect(find.text('POST A RESULT →'), findsOneWidget);
  });

  testWidgets('primary product navigation opens every Client shell area', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: FitCalgaryApp()));
    await tester.pump();

    await tester.tap(find.text('Gyms'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Every major gym\nin Calgary.'), findsOneWidget);

    await tester.tap(find.text('Board'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('The city,\nranked.'), findsOneWidget);

    await tester.tap(find.text('Compete'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('You can enter\nthese.'), findsOneWidget);

    await tester.tap(find.text('Me'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ProfileScreen), findsOneWidget);
  });
}
