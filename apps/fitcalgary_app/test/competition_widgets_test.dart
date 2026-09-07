import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcalgary_app/app/providers.dart';
import 'package:fitcalgary_app/core/theme.dart';
import 'package:fitcalgary_app/domain/models.dart';
import 'package:fitcalgary_app/features/leaderboards/competition_providers.dart';
import 'package:fitcalgary_app/features/leaderboards/leaderboards_screen.dart';
import 'package:fitcalgary_app/features/submissions/submit_screen.dart';
import 'package:fitcalgary_app/features/submissions/review_screen.dart';

void main() {
  testWidgets(
    'real board projection distinguishes verified and unverified results at phone width',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            boardsProvider.overrideWith(
              (ref) async => [
                {
                  'id': 'official',
                  'board_type': 'OFFICIAL',
                  'discipline_name': 'Push-Ups',
                  'division_label': 'Open',
                  'region_name': 'Calgary',
                  'entry_count': 1,
                },
                {
                  'id': 'community',
                  'board_type': 'COMMUNITY',
                  'discipline_name': 'Push-Ups',
                  'division_label': 'Open',
                  'region_name': 'Calgary',
                  'entry_count': 1,
                },
              ],
            ),
            boardProvider.overrideWith(
              (ref, key) async => {
                'entries': [
                  {
                    'result_id': 'r',
                    'rank': 1,
                    'display_name': 'Development Athlete',
                    'profile_id': 'athlete',
                    'display_metric': '42 reps',
                    'verification_type': key.$1 == 'official'
                        ? 'VIDEO_REVIEWED'
                        : 'UNVERIFIED',
                  },
                ],
              },
            ),
          ],
          child: MaterialApp(
            theme: fitTheme(),
            home: const LeaderboardsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Development Athlete'), findsOneWidget);
      expect(find.text('Verified performance'), findsOneWidget);
      expect(find.text('PREVIEW'), findsNothing);
      await tester.tap(find.text('Community'));
      await tester.pumpAndSettle();
      expect(find.text('Unverified claim'), findsOneWidget);
      expect(find.text('Verified performance'), findsNothing);
    },
  );
  testWidgets('empty published boards show no generated athletes', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [boardsProvider.overrideWith((ref) async => [])],
        child: const MaterialApp(home: LeaderboardsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No published boards yet'), findsOneWidget);
    expect(find.textContaining('Development Athlete'), findsNothing);
  });
  testWidgets(
    'submission form uses configured discipline units and checklist',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            competitionCatalogProvider.overrideWith(
              (ref) async => {
                'disciplines': [
                  {
                    'id': 'd',
                    'display_name': 'Bench Press',
                    'metric_type': 'WEIGHT',
                    'unit': 'kg',
                    'evidence_type': 'VIDEO',
                    'official_eligible': true,
                    'community_eligible': true,
                    'rules_version': 3,
                    'verification_checklist': [
                      {'key': 'form', 'label': 'Published full range rule'},
                    ],
                  },
                ],
                'divisions': [
                  {'id': 'v', 'display_label': 'Open'},
                ],
                'cities': [
                  {'id': 'c', 'name': 'Calgary'},
                ],
              },
            ),
          ],
          child: const MaterialApp(home: SubmitScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(find.text('Result (kg)'), findsOneWidget);
      expect(find.text('Published full range rule'), findsOneWidget);
      expect(find.text('Verification rules · version 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('ordinary athlete sees review history but no judge controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(
            (ref) async => const AthleteProfile(
              id: 'owner',
              displayName: 'Development Athlete',
              roles: ['USER'],
            ),
          ),
          submissionDetailProvider.overrideWith(
            (ref, id) async => {
              'id': id,
              'profile_id': 'owner',
              'discipline': 'Push-Ups',
              'claimed_metric': 20,
              'unit': 'reps',
              'board_type': 'OFFICIAL',
              'status': 'CHANGES_REQUESTED',
              'verification_checklist': <Map<String, dynamic>>[],
              'reviews': [
                {
                  'decision': 'RESUBMISSION_REQUESTED',
                  'comments': 'Please show the full range.',
                },
              ],
            },
          ),
        ],
        child: const MaterialApp(home: SubmissionDetailScreen(id: 's')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Please show the full range.'), findsOneWidget);
    expect(find.text('CORRECT & RESUBMIT'), findsOneWidget);
    expect(find.text('APPROVE & PUBLISH'), findsNothing);
    expect(find.text('OPEN PRIVATE EVIDENCE'), findsNothing);
  });
}
