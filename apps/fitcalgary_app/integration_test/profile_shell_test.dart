import 'package:fitcalgary_app/app/app.dart';
import 'package:fitcalgary_app/app/providers.dart';
import 'package:fitcalgary_app/core/auth_service.dart';
import 'package:fitcalgary_app/core/onboarding_store.dart';
import 'package:fitcalgary_app/domain/models.dart';
import 'package:fitcalgary_app/features/gyms/gym_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class DevelopmentProfileIdentity extends AuthService {
  @override
  Future<AuthTokens?> current() async =>
      const AuthTokens(accessToken: 'runtime-only-profile-shell');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'athlete profile shell presents private settings and board status',
    (tester) async {
      const official = AthleteResult(
        id: 'official-result',
        discipline: '5K Run',
        displayMetric: '19:45',
        boardType: 'OFFICIAL',
        division: 'Open',
        rank: 1,
      );
      const community = AthleteResult(
        id: 'community-result',
        discipline: 'Push-Ups',
        displayMetric: '42 reps',
        boardType: 'COMMUNITY',
        division: 'Open',
        rank: 3,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(DevelopmentProfileIdentity()),
            profileProvider.overrideWith(
              (ref) async => const AthleteProfile(
                id: 'development-athlete',
                displayName: 'Development Athlete',
                bio: 'Development-only profile presentation.',
                city: 'Calgary',
                gymName: 'Development Gym',
                homeGymId: 'development-gym',
                sexCategory: 'WOMEN',
              ),
            ),
            performanceProvider.overrideWith(
              (ref) async => const AthletePerformance(
                results: [official, community],
                personalBests: [official, community],
              ),
            ),
            submissionsProvider.overrideWith(
              (ref) async => const <SubmissionRecord>[],
            ),
            gymsProvider.overrideWith(
              (ref) async => const [
                Gym(
                  id: 'development-gym',
                  name: 'Development Gym',
                  operatorName: 'Development fixture',
                  city: 'Calgary',
                ),
              ],
            ),
            eventsProvider.overrideWith((ref) async => const <EventListing>[]),
            disciplinesProvider.overrideWith(
              (ref) async => const <Discipline>[],
            ),
            savedGymsProvider.overrideWith((ref) async => const <Gym>[]),
          ],
          child: FitCalgaryApp(
            onboardingStore: MemoryOnboardingStore(complete: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Me'));
      await tester.pumpAndSettle();
      expect(find.text('Development Athlete'), findsOneWidget);
      expect(find.text('Calgary · Women’s division'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -520));
      await tester.pumpAndSettle();
      expect(find.text('VERIFIED'), findsWidgets);
      expect(find.text('COMMUNITY'), findsWidgets);
      expect(find.textContaining('Rank 1'), findsWidgets);
      if (defaultTargetPlatform != TargetPlatform.android) {
        await binding.takeScreenshot('day4-athlete-performance');
      }
      await tester.drag(find.byType(ListView).first, const Offset(0, 520));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EDIT PROFILE'));
      await tester.pumpAndSettle();
      expect(find.text('BOARD CATEGORY'), findsOneWidget);
      expect(find.text('HOME GYM'), findsOneWidget);
      expect(find.text('Public athlete profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
