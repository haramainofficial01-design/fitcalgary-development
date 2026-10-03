import 'package:fitcalgary_app/app/app.dart';
import 'package:dio/dio.dart';
import 'package:fitcalgary_app/core/api_client.dart';
import 'package:fitcalgary_app/app/providers.dart';
import 'package:fitcalgary_app/core/auth_service.dart';
import 'package:fitcalgary_app/core/onboarding_store.dart';
import 'package:fitcalgary_app/domain/models.dart';
import 'package:fitcalgary_app/features/gyms/gym_providers.dart';
import 'package:fitcalgary_app/features/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedInAuth extends AuthService {
  @override
  Future<AuthTokens?> current() async => const AuthTokens(accessToken: 'test');
}

class _RecoveringAuth extends AuthService {
  int requests = 0;
  @override
  Future<AuthTokens?> current() async {
    if (++requests == 1) throw StateError('Private provider detail');
    return null;
  }
}

void main() {
  test(
    'home board count uses published boards, not configured disciplines',
    () async {
      final api = ApiClient(_SignedInAuth());
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, isNot('/disciplines'));
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: options.path == '/leaderboards'
                    ? {
                        'data': [
                          {'id': 'published-board'},
                        ],
                      }
                    : {
                        'total': options.path == '/gyms' ? 273 : 531,
                        'data': [],
                      },
              ),
            );
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [apiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      addTearDown(api.dio.close);
      final snapshot = await container.read(catalogSnapshotProvider.future);
      expect(snapshot.boards, 1);
      expect(snapshot.gyms, 273);
      expect(snapshot.events, 531);
    },
  );
  testWidgets(
    'profile identity outage shows retry instead of a false signed-out state',
    (tester) async {
      final auth = _RecoveringAuth();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(auth)],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Your account could not be reached. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Private provider detail'), findsNothing);
      expect(find.text('Your fitness\nidentity.'), findsNothing);
      expect(auth.requests, 1);
      await tester.tap(find.text('TRY AGAIN'));
      await tester.pumpAndSettle();
      expect(find.text('Your fitness\nidentity.'), findsOneWidget);
      expect(auth.requests, 2);
      expect(tester.takeException(), isNull);
    },
  );
  test('profile parses ranking eligibility fields and privacy controls', () {
    final profile = AthleteProfile.fromJson({
      'id': 'athlete',
      'display_name': 'Development Athlete',
      'home_gym_id': 'gym-1',
      'home_gym_name': 'Development Gym',
      'date_of_birth': '1992-08-31',
      'sex_category': 'WOMEN',
      'privacy': {'publicProfile': false, 'showGym': false},
    });
    expect(profile.homeGymId, 'gym-1');
    expect(profile.dateOfBirth, DateTime(1992, 8, 31));
    expect(profile.sexCategory, 'WOMEN');
    expect(profile.publicProfile, isFalse);
    expect(profile.showGym, isFalse);
  });

  testWidgets(
    'signed-in profile distinguishes verified and community results',
    (tester) async {
      const official = AthleteResult(
        id: 'official',
        discipline: '5K Run',
        displayMetric: '19:45',
        boardType: 'OFFICIAL',
        division: 'Open',
        rank: 1,
      );
      const community = AthleteResult(
        id: 'community',
        discipline: 'Push-Ups',
        displayMetric: '42 reps',
        boardType: 'COMMUNITY',
        division: 'Open',
        rank: 3,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_SignedInAuth()),
            profileProvider.overrideWith(
              (ref) async => const AthleteProfile(
                id: 'athlete',
                displayName: 'Development Athlete',
                gymName: 'Development Gym',
                homeGymId: 'gym-1',
                city: 'Calgary',
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
                  id: 'gym-1',
                  name: 'Development Gym',
                  operatorName: 'Development',
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
      await tester.pump();
      expect(find.text('VERIFIED'), findsWidgets);
      expect(find.text('COMMUNITY'), findsWidgets);
      expect(find.text('19:45'), findsWidgets);
      expect(find.textContaining('Rank 1'), findsWidgets);

      await tester.drag(find.byType(ListView).first, const Offset(0, 520));
      await tester.pump();
      await tester.tap(find.text('EDIT PROFILE'));
      await tester.pumpAndSettle();
      expect(find.text('BOARD CATEGORY'), findsOneWidget);
      expect(find.text('HOME GYM'), findsOneWidget);
      expect(find.text('Public athlete profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
