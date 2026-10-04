import 'package:fitcalgary_app/features/gyms/gym_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'known advertised prices remain visible without an all-in estimate',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PricingPlans(
                plans: [
                  {
                    'plan_name': 'Monthly membership',
                    'pricing_complete': false,
                    'recurring_cents': 6500,
                    'billing_frequency': 'MONTHLY',
                  },
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Advertised: \$65.00 / monthly'), findsOneWidget);
      expect(
        find.text('Pricing incomplete — no all-in estimate'),
        findsOneWidget,
      );
      expect(find.textContaining('/ month all-in'), findsNothing);
      expect(find.text('Annual fee: Not supplied'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
