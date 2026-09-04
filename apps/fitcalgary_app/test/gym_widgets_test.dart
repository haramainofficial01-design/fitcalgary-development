import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcalgary_app/domain/models.dart';
import 'package:fitcalgary_app/features/gyms/gym_providers.dart';
import 'package:fitcalgary_app/features/gyms/gym_widgets.dart';
import 'package:fitcalgary_app/features/gyms/gyms_screen.dart';

void main() {
  test(
    'gym parses service identity and missing prices without inventing values',
    () {
      final gym = Gym.fromJson({
        'id': 'test',
        'slug': 'development-test',
        'name': 'Development Fixture',
        'neighbourhood': 'Test area',
        'address_line1': 'Test address',
      });
      expect(gym.slug, 'development-test');
      expect(gym.area, 'Test area');
      expect(gym.address, 'Test address');
      expect(gym.lowestOngoingMonthlyCents, isNull);
      expect(money(null), 'Not supplied');
      expect(money(3350), '\$33.50');
    },
  );
  testWidgets('unknown membership never presents a free all-in estimate', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PricingPlans(
            plans: [
              {
                'plan_name': 'Development incomplete',
                'pricing_complete': false,
                'recurring_cents': 0,
              },
            ],
          ),
        ),
      ),
    );
    expect(
      find.text('Pricing incomplete — no all-in estimate'),
      findsOneWidget,
    );
    expect(find.text('\$0.00 / month all-in'), findsNothing);
  });
  testWidgets('directory error can retry into a truthful empty state', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          directoryProvider.overrideWith((ref, query) async {
            attempts++;
            if (attempts == 1) throw Exception('test offline');
            return const GymPage([], 0);
          }),
          savedGymsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: GymsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('The gym index could not be reached. Try again.'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('The gym index could not be reached. Try again.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('TRY AGAIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TRY AGAIN'));
    await tester.pumpAndSettle();
    expect(find.text('No gyms found'), findsOneWidget);
  });
}
