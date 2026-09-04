import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitcalgary_app/app/app.dart';
import 'package:fitcalgary_app/app/providers.dart';
import 'package:fitcalgary_app/core/onboarding_store.dart';
import 'package:fitcalgary_app/domain/models.dart';
import 'package:fitcalgary_app/features/profile/profile_screen.dart';
import 'package:fitcalgary_app/features/gyms/gym_providers.dart';

void main() {
  ProviderScope testApp(OnboardingStore store) => ProviderScope(
    overrides: [
      directoryProvider.overrideWith(
        (ref, query) async => const GymPage([], 0),
      ),
      savedGymsProvider.overrideWith((ref) async => []),
      gymsProvider.overrideWith((ref) async => const <Gym>[]),
      eventsProvider.overrideWith((ref) async => const <EventListing>[]),
      disciplinesProvider.overrideWith((ref) async => const <Discipline>[]),
      submissionsProvider.overrideWith(
        (ref) async => const <SubmissionRecord>[],
      ),
      profileProvider.overrideWith(
        (ref) async =>
            const AthleteProfile(id: 'test-user', displayName: 'Test Athlete'),
      ),
    ],
    child: FitCalgaryApp(onboardingStore: store),
  );

  testWidgets('launches the FitCalgary home experience', (tester) async {
    await tester.pumpWidget(testApp(MemoryOnboardingStore(complete: true)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('The city,\nranked.'), findsOneWidget);
    expect(find.text('POST A RESULT →'), findsOneWidget);
  });

  testWidgets('primary product navigation opens every Client shell area', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(MemoryOnboardingStore(complete: true)));
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

  testWidgets('new user completes onboarding and is not shown it again', (
    tester,
  ) async {
    final store = MemoryOnboardingStore();
    await tester.pumpWidget(testApp(store));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('The city,\nranked.'), findsOneWidget);
    await tester.tap(find.text('NEXT →'));
    await tester.pumpAndSettle();
    expect(find.text('Know what\nyou pay.'), findsOneWidget);
    await tester.tap(find.text('NEXT →'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to\nmake a mark?'), findsOneWidget);
    await tester.tap(find.text('EXPLORE FITCALGARY'));
    await tester.pumpAndSettle();

    expect(store.completed, isTrue);
    expect(find.text('POST A RESULT →'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      KeyedSubtree(key: UniqueKey(), child: testApp(store)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('POST A RESULT →'), findsOneWidget);
    expect(find.text('EXPLORE FITCALGARY'), findsNothing);
  });

  testWidgets('account onboarding path opens sign in and returns safely', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(MemoryOnboardingStore()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE ACCOUNT OR SIGN IN →'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in.'), findsOneWidget);
    expect(find.text('← BACK TO INTRODUCTION'), findsOneWidget);
    await tester.tap(find.text('← BACK TO INTRODUCTION'));
    await tester.pumpAndSettle();
    expect(find.text('The city,\nranked.'), findsOneWidget);
  });
}
