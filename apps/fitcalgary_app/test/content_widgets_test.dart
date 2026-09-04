import 'package:fitcalgary_app/app/app.dart';
import 'package:fitcalgary_app/core/onboarding_store.dart';
import 'package:fitcalgary_app/domain/models.dart';
import 'package:fitcalgary_app/features/events/content_providers.dart';
import 'package:fitcalgary_app/features/events/content_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const event = EventListing(
    id: 'event-1',
    slug: 'development-event',
    name: 'Development Event',
    startAt: null,
    phase: 'UPCOMING',
    registrationStatus: 'OPEN',
    description: 'Development event details',
  );
  const club = ClubListing(
    id: 'club-1',
    slug: 'development-club',
    name: 'Development Club',
    sport: 'Running',
    city: 'Calgary',
    description: 'Development club details',
  );
  Widget application() => ProviderScope(
    overrides: [
      eventDirectoryProvider.overrideWith(
        (ref, query) async => const ContentPage([event], 1),
      ),
      clubDirectoryProvider.overrideWith(
        (ref, query) async => const ContentPage([club], 1),
      ),
      eventDetailProvider.overrideWith((ref, slug) async => event),
      clubDetailProvider.overrideWith((ref, slug) async => club),
    ],
    child: FitCalgaryApp(
      onboardingStore: MemoryOnboardingStore(complete: true),
    ),
  );

  Future<void> load(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('published event list opens its actual detail route', (
    tester,
  ) async {
    await tester.pumpWidget(application());
    await load(tester);
    await tester.tap(find.text('Compete'));
    await load(tester);
    expect(find.text('1 PUBLISHED EVENTS'), findsOneWidget);
    final eventCard = find.byKey(const ValueKey('event-development-event'));
    await tester.ensureVisible(eventCard);
    await tester.pump();
    await tester.drag(find.byType(ListView).first, const Offset(0, -100));
    await tester.pump();
    tester.widget<InkWell>(eventCard).onTap!();
    await load(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(ContentDetailScreen), findsOneWidget);
    expect(find.text('EVENT DETAILS'), findsOneWidget);
    expect(find.text('Development event details'), findsOneWidget);
  });

  testWidgets('club section opens a distinct detail route', (tester) async {
    await tester.pumpWidget(application());
    await load(tester);
    await tester.tap(find.text('Compete'));
    await load(tester);
    await tester.tap(find.text('CLUBS'));
    await load(tester);
    expect(find.text('1 PUBLISHED CLUBS'), findsOneWidget);
    final clubCard = find.byKey(const ValueKey('club-development-club'));
    await tester.ensureVisible(clubCard);
    await tester.pump();
    await tester.drag(find.byType(ListView).first, const Offset(0, -100));
    await tester.pump();
    tester.widget<InkWell>(clubCard).onTap!();
    await load(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('CLUB DETAILS'), findsOneWidget);
    expect(find.text('Development club details'), findsOneWidget);
  });
}
