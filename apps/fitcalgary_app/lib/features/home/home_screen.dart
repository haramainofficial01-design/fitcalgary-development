import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../events/event_labels.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(catalogSnapshotProvider);
    final events = ref.watch(eventsProvider);
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: BrandHeader()),
        SliverToBoxAdapter(
          child: Container(
            color: FitColors.black,
            padding: const EdgeInsets.fromLTRB(24, 54, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Overline('Calgary · Video-verified', light: true),
                const SizedBox(height: 28),
                const Text(
                  'The city,\nranked.',
                  style: TextStyle(
                    color: FitColors.white,
                    fontSize: 62,
                    height: .92,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -4,
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Find the real cost of membership. Post a mark. Every result is reviewed against a published standard before it lands.',
                  style: TextStyle(
                    color: Color(0xFFD5D4CF),
                    fontSize: 17,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => context.push('/submit'),
                        child: const Text('POST A RESULT →'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.go('/gyms'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: FitColors.white),
                          foregroundColor: FitColors.white,
                        ),
                        child: const Text('BROWSE GYMS →'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _SnapshotGrid(
            gymCount: snapshot.valueOrNull?.gyms,
            eventCount: snapshot.valueOrNull?.events,
            boardCount: snapshot.valueOrNull?.boards,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Overline('The real number'),
                    Text(
                      'GYM INDEX →',
                      style: TextStyle(
                        color: FitColors.coralDark,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Cheapest all-in.',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Biweekly means 26 payments each year. Mandatory fees stay visible and incomplete pricing stays honest.',
                  style: TextStyle(height: 1.55, color: context.fitMuted),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/gyms'),
                  child: const Text('OPEN THE GYM INDEX →'),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Overline('Explore events'),
                    TextButton(
                      onPressed: () => context.go('/events'),
                      child: const Text('ALL EVENTS →'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Explore Calgary events.',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 16),
                events.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const EmptyPanel(
                    title: 'Events reconnecting',
                    body: 'We could not load the latest updates. Please try again.',
                  ),
                  data: (items) => items.isEmpty
                      ? const EmptyPanel(
                          title: 'No events listed',
                          body: 'Published Calgary competitions will appear here when available.',
                        )
                      : Column(
                          children: items
                              .take(3)
                              .map((event) => _HomeEvent(event: event))
                              .toList(growable: false),
                        ),
                ),
                const SizedBox(height: 38),
                Container(
                  width: double.infinity,
                  color: FitColors.coral,
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Put a number on it.',
                        style: TextStyle(
                          color: FitColors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'One clip, one review, one place on the board.',
                        style: TextStyle(color: Color(0xFFFFDDD6)),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: () => context.push('/submit'),
                        style: FilledButton.styleFrom(
                          backgroundColor: FitColors.black,
                        ),
                        child: const Text('POST A RESULT →'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SnapshotGrid extends StatelessWidget {
  const _SnapshotGrid({this.gymCount, this.eventCount, this.boardCount});
  final int? gymCount;
  final int? eventCount;
  final int? boardCount;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('${gymCount ?? '—'}', 'GYMS INDEXED'),
      ('${eventCount ?? '—'}', 'EVENTS LISTED'),
      ('${boardCount ?? '—'}', 'ACTIVE BOARDS'),
      ('YOU', 'YOUR NEXT BEST'),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: context.fitLine),
          top: BorderSide(color: context.fitLine),
        ),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.8,
        ),
        itemCount: values.length,
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: context.fitLine),
              bottom: BorderSide(color: context.fitLine),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                values[index].$1,
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                values[index].$2,
                style: TextStyle(
                  fontSize: 8,
                  color: context.fitMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeEvent extends StatelessWidget {
  const _HomeEvent({required this.event});
  final EventListing event;

  @override
  Widget build(BuildContext context) {
    final date = event.startAt ?? event.startDate;
    return InkWell(
      onTap: () => context.go('/events/${event.slug}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.fitLine)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Column(
                children: [
                  Text(
                    date == null ? '—' : DateFormat('d').format(date),
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    date == null
                        ? 'TBD'
                        : DateFormat('MMM').format(date).toUpperCase(),
                    style: const TextStyle(fontSize: 8, letterSpacing: 1.3),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 56, color: context.fitInk),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    event.location ?? 'Calgary',
                    style: TextStyle(fontSize: 10, color: context.fitMuted),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    eventPhaseLabel(
                      event.phase,
                      dateOnly:
                          event.startAt == null && event.startDate != null,
                    ),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: context.fitMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 17),
          ],
        ),
      ),
    );
  }
}
