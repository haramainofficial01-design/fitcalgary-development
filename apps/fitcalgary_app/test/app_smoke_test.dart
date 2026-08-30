import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitcalgary_app/app/app.dart';

void main() {
  testWidgets('launches the FitCalgary home experience', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitCalgaryApp()));
    await tester.pumpAndSettle();
    expect(find.text('The city,\nranked.'), findsOneWidget);
    expect(find.text('POST A RESULT →'), findsOneWidget);
  });
}
