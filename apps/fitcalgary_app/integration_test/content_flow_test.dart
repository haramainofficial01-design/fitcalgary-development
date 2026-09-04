import 'package:dio/dio.dart';
import 'package:fitcalgary_app/core/onboarding_store.dart';
import 'package:fitcalgary_app/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'admin publication becomes a searchable event and club in Flutter',
    (tester) async {
      Future<void> load([int ticks = 8]) async {
        for (var i = 0; i < ticks; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
      }

      const base = String.fromEnvironment('API_BASE_URL');
      const token = String.fromEnvironment('TEST_ADMIN_TOKEN');
      expect(
        base.isNotEmpty && token.isNotEmpty,
        isTrue,
        reason: 'Supply loopback test service and ephemeral admin identity',
      );
      final dio = Dio(
        BaseOptions(baseUrl: base, headers: {'Authorization': 'Bearer $token'}),
      );
      final reference = await dio.get<Map<String, dynamic>>(
        '/admin/reference-data',
      );
      final cities = reference.data?['cities'] as List? ?? const [];
      final city = Map<String, dynamic>.from(
        cities.firstWhere((value) => value['slug'] == 'calgary'),
      )['id'].toString();
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final eventSlug = 'development-mobile-event-$suffix';
      final clubSlug = 'development-mobile-club-$suffix';
      final eventName = 'Development Mobile Event $suffix';
      final clubName = 'Development Mobile Club $suffix';
      final start = DateTime.now().toUtc().add(const Duration(days: 3));
      final eventBody = <String, dynamic>{
        'cityId': city,
        'slug': eventSlug,
        'name': eventName,
        'sport': 'Running',
        'category': 'Development',
        'description': 'Published by the integration test using the real administrative service.',
        'startAt': start.toIso8601String(),
        'endAt': start.add(const Duration(hours: 2)).toIso8601String(),
        'location': 'Development test venue',
        'registrationStatus': 'OPEN',
        'externalRegistrationUrl': 'https://fixtures.example.invalid/event',
        'publishStatus': 'PUBLISHED',
      };
      final event = await dio.post<Map<String, dynamic>>(
        '/admin/events',
        data: eventBody,
      );
      final clubBody = <String, dynamic>{
        'cityId': city,
        'slug': clubSlug,
        'name': clubName,
        'sport': 'Running',
        'category': 'Development',
        'description': 'Published by the integration test using the real administrative service.',
        'websiteUrl': 'https://fixtures.example.invalid/club',
        'publishStatus': 'PUBLISHED',
      };
      final club = await dio.post<Map<String, dynamic>>(
        '/admin/clubs',
        data: clubBody,
      );
      addTearDown(() async {
        await dio.put(
          '/admin/events/${event.data!['id']}',
          data: {...eventBody, 'publishStatus': 'ARCHIVED'},
        );
        await dio.put(
          '/admin/clubs/${club.data!['id']}',
          data: {...clubBody, 'publishStatus': 'ARCHIVED'},
        );
      });

      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(SharedPreferencesOnboardingStore.key, true);
      app.main();
      await load();
      await tester.tap(find.text('Compete'));
      await load();
      expect(find.text(eventName), findsOneWidget);
      final eventCard = find.byKey(ValueKey('event-$eventSlug'));
      await tester.ensureVisible(eventCard);
      tester.widget<InkWell>(eventCard).onTap!();
      await load(6);
      expect(find.text(eventName), findsOneWidget);
      expect(
        find.text(
          'Published by the integration test using the real administrative service.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Compete'));
      await load(4);
      await tester.tap(find.text('CLUBS'));
      await load(6);
      expect(find.text(clubName), findsOneWidget);
      final clubCard = find.byKey(ValueKey('club-$clubSlug'));
      await tester.ensureVisible(clubCard);
      tester.widget<InkWell>(clubCard).onTap!();
      await load(6);
      expect(find.text(clubName), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
