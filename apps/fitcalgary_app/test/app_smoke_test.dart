import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitcalgary_app/app/app.dart';
import 'package:fitcalgary_app/app/providers.dart';
import 'package:fitcalgary_app/core/onboarding_store.dart';
import 'package:fitcalgary_app/core/auth_service.dart';
import 'package:fitcalgary_app/domain/models.dart';
import 'package:fitcalgary_app/features/profile/profile_screen.dart';
import 'package:fitcalgary_app/features/gyms/gym_providers.dart';
import 'package:fitcalgary_app/features/events/content_providers.dart';
import 'package:fitcalgary_app/features/leaderboards/competition_providers.dart';

class _GuestAuth extends AuthService {
  @override
  Future<AuthTokens?> current() async => null;
}

void main() {
  ProviderScope testApp(
    OnboardingStore store, {
    Future<GymPage> Function()? loadDirectory,
  }) => ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(_GuestAuth()),
      catalogSnapshotProvider.overrideWith(
        (ref) async => const CatalogSnapshot(gyms: 273, events: 531, boards: 4),
      ),
      boardsProvider.overrideWith((ref) async => []),
      directoryProvider.overrideWith(
        (ref, query) async => loadDirectory == null
            ? const GymPage([], 0)
            : await loadDirectory(),
      ),
      savedGymsProvider.overrideWith((ref) async => []),
      gymsProvider.overrideWith((ref) async => const <Gym>[]),
      eventsProvider.overrideWith((ref) async => const <EventListing>[]),
      eventDirectoryProvider.overrideWith(
        (ref, query) async => const ContentPage<EventListing>([], 0),
      ),
      clubDirectoryProvider.overrideWith(
        (ref, query) async => const ContentPage<ClubListing>([], 0),
      ),
      clubDetailProvider.overrideWith(
        (ref, slug) async => ClubListing(
          id: 'test-club',
          slug: slug,
          name: 'Test Club',
          sport: 'Running',
        ),
      ),
      disciplinesProvider.overrideWith((ref) async => const <Discipline>[]),
      submissionsProvider.overrideWith(
        (ref) async => const <SubmissionRecord>[],
      ),
      profileProvider.overrideWith(
        (ref) async =>
            const AthleteProfile(id: 'test-user', displayName: 'Test Athlete'),
      ),
      performanceProvider.overrideWith(
        (ref) async => const AthletePerformance(),
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

  testWidgets('selected Compete tab returns from club detail to directory', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(MemoryOnboardingStore(complete: true)));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('Home'))).go('/clubs/test-club');
    await tester.pumpAndSettle();
    expect(find.text('CLUB DETAILS'), findsOneWidget);
    await tester.tap(find.text('Compete'));
    await tester.pumpAndSettle();
    expect(find.text('Calgary\ncompetitions.'), findsOneWidget);
    GoRouter.of(tester.element(find.text('Home'))).go('/clubs/test-club');
    await tester.pumpAndSettle();
    await tester.tap(find.text('BACK TO COMPETE'));
    await tester.pumpAndSettle();
    expect(find.text('Calgary\ncompetitions.'), findsOneWidget);
  });

  testWidgets('failed pull refresh settles and shows a recoverable error', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      testApp(
        MemoryOnboardingStore(complete: true),
        loadDirectory: () async {
          if (++requests == 2) throw StateError('Simulated network failure');
          return const GymPage([], 0);
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gyms'));
    await tester.pumpAndSettle();
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('The gym index could not be reached. Try again.'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('The gym index could not be reached. Try again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('No gyms found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact phone navigation remains usable with large system text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(testApp(MemoryOnboardingStore(complete: true)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('YOUR NEXT BEST'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Home metrics at double text size',
      );
      await tester.tap(find.text('Gyms'));
      await tester.pumpAndSettle();
      expect(find.text('Every major gym\nin Calgary.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final tab in ['Board', 'Compete', 'Me']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$tab at double text size',
        );
      }
    },
  );

  testWidgets('home gym index action opens the actual directory', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(MemoryOnboardingStore(complete: true)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('GYM INDEX →'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('GYM INDEX →'));
    await tester.pumpAndSettle();
    expect(find.text('Every major gym\nin Calgary.'), findsOneWidget);
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
    expect(find.text('Calgary\ncompetitions.'), findsOneWidget);

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
