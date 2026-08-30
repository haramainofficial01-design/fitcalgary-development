import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  String filter = 'ALL EVENTS';

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider);
    return Scaffold(
      body: Column(
        children: [
          const BrandHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(eventsProvider.future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 34, 22, 34),
                children: [
                  const Overline('Compete'),
                  const SizedBox(height: 16),
                  const Text(
                    'You can enter\nthese.',
                    style: TextStyle(
                      fontSize: 46,
                      height: .98,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Local competitions, events, leagues and recreational clubs from verified sources.',
                    style: TextStyle(color: FitColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: ['ALL EVENTS', 'OPEN ENTRY', 'LEAGUES & CLUBS']
                        .map(
                          (label) => _EventFilter(
                            label: label,
                            selected: filter == label,
                            onPressed: () => setState(() => filter = label),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 28),
                  events.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => ErrorPanel(
                      message: 'Events could not be loaded.',
                      onRetry: () => ref.invalidate(eventsProvider),
                    ),
                    data: (items) {
                      final visible = items
                          .where((event) {
                            final status =
                                event.registrationStatus?.toUpperCase() ?? '';
                            final sport = event.sport?.toUpperCase() ?? '';
                            if (filter == 'OPEN ENTRY') {
                              return status.contains('OPEN');
                            }
                            if (filter == 'LEAGUES & CLUBS') {
                              return sport.contains('LEAGUE') ||
                                  sport.contains('CLUB');
                            }
                            return true;
                          })
                          .toList(growable: false);
                      if (visible.isEmpty) {
                        return const EmptyPanel(
                          title: 'No matching published events',
                          body: 'Client-confirmed event and registration data will appear here after publication.',
                        );
                      }
                      final grouped = <String, List<EventListing>>{};
                      for (final item in visible) {
                        final key = item.startAt == null
                            ? 'DATE TO BE CONFIRMED'
                            : DateFormat('MMMM yyyy')
                                  .format(item.startAt!)
                                  .toUpperCase();
                        grouped.putIfAbsent(key, () => []).add(item);
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: grouped.entries
                            .map(
                              (entry) => _EventMonth(
                                month: entry.key,
                                events: entry.value,
                              ),
                            )
                            .toList(growable: false),
                      );
                    },
                  ),
                  const SizedBox(height: 34),
                  Container(
                    color: FitColors.coral,
                    padding: const EdgeInsets.all(26),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Find your next start line.',
                          style: TextStyle(
                            color: FitColors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Final registration links and Client content remain clearly separated from development data.',
                          style: TextStyle(
                            color: Color(0xFFFFDDD6),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventFilter extends StatelessWidget {
  const _EventFilter({
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      backgroundColor: selected ? FitColors.coral : Colors.transparent,
      foregroundColor: selected ? FitColors.white : FitColors.ink,
      side: BorderSide(color: selected ? FitColors.coral : FitColors.line),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 13),
    ),
    child: Text(label),
  );
}

class _EventMonth extends StatelessWidget {
  const _EventMonth({required this.month, required this.events});
  final String month;
  final List<EventListing> events;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        color: FitColors.black,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Text(
          month,
          style: const TextStyle(
            color: FitColors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
      ),
      ...events.map((event) => _EventRow(event)),
      const SizedBox(height: 18),
    ],
  );
}

class _EventRow extends StatelessWidget {
  const _EventRow(this.event);
  final EventListing event;

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Overline('Event details'),
              const SizedBox(height: 14),
              Text(
                event.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                event.location ?? 'Calgary',
                style: const TextStyle(color: FitColors.muted),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (event.registrationStatus != null)
                    Chip(label: Text(event.registrationStatus!.toUpperCase())),
                  if (event.sport != null)
                    Chip(label: Text(event.sport!.toUpperCase())),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Registration links are published with Client-confirmed event data.',
                      ),
                    ),
                  );
                },
                child: const Text('REGISTRATION DETAILS →'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = event.startAt;
    return InkWell(
      onTap: () => _showDetails(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: FitColors.line)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Column(
                children: [
                  Text(
                    date == null ? '—' : DateFormat('d').format(date),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    date == null
                        ? 'TBD'
                        : DateFormat('MMM').format(date).toUpperCase(),
                    style: const TextStyle(fontSize: 9, letterSpacing: 1.4),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 76, color: FitColors.ink),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.location ?? 'Calgary',
                    style: const TextStyle(
                      fontSize: 11,
                      color: FitColors.muted,
                    ),
                  ),
                  if (event.registrationStatus != null) ...[
                    const SizedBox(height: 11),
                    Text(
                      event.registrationStatus!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 8,
                        color: FitColors.coralDark,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }
}
