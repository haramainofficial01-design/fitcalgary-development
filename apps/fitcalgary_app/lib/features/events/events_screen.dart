import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/widgets.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  const SizedBox(height: 28),
                  events.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => ErrorPanel(
                      message: 'Events could not be loaded.',
                      onRetry: () => ref.invalidate(eventsProvider),
                    ),
                    data: (items) => items.isEmpty
                        ? const EmptyPanel(
                            title: 'No published events',
                            body: 'Client-confirmed events will appear here after an administrator publishes them.',
                          )
                        : Column(
                            children: items
                                .map((item) => _EventRow(item))
                                .toList(),
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

class _EventRow extends StatelessWidget {
  const _EventRow(this.event);
  final EventListing event;
  @override
  Widget build(BuildContext context) {
    final date = event.startAt;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
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
          Container(width: 1, height: 68, color: FitColors.ink),
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
                  style: const TextStyle(fontSize: 11, color: FitColors.muted),
                ),
                const SizedBox(height: 12),
                Text(
                  event.registrationStatus ?? '',
                  style: const TextStyle(
                    fontSize: 8,
                    color: FitColors.coralDark,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward),
        ],
      ),
    );
  }
}
